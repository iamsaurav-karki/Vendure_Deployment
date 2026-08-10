FROM node:20-alpine
WORKDIR /app

COPY saurav-shop/package*.json ./
RUN npm install

COPY saurav-shop/ ./

EXPOSE 3000
CMD ["npm", "run", "dev"]
