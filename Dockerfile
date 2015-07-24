FROM shimaore/debian:2.0.0
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
RUN git clone https://github.com/tj/n.git
WORKDIR n
RUN make install
WORKDIR ..
RUN n io 2.4.0
ENV NODE_ENV production

#-------------------#

RUN useradd -m spicy
COPY . /home/spicy/spicy-action
RUN chown -R spicy.spicy /home/spicy

#-------------------#
USER spicy
WORKDIR /home/spicy/spicy-action
RUN mkdir log
RUN npm install
RUN npm install coffee-script
RUN npm cache clean

CMD ["supervisord","-n"]
