# ---- Build stage ----
FROM node:20-alpine AS build
WORKDIR /app

COPY saurav-shop/package*.json ./
RUN npm ci

COPY saurav-shop/ ./
RUN npm run build

# ---- Production stage ----
FROM node:20-alpine AS production
WORKDIR /app
ENV NODE_ENV=production

COPY saurav-shop/package*.json ./
RUN npm ci --omit=dev && npm cache clean --force

COPY --from=build /app/dist ./dist
COPY --from=build /app/static ./static

RUN addgroup -S vendure && adduser -S vendure -G vendure \
  && chown -R vendure:vendure /app

USER vendure

EXPOSE 3000
CMD ["node", "dist/index.js"]
