#!/bin/bash

# SwiftTrack VPS Kurulum Scripti
# Hostinger VPS (Ubuntu/Debian) için
# Çalıştır: chmod +x install.sh && sudo ./install.sh

set -e  # Hata durumunda dur

echo "🚀 SwiftTrack VPS Kurulumu Başlıyor..."
echo "=========================================="

# Renkler
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. Sistem Güncelleme
echo -e "${YELLOW}[1/8] Sistem paketleri güncelleniyor...${NC}"
apt-get update -y
apt-get upgrade -y

# 2. Gerekli Paketlerin Kurulumu
echo -e "${YELLOW}[2/8] Gerekli paketler kuruluyor...${NC}"
apt-get install -y     curl     wget     git     nginx     certbot     python3-certbot-nginx     ufw     software-properties-common     build-essential     pkg-config

# 3. Node.js Kurulumu (LTS)
echo -e "${YELLOW}[3/8] Node.js LTS kuruluyor...${NC}"
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# Node.js versiyon kontrolü
node_version=$(node --version)
npm_version=$(npm --version)
echo -e "${GREEN}✓ Node.js ${node_version} kuruldu${NC}"
echo -e "${GREEN}✓ npm ${npm_version} kuruldu${NC}"

# 4. PM2 Kurulumu (Process Manager)
echo -e "${YELLOW}[4/8] PM2 kuruluyor...${NC}"
npm install -g pm2
pm2 startup systemd

# 5. MongoDB Kurulumu
echo -e "${YELLOW}[5/8] MongoDB kuruluyor...${NC}"

# MongoDB için GPG key ve repo
curl -fsSL https://pgp.mongodb.com/server-7.0.asc |    gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg    --dearmor

echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" |    tee /etc/apt/sources.list.d/mongodb-org-7.0.list

apt-get update
apt-get install -y mongodb-org

# MongoDB servisini başlat
systemctl start mongod
systemctl enable mongod

echo -e "${GREEN}✓ MongoDB kuruldu ve başlatıldı${NC}"

# 6. Firewall Ayarları
echo -e "${YELLOW}[6/8] Firewall ayarları yapılıyor...${NC}"
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 5000/tcp  # API port
ufw --force enable

echo -e "${GREEN}✓ Firewall yapılandırıldı${NC}"

# 7. Proje Dizini Oluşturma
echo -e "${YELLOW}[7/8] Proje dizini oluşturuluyor...${NC}"
mkdir -p /var/www/swifttrack
cd /var/www/swifttrack

# Git repo'dan çek (veya manuel yükle)
# git clone https://github.com/kullanici/swifttrack.git .

echo -e "${YELLOW}⚠️  Proje dosyalarını /var/www/swifttrack dizinine yükleyin${NC}"
echo -e "${YELLOW}   SCP kullanarak: scp -r /local/path/* root@153.92.221.140:/var/www/swifttrack/${NC}"

# 8. Nginx Yapılandırması
echo -e "${YELLOW}[8/8] Nginx yapılandırılıyor...${NC}"

cat > /etc/nginx/sites-available/swifttrack << 'EOF'
server {
    listen 80;
    server_name 153.92.221.140;

    # Frontend (statik dosyalar)
    location / {
        root /var/www/swifttrack;
        index index.html;
        try_files $uri $uri/ /index.html;

        # Cache ayarları
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }

    # Backend API (Reverse Proxy)
    location /api {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;

        # Timeout ayarları
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Socket.io için (real-time)
    location /socket.io/ {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Güvenlik başlıkları
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Loglar
    access_log /var/log/nginx/swifttrack-access.log;
    error_log /var/log/nginx/swifttrack-error.log;
}
EOF

# Siteyi etkinleştir
ln -sf /etc/nginx/sites-available/swifttrack /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Nginx yapılandırmasını test et
nginx -t

# Nginx'i yeniden başlat
systemctl restart nginx
systemctl enable nginx

echo -e "${GREEN}✓ Nginx yapılandırıldı${NC}"

echo ""
echo "=========================================="
echo -e "${GREEN}✅ Kurulum Tamamlandı!${NC}"
echo "=========================================="
echo ""
echo "📋 Sonraki Adımlar:"
echo "1. Proje dosyalarını yükleyin:"
echo "   scp -r swifttrack-full-app.zip root@153.92.221.140:/var/www/swifttrack/"
echo ""
echo "2. Sunucuya bağlanın:"
echo "   ssh root@153.92.221.140"
echo ""
echo "3. Proje dizinine gidin:"
echo "   cd /var/www/swifttrack"
echo ""
echo "4. Backend bağımlılıklarını yükleyin:"
echo "   cd backend && npm install"
echo ""
echo "5. .env dosyasını oluşturun:"
echo "   cp .env.example .env"
echo "   nano .env  # Düzenleyin"
echo ""
echo "6. PM2 ile başlatın:"
echo "   npm run deploy"
echo ""
echo "🌐 Erişim:"
echo "   Frontend: http://153.92.221.140"
echo "   API: http://153.92.221.140/api"
echo ""
echo "📚 Detaylı bilgi için README.md'yi okuyun"
