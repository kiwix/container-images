FROM ubuntu:latest

MAINTAINER Kelson <kelson@kiwix.org>

# Install necessary packages
RUN apt-get update && apt-get install -y nodejs npm

# Copy necessary files
COPY watcherbot.js watcherbot.js
COPY run.sh        run.sh
COPY package.json  package.json

# Install node modules
RUN npm install && npm install -g slack-irc

# Run bot
CMD ./run.sh