FROM node:22-slim AS builder
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY tsconfig.json ./
COPY src/ ./src/
RUN npm run build

FROM node:22-slim
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev && \
    groupadd -r appuser && useradd -r -g appuser -d /app appuser && \
    chown -R appuser:appuser /app

COPY --from=builder /app/dist ./dist

USER appuser
ENV NODE_ENV=production
EXPOSE 3000

CMD ["node", "dist/index.js"]
