FROM ubuntu:18.04

MAINTAINER Kelson <kelson@kiwix.org>

ENV DEBIAN_FRONTEND noninteractive

# Install necessary packages
RUN echo "UTC" > /etc/timezone && \
    ln -fs /usr/share/zoneinfo/UTC /etc/localtime && \
    apt-get update -y && \
    apt-get install -y --no-install-recommends nodejs npm

# Copy necessary files
COPY watcherbot.js watcherbot.js
COPY run.sh        run.sh
COPY package.json  package.json

# Install node modules
RUN npm install && npm install -g slack-irc

# Run bot
CMD ./run.sh
