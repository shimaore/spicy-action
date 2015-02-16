FROM shimaore/nodejs
MAINTAINER Stéphane Alnet <stephane@shimaore.net>

USER root
RUN useradd -m spicy
WORKDIR /home/spicy
COPY . /home/spicy/spicy-action
RUN chown -R spicy.spicy .
USER spicy
WORKDIR spicy-action
RUN mkdir log

CMD ["supervisord","-n"]
