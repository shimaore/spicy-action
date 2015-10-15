FROM shimaore/debian:2.0.3
MAINTAINER Stéphane Alnet <stephane@shimaore.net>

#-------------------#
USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
  build-essential \
  ca-certificates \
  curl \
  git \
  make \
  supervisor
# Install Node.js using `n`.
RUN git clone https://github.com/tj/n.git \
 && cd n \
 && make install \
 && cd .. \
 && n 4.2.1
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
 && npm cache clean

CMD ["supervisord","-n"]
