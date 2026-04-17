FROM ubuntu:latest

COPY bingo /bingo
COPY start.sh /start.sh

RUN mkdir /opt/bingo
COPY config.yaml /opt/bingo/config.yaml

RUN mkdir /opt/bongo
RUN mkdir /opt/bongo/logs
RUN mkdir /opt/bongo/logs/c08832d0e4
RUN touch /opt/bongo/logs/c08832d0e4/main.log

RUN chmod +x /bingo
RUN chmod +x /start.sh

RUN apt update && apt install -y postgresql-client netcat-openbsd curl

RUN groupadd -r app_group && useradd -r -g app_group app

RUN chmod -R a+rX /opt/bingo
RUN chmod -R a+rX /opt/bongo
RUN chown -R app: /opt/bingo
RUN chown -R app: /opt/bongo

CMD ["/bin/bash", "./start.sh"]
