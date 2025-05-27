# Dockerfile
FROM node:20

WORKDIR /usr/src/app

# Chỉ copy package.json để cache npm install
COPY package*.json ./
RUN npm install

# Sau đó mới copy toàn bộ source
COPY . .

CMD ["npm", "start"]
