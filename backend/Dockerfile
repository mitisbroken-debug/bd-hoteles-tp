FROM node:22-alpine AS builder
WORKDIR /app
RUN apk --no-cache upgrade
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

FROM node:22-alpine
WORKDIR /app
ENV NODE_ENV=production
RUN apk --no-cache upgrade \
  && rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx /root/.npm
COPY --from=builder --chown=node:node /app/node_modules ./node_modules
COPY --chown=node:node src ./src
USER node
EXPOSE 3000
HEALTHCHECK --interval=15s --timeout=5s --start-period=15s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/health || exit 1
CMD ["node", "src/server.js"]