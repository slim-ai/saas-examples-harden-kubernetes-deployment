FROM node:18

LABEL org.opencontainers.image.source=https://github.com/slim-ai/saas-examples-harden-kubernetes-deployment

WORKDIR /opt/my/service

COPY . /opt/my/service

RUN yarn install

EXPOSE 8080

ENTRYPOINT ["node", "/opt/my/service/server.js"]
