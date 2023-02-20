FROM node:18

LABEL org.opencontainers.image.source=https://github.com/slim-ai/saas-examples-harden-kubernetes-deployment

WORKDIR /service

COPY . .

RUN chown -R node:node /service

RUN yarn install

EXPOSE 8080

USER node

ENTRYPOINT [ "node", "server.js" ]
