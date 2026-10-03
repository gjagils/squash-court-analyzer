# Squash Analyzer: live meekijken. No dependencies, no volumes: everything in memory.
# Pinned to a digest (node:22-alpine on 2026-10-03); update it on purpose
FROM node:22-alpine@sha256:0a7108bf6c7bf5de370ffb1a3ed6be93d405b43ff159f681a8d18c0e2bc2e402
ENV NODE_ENV=production PORT=8080
WORKDIR /app
COPY package.json server.js ./
COPY public ./public
USER node
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
  CMD wget -qO- http://127.0.0.1:8080/health || exit 1
CMD ["node", "server.js"]
