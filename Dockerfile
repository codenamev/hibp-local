FROM node:8.9.1-alpine

RUN npm install -g yarn

# Create app directory
RUN mkdir /app
WORKDIR /app

# Install app dependencies
COPY package.json yarn.lock .env ./
RUN yarn install -s

# Bundle app source
COPY . .

EXPOSE 4000
CMD yarn run start
