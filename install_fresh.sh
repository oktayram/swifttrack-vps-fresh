#!/bin/bash

# =============================================================================
# SWIFTTRACK - SIFIRDAN VPS KURULUM SCRIPTI
# Hostinger VPS (Ubuntu/Debian) - Fresh Install
# IP: 153.92.221.140
# =============================================================================

set -e  # Hata durumunda dur

# Renkler
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log fonksiyonu
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
}

# =============================================================================
# 1. SISTEM GUNCELLEME
# =============================================================================
log "1/10 - Sistem paketleri güncelleniyor..."
apt-get update -y > /dev/null 2>&1
apt-get upgrade -y > /dev/null 2>&1
success "Sistem güncellendi"

# =============================================================================
# 2. TEMEL PAKETLER
# =============================================================================
log "2/10 - Temel paketler kuruluyor..."
apt-get install -y     curl     wget     git     nano     unzip     build-essential     software-properties-common     apt-transport-https     ca-certificates     gnupg     lsb-release     ufw     net-tools     htop     > /dev/null 2>&1
success "Temel paketler kuruldu"

# =============================================================================
# 3. NODE.JS KURULUMU (LTS)
# =============================================================================
log "3/10 - Node.js LTS kuruluyor..."

# Eski Node.js varsa kaldır
apt-get remove -y nodejs npm > /dev/null 2>&1 || true

# NodeSource reposu
curl -fsSL https://deb.nodesource.com/setup_20.x | bash - > /dev/null 2>&1
apt-get install -y nodejs > /dev/null 2>&1

# Versiyon kontrol
NODE_VERSION=$(node --version)
NPM_VERSION=$(npm --version)
success "Node.js ${NODE_VERSION} kuruldu"
success "npm ${NPM_VERSION} kuruldu"

# =============================================================================
# 4. PM2 KURULUMU (Process Manager)
# =============================================================================
log "4/10 - PM2 kuruluyor..."
npm install -g pm2 > /dev/null 2>&1

# PM2 startup scripti
pm2 startup systemd -u root --hp /root > /dev/null 2>&1
success "PM2 kuruldu ve yapılandırıldı"

# =============================================================================
# 5. MONGODB KURULUMU
# =============================================================================
log "5/10 - MongoDB kuruluyor..."

# MongoDB GPG anahtarı
curl -fsSL https://pgp.mongodb.com/server-7.0.asc |    gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor > /dev/null 2>&1

# MongoDB reposu
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ]    https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/7.0 multiverse" |    tee /etc/apt/sources.list.d/mongodb-org-7.0.list > /dev/null 2>&1

apt-get update > /dev/null 2>&1
apt-get install -y mongodb-org > /dev/null 2>&1

# MongoDB servisini başlat ve etkinleştir
systemctl start mongod > /dev/null 2>&1
systemctl enable mongod > /dev/null 2>&1

# Başlangıçta başlaması için
systemctl daemon-reload > /dev/null 2>&1

success "MongoDB kuruldu ve başlatıldı"

# =============================================================================
# 6. NGINX KURULUMU
# =============================================================================
log "6/10 - Nginx kuruluyor..."
apt-get install -y nginx > /dev/null 2>&1

# Nginx'i başlat
systemctl start nginx > /dev/null 2>&1
systemctl enable nginx > /dev/null 2>&1

success "Nginx kuruldu ve başlatıldı"

# =============================================================================
# 7. FIREWALL (UFW) YAPILANDIRMASI
# =============================================================================
log "7/10 - Firewall yapılandırılıyor..."

# Varsayılan politikalar
ufw default deny incoming > /dev/null 2>&1
ufw default allow outgoing > /dev/null 2>&1

# Portları aç
ufw allow 22/tcp > /dev/null 2>&1    # SSH
ufw allow 80/tcp > /dev/null 2>&1    # HTTP
ufw allow 443/tcp > /dev/null 2>&1   # HTTPS
ufw allow 5000/tcp > /dev/null 2>&1  # API (internal)

# Firewall'u etkinleştir (sorarsa 'y' ile onayla)
echo "y" | ufw enable > /dev/null 2>&1

success "Firewall yapılandırıldı (Portlar: 22, 80, 443, 5000)"

# =============================================================================
# 8. PROJE DIZINI OLUSTURMA
# =============================================================================
log "8/10 - Proje dizini oluşturuluyor..."

mkdir -p /var/www/swifttrack
mkdir -p /var/log/swifttrack
mkdir -p /var/log/nginx

# Log dosyaları
touch /var/log/swifttrack/out.log
touch /var/log/swifttrack/error.log
touch /var/log/swifttrack/combined.log

success "Proje dizini hazır: /var/www/swifttrack"

# =============================================================================
# 9. NGINX YAPILANDIRMASI
# =============================================================================
log "9/10 - Nginx yapılandırılıyor..."

# Nginx config dosyası
cat > /etc/nginx/sites-available/swifttrack << 'EOF'
server {
    listen 80;
    server_name 153.92.221.140;

    # Güvenlik başlıkları
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

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

    # Loglar
    access_log /var/log/nginx/swifttrack-access.log;
    error_log /var/log/nginx/swifttrack-error.log;
}
EOF

# Varsayılan siteyi kaldır ve yenisini etkinleştir
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/swifttrack /etc/nginx/sites-enabled/

# Nginx yapılandırmasını test et
nginx -t > /dev/null 2>&1

# Nginx'i yeniden başlat
systemctl restart nginx > /dev/null 2>&1

success "Nginx yapılandırıldı"

# =============================================================================
# 10. KONTROL VE SONUC
# =============================================================================
log "10/10 - Kurulum kontrol ediliyor..."

# Servisleri kontrol et
NGINX_STATUS=$(systemctl is-active nginx)
MONGO_STATUS=$(systemctl is-active mongod)
NODE_STATUS=$(which node > /dev/null && echo "active" || echo "inactive")

echo ""
echo "=========================================="
echo -e "${GREEN}✅ KURULUM TAMAMLANDI!${NC}"
echo "=========================================="
echo ""
echo "📊 Servis Durumları:"
echo "  • Nginx:    ${NGINX_STATUS}"
echo "  • MongoDB:  ${MONGO_STATUS}"
echo "  • Node.js:  ${NODE_STATUS}"
echo ""
echo "📂 Proje Dizini:"
echo "  /var/www/swifttrack"
echo ""
echo "🌐 Erişim Bilgileri:"
echo "  • VPS IP:     153.92.221.140"
echo "  • Website:    http://153.92.221.140"
echo "  • API:        http://153.92.221.140/api"
echo "  • Health:     http://153.92.221.140/api/health"
echo ""
echo "📋 SONRAKI ADIMLAR:"
echo ""
echo "1. Proje dosyalarını yükleyin:"
echo "   scp -r swifttrack/* root@153.92.221.140:/var/www/swifttrack/"
echo ""
echo "2. Backend bağımlılıklarını yükleyin:"
echo "   cd /var/www/swifttrack/backend"
echo "   npm install"
echo ""
echo "3. Çevre değişkenlerini ayarlayın:"
echo "   cp .env.production .env"
echo "   nano .env  # JWT_SECRET değiştirin"
echo ""
echo "4. Test verisi ekleyin (isteğe bağlı):"
echo "   npm run seed"
echo ""
echo "5. Uygulamayı başlatın:"
echo "   npm run deploy"
echo ""
echo "🔧 YÖNETİM KOMUTLARI:"
echo "   pm2 status              # Durum görüntüle"
echo "   pm2 logs                # Logları izle"
echo "   pm2 restart all         # Tümünü yeniden başlat"
echo "   systemctl status nginx  # Nginx durumu"
echo "   systemctl status mongod # MongoDB durumu"
echo ""
echo "📚 Detaylı bilgi için:"
echo "   cat /var/www/swifttrack/HOSTINGER_KURULUM.md"
echo ""
echo "=========================================="
