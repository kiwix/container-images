FROM node:16-bullseye

ENV PASSWORD "admin"

RUN mkdir /app /data
WORKDIR /app
VOLUME /data

RUN wget https://git.cloudron.io/cloudron/surfer/-/archive/master/surfer-master.tar.gz \
  && tar -xvf surfer-master.tar.gz --strip=1 \
      surfer-master/src/ \
      surfer-master/frontend/ \
      surfer-master/cli/ \
      surfer-master/public/ \
      surfer-master/vue.config.js \
      surfer-master/babel.config.js \
      surfer-master/server.js \
      surfer-master/admin \
      surfer-master/package.json \
      surfer-master/package-lock.json \
  && rm surfer-master.tar.gz \
  && sed -i '/chromedriver/d' package.json \
  && sed -i 's/listen(3000/listen(80/g' server.js

RUN npm install && npm run build
ADD start.sh .config.json /app/

EXPOSE 80

CMD [ "/app/start.sh" ]
