# Squash Analyzer: live meekijken. No dependencies, no volumes: everything in memory.
FROM node:22-alpine
ENV NODE_ENV=production PORT=8080
WORKDIR /app
COPY package.json server.js ./
COPY public ./public
USER node
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
  CMD wget -qO- http://127.0.0.1:8080/health || exit 1
CMD ["node", "server.js"]
