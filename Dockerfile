FROM shimaore/debian:2.0.15
MAINTAINER Stéphane Alnet <stephane@shimaore.net>

#-------------------#
USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  git \
  make \
  supervisor
# Install Node.js using `n`.
RUN git clone https://github.com/tj/n.git n.git \
 && cd n.git \
 && make install \
 && cd .. \
 && rm -rf n.git \
 && n 7.4.0
ENV NODE_ENV production

#-------------------#

RUN useradd -m spicy
COPY . /home/spicy/spicy-action
RUN chown -R spicy.spicy /home/spicy

#-------------------#
USER spicy
WORKDIR /home/spicy/spicy-action
RUN mkdir log
RUN npm install \
 && npm install coffee-script \
 && npm cache clean \
 && rm -rf /tmp/npm*

CMD ["supervisord","-n"]
