FROM shimaore/nodejs
MAINTAINER Stéphane Alnet <stephane@shimaore.net>

USER root
RUN useradd -m spicy
USER spicy
WORKDIR /home/spicy
COPY . /home/spicy/spicy-action
WORKDIR spicy-action
RUN mkdir log

CMD ["supervisord","-n"]
