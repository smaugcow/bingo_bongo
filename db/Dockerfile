FROM ubuntu:latest

RUN apt-get update && apt-get install -y netcat-openbsd postgresql-client

COPY init_db.sql /tmp/init_db.sql
COPY commands.sql /tmp/commands.sql
COPY restore.sh /tmp/restore.sh

CMD ["/bin/sh", "/tmp/restore.sh"]
