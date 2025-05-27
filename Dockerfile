# Sử dụng Node.js Alpine image (nhẹ hơn)
FROM node:20-alpine

# Cài đặt dumb-init để xử lý signals tốt hơn
RUN apk add --no-cache dumb-init

# Tạo user non-root
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nestjs -u 1001

# Tạo thư mục app
WORKDIR /usr/src/app

# Copy package files trước để cache layer
COPY package*.json ./

# Set npm config để tăng tốc
RUN npm config set registry https://registry.npmjs.org/
RUN npm config set fetch-retries 5
RUN npm config set fetch-retry-factor 2
RUN npm config set fetch-retry-mintimeout 20000
RUN npm config set fetch-retry-maxtimeout 120000

# Install dependencies với cache mount (nếu dùng BuildKit)
RUN --mount=type=cache,target=/root/.npm \
    npm ci --only=production --silent

# Copy source code
COPY --chown=nestjs:nodejs . .

# Build application (nếu cần)
# RUN npm run build

# Chuyển sang user non-root
USER nestjs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node healthcheck.js

# Start application
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "dist/main.js"]