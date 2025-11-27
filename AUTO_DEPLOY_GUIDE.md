# Hướng dẫn Tự động Deploy (Continuous Deployment) với GitHub Actions

Tài liệu này hướng dẫn cách thiết lập quy trình tự động deploy cho dự án của bạn lên VPS mỗi khi có code mới được push lên nhánh `main`.

Chúng ta sẽ sử dụng:
- **GitHub Actions**: Để bắt sự kiện `push` và thực thi các lệnh.
- **SSH**: Để kết nối an toàn từ GitHub Actions đến VPS của bạn.
- **PM2**: Một trình quản lý tiến trình cho Node.js, giúp chạy ứng dụng nền, tự động khởi động lại khi có lỗi và quản lý ứng dụng một cách chuyên nghiệp.

---

### Bước 1: Cấu hình trên VPS

Bước này chuẩn bị môi trường trên VPS để sẵn sàng nhận lệnh deploy từ GitHub.

1.  **Cài đặt PM2:**
    Nếu bạn chưa cài đặt PM2, hãy chạy lệnh sau:
    ```bash
    npm install pm2 -g
    ```

2.  **Tạo SSH Key cho GitHub Actions:**
    Để bảo mật, chúng ta sẽ tạo một cặp SSH key riêng chỉ dành cho GitHub Actions, thay vì dùng key cá nhân của bạn.
    ```bash
    # Lệnh này sẽ hỏi bạn lưu key ở đâu, hãy nhấn Enter để dùng đường dẫn mặc định
    # Khi hỏi passphrase, hãy để trống (nhấn Enter 2 lần)
    ssh-keygen -t rsa -b 4096 -C "github-actions@your-domain.com"
    ```
    Lệnh này sẽ tạo ra 2 file: `~/.ssh/id_rsa` (private key) và `~/.ssh/id_rsa.pub` (public key).

3.  **Thêm Public Key vào `authorized_keys`:**
    Cho phép key vừa tạo có thể SSH vào VPS.
    ```bash
    cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
    ```

4.  **Lấy Private Key:**
    Bạn sẽ cần nội dung của private key để thêm vào GitHub Secrets ở bước sau.
    ```bash
    cat ~/.ssh/id_rsa
    ```
    **Copy toàn bộ nội dung** của file này (bắt đầu từ `-----BEGIN RSA PRIVATE KEY-----` và kết thúc ở `-----END RSA PRIVATE KEY-----`).

5.  **Chạy ứng dụng lần đầu với PM2 (nếu cần):**
    Nếu ứng dụng của bạn chưa từng chạy với PM2, hãy build và khởi động nó. Giả sử sau khi build, file khởi động của bạn nằm ở `build/server.js`.

    ```bash
    # Di chuyển vào thư mục dự án
    cd /root/portfolio-website

    # Cài đặt dependencies
    npm install

    # Build project
    npm run build # (Dựa trên cấu trúc dự án, bạn có thể có lệnh build khác)

    # Khởi động app với PM2
    # Thay 'portfolio-app' bằng tên bạn muốn đặt cho ứng dụng
    pm2 start ./server/index.ts --name portfolio-app
    ```
    Kiểm tra trạng thái ứng dụng: `pm2 list`

---

### Bước 2: Thêm Secrets vào Repository trên GitHub

Để GitHub Actions có thể kết nối vào VPS, bạn cần cung cấp thông tin đăng nhập một cách an toàn thông qua Secrets.

1.  Vào repository của bạn trên GitHub.
2.  Đi đến **Settings** > **Secrets and variables** > **Actions**.
3.  Nhấn **New repository secret** và tạo các secret sau:
    *   `VPS_HOST`:
        *   **Value**: Địa chỉ IP của VPS của bạn.
    *   `VPS_USER`:
        *   **Value**: Tên người dùng để đăng nhập vào VPS (trong trường hợp của bạn là `root`).
    *   `VPS_SSH_PRIVATE_KEY`:
        *   **Value**: Dán toàn bộ nội dung của **private key** bạn đã copy ở Bước 1.4.

---

### Bước 3: Tạo Workflow cho GitHub Actions

Tạo một file workflow mới để định nghĩa các bước deploy.

1.  Tạo file `.github/workflows/deploy.yml` trong dự án của bạn.
2.  Dán nội dung sau vào file:

    ```yaml
    name: Deploy to VPS

    on:
      push:
        branches:
          - main # Chỉ chạy khi có push lên nhánh main

    jobs:
      deploy:
        runs-on: ubuntu-latest

        steps:
        - name: Checkout code
          uses: actions/checkout@v3

        - name: Deploy to VPS
          uses: appleboy/ssh-action@master
          with:
            host: ${{ secrets.VPS_HOST }}
            username: ${{ secrets.VPS_USER }}
            key: ${{ secrets.VPS_SSH_PRIVATE_KEY }}
            script: |
              # Di chuyển đến thư mục dự án trên VPS
              cd /root/portfolio-website
              
              # Kéo code mới nhất từ nhánh main
              git pull origin main
              
              # Cài đặt lại dependencies nếu có thay đổi trong package.json
              npm install
              
              # Build lại dự án
              npm run build
              
              # Khởi động lại ứng dụng bằng PM2
              # 'portfolio-app' là tên bạn đã đặt khi chạy pm2 start
              pm2 restart portfolio-app
    ```

---

### Hoàn tất!

Bây giờ, mỗi khi bạn push code lên nhánh `main`, GitHub Actions sẽ tự động kích hoạt, kết nối đến VPS của bạn và thực hiện các lệnh trong file `deploy.yml`. Bạn có thể theo dõi tiến trình trong tab "Actions" trên repository GitHub của mình.
