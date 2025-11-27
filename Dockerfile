# --- Giai đoạn 1: Build Frontend ---
FROM node:18-alpine AS builder

WORKDIR /app

# Copy file package để cài đặt dependencies
COPY package.json package-lock.json ./

# Cài đặt tất cả dependencies (bao gồm cả devDependencies để build webpack)
RUN npm ci

# Copy toàn bộ source code vào
COPY . .

# Chạy lệnh build (Webpack sẽ bundle code vào thư mục /public)
RUN npm run build

# --- Giai đoạn 2: Chạy Server (Production) ---
FROM node:18-alpine

WORKDIR /app

# Copy package.json lại
COPY package.json package-lock.json ./

# Cài đặt dependencies
RUN npm ci

# Copy thư mục server từ source gốc
COPY server ./server

# Copy thư mục public (đã build) từ giai đoạn builder
COPY --from=builder /app/public ./public

# Copy các file static assets nếu cần (webpack copy-plugin đã làm việc này vào public rồi, 
# nhưng nếu server cần truy cập trực tiếp thư mục static gốc thì copy thêm, 
# tuy nhiên setup hiện tại server serve static từ public nên ổn).

# Thiết lập biến môi trường mặc định
ENV PORT=8080
ENV NODE_ENV=production

# Mở port
EXPOSE 8080

# Chạy server bằng ts-node để xử lý file .ts
CMD ["npx", "ts-node", "server/index.ts"]
