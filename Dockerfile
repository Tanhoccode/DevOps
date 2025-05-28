# Dockerfile

FROM node:20-alpine

# Tạo thư mục làm việc trong container
WORKDIR /usr/src/app

# Copy package.json và package-lock.json vào image
COPY package*.json ./

# Cài đặt dependencies
RUN npm install

# Copy toàn bộ project vào image
COPY . .

# ⚠️ Build app NestJS → tạo ra dist/
RUN npm run build

# Expose cổng NestJS thường chạy (tuỳ bạn)
EXPOSE 3000

# Lệnh chạy chính của container
CMD ["node", "dist/main.js"]
