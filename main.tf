terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  token =     "YOUR_IAM_TOKEN"
  folder_id = local.folder_id
  zone =      "ru-central1-a"
}

resource "null_resource" "build_docker_image" {
  provisioner "local-exec" {
    command = <<-EOF
      docker build -t bingo_db:1 ./db/
      docker tag bingo_db:1 cr.yandex/"${yandex_container_registry.registry-bingo.id}"/bingo_db:1
      docker push cr.yandex/"${yandex_container_registry.registry-bingo.id}"/bingo_db:1

      docker build -t bingo_nginx:1 ./nginx/
      docker tag bingo_nginx:1 cr.yandex/"${yandex_container_registry.registry-bingo.id}"/bingo_nginx:1
      docker push cr.yandex/"${yandex_container_registry.registry-bingo.id}"/bingo_nginx:1

      docker build -t bingo:1 ./app/
      docker tag bingo:1 cr.yandex/"${yandex_container_registry.registry-bingo.id}"/bingo:1
      docker push cr.yandex/"${yandex_container_registry.registry-bingo.id}"/bingo:1
    EOF
  }
}

resource "yandex_vpc_network" "foo" {}

resource "yandex_vpc_subnet" "foo" {
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.foo.id
  v4_cidr_blocks = ["10.5.0.0/24"]
}

resource "yandex_container_registry" "registry-bingo" {
  name = "registry-bingo"
}

locals {
  folder_id = "YOUR_FOLDER_ID"
  service-accounts = toset([
    "bingo-sa",
    "bingo-ig-sa",
  ])
  bingo-sa-roles = toset([
    "container-registry.images.puller",
    "monitoring.editor",
  ])
  bingo-ig-sa-roles = toset([
    "compute.editor",
    "iam.serviceAccounts.user",
    "load-balancer.admin",
    "vpc.publicAdmin",
    "vpc.user",
  ])
}
resource "yandex_iam_service_account" "service-accounts" {
  for_each = local.service-accounts
  name     = "${local.folder_id}-${each.key}"
}
resource "yandex_resourcemanager_folder_iam_member" "bingo-roles" {
  for_each  = local.bingo-sa-roles
  folder_id = local.folder_id
  member    = "serviceAccount:${yandex_iam_service_account.service-accounts["bingo-sa"].id}"
  role      = each.key
}
resource "yandex_resourcemanager_folder_iam_member" "bingo-ig-roles" {
  for_each  = local.bingo-ig-sa-roles
  folder_id = local.folder_id
  member    = "serviceAccount:${yandex_iam_service_account.service-accounts["bingo-ig-sa"].id}"
  role      = each.key
}

data "yandex_compute_image" "coi" {
  family = "container-optimized-image"
}

resource "yandex_compute_instance" "bingo-db" {
  platform_id        = "standard-v2"
  service_account_id = yandex_iam_service_account.service-accounts["bingo-sa"].id
  resources {
    cores         = 2
    memory        = 2
    core_fraction = 100
  }
  scheduling_policy {
    preemptible = true
  }
  network_interface {
    subnet_id = "${yandex_vpc_subnet.foo.id}"
    nat        = true
  }
  boot_disk {
    initialize_params {
      type     = "network-hdd"
      size     = "30"
      image_id = data.yandex_compute_image.coi.id
    }
  }
  metadata = {
    docker-compose = templatefile(
      "${path.module}/docker-compose-db.yaml",
      {
        folder_id   = "${local.folder_id}",
        registry_id = "${yandex_container_registry.registry-bingo.id}",
      }
    )
    ssh-keys  = "ubuntu:${file("~/.ssh/id_ed25519.pub")}"
  }
}

resource "yandex_compute_instance_group" "bingo" {
  depends_on = [
    yandex_resourcemanager_folder_iam_member.bingo-ig-roles
  ]
  name               = "bingo"
  service_account_id = yandex_iam_service_account.service-accounts["bingo-ig-sa"].id
  allocation_policy {
    zones = ["ru-central1-a"]
  }
  deploy_policy {
    max_unavailable = 1
    max_creating    = 2
    max_expansion   = 2
    max_deleting    = 2
  }
  scale_policy {
    fixed_scale {
      size = 2
    }
  }
  instance_template {
    platform_id        = "standard-v2"
    service_account_id = yandex_iam_service_account.service-accounts["bingo-sa"].id
    resources {
      cores         = 2
      memory        = 2
      core_fraction = 100
    }
    scheduling_policy {
      preemptible = true
    }
    network_interface {
      network_id = yandex_vpc_network.foo.id
      subnet_ids = ["${yandex_vpc_subnet.foo.id}"]
      nat        = true
    }
    boot_disk {
      initialize_params {
        type     = "network-hdd"
        size     = "30"
        image_id = data.yandex_compute_image.coi.id
      }
    }
    metadata = {
      docker-compose = templatefile(
        "${path.module}/docker-compose-app.yaml",
        {
          folder_id   = "${local.folder_id}",
          registry_id = "${yandex_container_registry.registry-bingo.id}",
          db_ip = "${yandex_compute_instance.bingo-db.network_interface[0].nat_ip_address}",
        }
      )
      user-data = file("${path.module}/set_dns.sh"),
      ssh-keys  = "ubuntu:${file("~/.ssh/id_ed25519.pub")}"
    }
  }
  load_balancer {
    target_group_name = "bingo"
  }
}

resource "yandex_lb_network_load_balancer" "lb-bingo" {
  name = "bingo"

  listener {
    name        = "bingo-http-listener"
    port        = 80
    target_port = 8090
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  listener {
    name        = "bingo-https-listener"
    port        = 443
    target_port = 443
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_compute_instance_group.bingo.load_balancer[0].target_group_id

    healthcheck {
      name = "http"
      http_options {
        port = 21999
        path = "/ping"
      }
    }
  }
}