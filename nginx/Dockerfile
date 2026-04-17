FROM nginx

RUN mkdir /opt/crt
COPY example.key /opt/crt/example.key
COPY example.crt /opt/crt/example.crt

RUN mkdir /tmp/nginx_cache
RUN rm /etc/nginx/nginx.conf /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/nginx.conf
