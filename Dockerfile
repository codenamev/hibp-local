FROM node:8.9.1-alpine

RUN apk add --no-cache build-base
RUN npm install -g yarn

# Create app directory
RUN mkdir /app
WORKDIR /app

# Install app dependencies
COPY package.json .env /app/

ENV DOCKER=true
RUN yarn install -s

# Bundle app source
COPY . /app

EXPOSE 4000
CMD yarn run server
