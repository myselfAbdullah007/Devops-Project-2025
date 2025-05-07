FROM node:18-alpine

WORKDIR /app

# Install wait-for-it script
RUN apk add --no-cache bash

COPY package*.json ./

RUN npm install

COPY . .

EXPOSE 5001

# Use nodemon for hot reloading
CMD ["npx", "nodemon", "server.js"] 