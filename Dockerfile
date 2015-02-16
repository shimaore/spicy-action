FROM shimaore/nodejs:0.10.36
MAINTAINER Stéphane Alnet <stephane@shimaore.net>

USER root
RUN useradd -m spicy
COPY . /home/spicy/spicy-action
RUN chown -R spicy.spicy /home/spicy

USER spicy
WORKDIR /home/spicy/spicy-action
RUN mkdir log
RUN npm install
RUN npm install coffee-script
RUN npm cache clean

CMD ["supervisord","-n"]
