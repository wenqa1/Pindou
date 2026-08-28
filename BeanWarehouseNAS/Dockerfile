FROM node:24-alpine

WORKDIR /app
COPY server ./server
COPY public ./public

ENV NODE_ENV=production \
    PORT=8786 \
    DATA_PATH=/data/bean-warehouse.sqlite \
    PUBLIC_PATH=/app/public

RUN mkdir -p /data && chown -R node:node /app /data

USER node
EXPOSE 8786

CMD ["node", "server/server.mjs"]
