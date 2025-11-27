# Hướng dẫn Thiết lập CI/CD và Auto Deploy

Tài liệu này hướng dẫn bạn cách thiết lập quy trình Tích hợp liên tục (CI) và Triển khai liên tục (CD) cho dự án Portfolio Website (Three.js + React + Express).

Chúng ta sẽ sử dụng **Docker** để đóng gói ứng dụng, **GitHub Actions** để kiểm tra code (CI), và **Render** (hoặc Railway) để tự động triển khai (CD).

## 1. Dockerize Ứng dụng (Chuẩn bị môi trường)

Để đảm bảo ứng dụng chạy giống nhau ở mọi nơi, chúng ta sẽ đóng gói nó vào Docker.

### 1.1. Tạo file `.dockerignore`
Tạo một file tên là `.dockerignore` ở thư mục gốc dự án để loại bỏ các file không cần thiết khi build Docker image.

```text
node_modules
npm-debug.log
build
dist
.git
.gitignore
.dockerignore
Dockerfile
README.md
```

### 1.2. Tạo file `Dockerfile`
Tạo một file tên là `Dockerfile` (không có đuôi mở rộng) ở thư mục gốc. File này sẽ thực hiện 2 việc: Build frontend và Chạy backend server.

```dockerfile
# Giai đoạn 1: Build Frontend
FROM node:16-alpine AS builder

WORKDIR /app

# Copy package.json và cài đặt dependencies
COPY package.json package-lock.json ./
RUN npm ci

# Copy toàn bộ source code
COPY . .

# Build dự án (tạo ra thư mục /public)
RUN npm run build

# Giai đoạn 2: Chạy Server
FROM node:16-alpine

WORKDIR /app

# Copy package.json và cài dependencies cho production (nếu cần)
COPY package.json package-lock.json ./
RUN npm ci --production

# Copy server code
COPY server ./server

# Copy kết quả build từ giai đoạn 1 sang
COPY --from=builder /app/public ./public

# Thiết lập biến môi trường (Có thể ghi đè khi deploy)
ENV PORT=8080

# Mở port
EXPOSE 8080

# Lệnh chạy server
CMD ["node", "server/index.ts"]
```

*Lưu ý: Trong `package.json`, lệnh `start` của bạn đang là `node server/index.ts`. Hãy đảm bảo `ts-node` không cần thiết hoặc server đã được transpile sang JS. Vì bạn đang chạy trực tiếp `.ts` bằng `node`, bạn có thể cần cài `ts-node` hoặc đổi lệnh start để chạy file JS đã biên dịch. Tuy nhiên, với setup hiện tại của dự án, Dockerfile trên giả định bạn chạy được `server/index.ts` (có thể cần điều chỉnh nếu node không chạy trực tiếp được TS).*

**Điều chỉnh cho Server:**
Dự án hiện tại dùng `ts-node` hay biên dịch server? Trong `package.json` scripts là `"start": "node server/index.ts"`. Node.js thuần không chạy được file `.ts`.
Bạn nên cập nhật `package.json` hoặc cấu hình Docker để dùng `ts-node`. Cách tốt nhất cho production là biên dịch server.
Nhưng để đơn giản, trong Dockerfile trên, ở bước CMD, bạn có thể cần đổi thành:
`CMD ["npx", "ts-node", "server/index.ts"]` (và đảm bảo `ts-node` có trong dependencies).

## 2. Thiết lập CI với GitHub Actions

Tự động kiểm tra xem code có build được không mỗi khi bạn đẩy code lên GitHub.

### Tạo file `.github/workflows/ci.yml`
Tạo thư mục `.github/workflows/` và bên trong tạo file `ci.yml`:

```yaml
name: CI Pipeline

on:
  push:
    branches: [ main, master ]
  pull_request:
    branches: [ main, master ]

jobs:
  build-and-test:
    runs-on: ubuntu-latest

    steps:
    - name: Checkout code
      uses: actions/checkout@v3

    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '16'

    - name: Install Dependencies
      run: npm ci

    - name: Build Project
      run: npm run build
      # Nếu build thất bại, quy trình sẽ dừng lại và báo lỗi cho bạn biết.
```

## 3. Thiết lập Auto Deploy (CD) với Render.com

Render là nền tảng dễ dùng nhất để deploy các ứng dụng Docker/Node.js.

1.  Đẩy code của bạn (bao gồm `Dockerfile`) lên GitHub.
2.  Đăng ký tài khoản tại [dashboard.render.com](https://dashboard.render.com/).
3.  Chọn **New +** -> **Web Service**.
4.  Kết nối với repository GitHub của bạn.
5.  **Runtime:** Chọn **Docker**.
6.  **Environment Variables:** Thêm các biến môi trường quan trọng:
    *   `FOLIO_EMAIL`: Email gửi đi (được dùng trong `server/index.ts`).
    *   `FOLIO_PASSWORD`: Mật khẩu ứng dụng (App Password) của Gmail.
7.  Nhấn **Create Web Service**.

Render sẽ tự động phát hiện `Dockerfile`, build image và deploy. Mỗi khi bạn push code mới lên nhánh `main`, Render sẽ tự động deploy lại phiên bản mới.

## Tóm tắt luồng hoạt động

1.  Bạn code -> `git push`.
2.  **GitHub Actions** chạy: Kiểm tra xem code có lỗi build không.
3.  Nếu ổn, **Render** tự động kéo code về, build Docker image mới và thay thế server cũ.
