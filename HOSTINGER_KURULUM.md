# 🚀 Hostinger VPS Kurulum Rehberi

**VPS IP:** `153.92.221.140`  
**İşletim Sistemi:** Ubuntu 22.04 (önerilen)  
**Domain:** (İsteğe bağlı, IP ile de çalışır)

---

## 📋 Ön Hazırlık

### 1. VPS'e Bağlanma

```bash
# Terminal/Komut satırından bağlan
ssh root@153.92.221.140

# Şifrenizi girin (Hostinger panelinden aldığınız şifre)
```

### 2. Güvenlik Güncellemeleri (İsteğe bağlı ama önerilir)

```bash
apt-get update && apt-get upgrade -y
```

---

## 🛠️ Otomatik Kurulum (Tek Komut)

**En kolay yöntem:** Hazırladığımız scripti çalıştırın:

```bash
# 1. Scripti indir
wget https://your-domain.com/install.sh

# 2. Çalıştırılabilir yap
chmod +x install.sh

# 3. Çalıştır (5-10 dakika sürebilir)
sudo ./install.sh
```

**Script ne yapıyor?**
- ✅ Node.js 20 LTS kurar
- ✅ MongoDB 7.0 kurar ve başlatır
- ✅ Nginx web sunucusu kurar
- ✅ PM2 process manager kurar
- ✅ Firewall (UFW) yapılandırır
- ✅ Gerekli portları açar (22, 80, 443, 5000)

---

## 📦 Manuel Kurulum (Adım Adım)

Eğer otomatik script çalışmazsa veya kontrol etmek isterseniz:

### Adım 1: Node.js Kurulumu

```bash
# NodeSource reposunu ekle
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -

# Node.js ve npm kur
apt-get install -y nodejs

# Kontrol et
node --version  # v20.x.x
npm --version   # 10.x.x
```

### Adım 2: MongoDB Kurulumu

```bash
# MongoDB GPG anahtarı
curl -fsSL https://pgp.mongodb.com/server-7.0.asc |    gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor

# MongoDB reposunu ekle
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ]    https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" |    tee /etc/apt/sources.list.d/mongodb-org-7.0.list

# Kur ve başlat
apt-get update
apt-get install -y mongodb-org
systemctl start mongod
systemctl enable mongod

# Kontrol et
systemctl status mongod
```

### Adım 3: PM2 Kurulumu

```bash
npm install -g pm2
pm2 startup systemd
```

### Adım 4: Nginx Kurulumu

```bash
apt-get install -y nginx
systemctl enable nginx
```

---

## 📂 Proje Yükleme

### Yöntem 1: SCP ile Yerel Bilgisayardan Yükleme

**Windows (PowerShell/CMD):**
```powershell
# Zip dosyasını VPS'e kopyala
scp swifttrack-full-app.zip root@153.92.221.140:/var/www/

# SSH ile bağlan
ssh root@153.92.221.140

# Zip'i çıkar
cd /var/www
unzip swifttrack-full-app.zip
mv courier-app swifttrack
cd swifttrack
```

**Mac/Linux:**
```bash
scp -r /local/path/swifttrack root@153.92.221.140:/var/www/
```

### Yöntem 2: Git ile Klonlama

```bash
cd /var/www
git clone https://github.com/kullanici/swifttrack.git
```

---

## ⚙️ Backend Yapılandırması

### 1. Bağımlılıkları Yükle

```bash
cd /var/www/swifttrack/backend
npm install
```

### 2. Çevre Değişkenlerini Ayarla

```bash
cp .env.example .env
nano .env
```

**`.env` içeriği:**
```env
NODE_ENV=production
PORT=5000
MONGODB_URI=mongodb://localhost:27017/swifttrack
JWT_SECRET=swifttrack_hostinger_vps_2024_secure_key
API_URL=http://153.92.221.140/api
FRONTEND_URL=http://153.92.221.140
CORS_ORIGINS=http://153.92.221.140,http://localhost:3000
```

**Kaydet:** `CTRL+O`, `Enter`, `CTRL+X`

### 3. Test Verisi Ekle (Opsiyonel)

```bash
npm run seed
```

### 4. PM2 ile Başlat

```bash
# Log dizini oluştur
mkdir -p /var/log/swifttrack

# PM2 ile başlat
pm2 start ecosystem.config.js --env production

# PM2 kaydet (sunucu yeniden başlayınca otomatik başlasın)
pm2 save
pm2 startup
```

**Kontrol:**
```bash
pm2 status
pm2 logs swifttrack-api
```

---

## 🌐 Nginx Yapılandırması

### 1. Site Konfigürasyonu

```bash
nano /etc/nginx/sites-available/swifttrack
```

**İçerik:**
```nginx
server {
    listen 80;
    server_name 153.92.221.140;

    # Frontend (statik dosyalar)
    location / {
        root /var/www/swifttrack;
        index index.html;
        try_files $uri $uri/ /index.html;
    }

    # Backend API
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
    }

    # Socket.io
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
}
```

### 2. Siteyi Etkinleştir

```bash
ln -sf /etc/nginx/sites-available/swifttrack /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl restart nginx
```

---

## 🔒 SSL Sertifikası (HTTPS) - Ücretsiz Let's Encrypt

### 1. Certbot Kurulumu

```bash
apt-get install -y certbot python3-certbot-nginx
```

### 2. Sertifika Al (Domain varsa)

Eğer domaininiz varsa (örn: `swifttrack.sizindomain.com`):

```bash
certbot --nginx -d swifttrack.sizindomain.com
```

**IP adresi için SSL:**  
IP adresine SSL sertifikası alınamaz. Domain satın almanız gerekir.  
Geçici çözüm: Cloudflare kullanabilirsiniz.

---

## 🧪 Test ve Kontrol

### 1. API Testi

```bash
# Health check
curl http://153.92.221.140/api/health

# Login test
curl -X POST http://153.92.221.140/api/auth/login   -H "Content-Type: application/json"   -d '{"email":"ahmet@swifttrack.com","password":"password123"}'
```

### 2. Tarayıcıdan Test

```
http://153.92.221.140
```

**Giriş:**
- Email: `ahmet@swifttrack.com`
- Şifre: `password123`

---

## 🔧 Yönetim Komutları

### PM2 (Process Manager)

```bash
# Durum görüntüle
pm2 status

# Logları izle
pm2 logs swifttrack-api

# Yeniden başlat
pm2 restart swifttrack-api

# Durdur
pm2 stop swifttrack-api

# Başlat
pm2 start swifttrack-api

# Monitör (CPU, RAM, vb.)
pm2 monit
```

### MongoDB

```bash
# MongoDB shell'e gir
mongosh

# Veritabanlarını listele
show dbs

# SwiftTrack veritabanını kullan
use swifttrack

# Koleksiyonları listele
show collections

# Kuryeleri görüntüle
db.couriers.find().pretty()

# Çık
exit
```

### Nginx

```bash
# Yapılandırmayı test et
nginx -t

# Yeniden başlat
systemctl restart nginx

# Durum görüntüle
systemctl status nginx

# Logları izle
tail -f /var/log/nginx/error.log
tail -f /var/log/nginx/access.log
```

### Sistem

```bash
# Bellek kullanımı
free -h

# Disk kullanımı
df -h

# CPU kullanımı
top

# Port dinleyenler
netstat -tlnp
```

---

## 🆘 Sorun Giderme

### 1. "Connection Refused" Hatası

```bash
# Firewall kontrolü
ufw status

# Port aç
ufw allow 5000/tcp
ufw allow 80/tcp

# MongoDB çalışıyor mu?
systemctl status mongod

# Node.js çalışıyor mu?
pm2 status
```

### 2. "403 Forbidden" Hatası

```bash
# Dosya izinleri
chown -R www-data:www-data /var/www/swifttrack
chmod -R 755 /var/www/swifttrack
```

### 3. "502 Bad Gateway" Hatası

```bash
# Backend çalışıyor mu?
pm2 logs swifttrack-api

# Port dinleniyor mu?
netstat -tlnp | grep 5000
```

### 4. MongoDB Bağlantı Hatası

```bash
# MongoDB servis durumu
systemctl status mongod

# MongoDB'yi yeniden başlat
systemctl restart mongod

# Logları kontrol et
tail -f /var/log/mongodb/mongod.log
```

---

## 📊 Performans Optimizasyonu

### 1. MongoDB İndexleme

```bash
mongosh
use swifttrack
db.orders.createIndex({ "assignedTo": 1, "status": 1 })
db.orders.createIndex({ "orderNumber": 1 })
db.couriers.createIndex({ "email": 1 })
exit
```

### 2. Nginx Cache

```nginx
# /etc/nginx/sites-available/swifttrack içine ekle
location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}
```

### 3. PM2 Cluster Mode (Çok çekirdekli VPS için)

```javascript
// ecosystem.config.js
deploy: {
  production: {
    instances: 'max',  // Tüm CPU çekirdeklerini kullan
    exec_mode: 'cluster'
  }
}
```

---

## 🔄 Güncelleme (Yeni Versiyon Yükleme)

```bash
cd /var/www/swifttrack

# Eski versiyonu yedekle
cp -r backend backend.backup.$(date +%Y%m%d)

# Yeni dosyaları yükle (SCP veya Git pull)
scp -r /local/new-version/* root@153.92.221.140:/var/www/swifttrack/

# Bağımlılıkları güncelle
cd backend
npm install

# Yeniden başlat
pm2 restart swifttrack-api

# Nginx yeniden yükle
systemctl reload nginx
```

---

## 📞 Destek

Sorun yaşarsanız:

1. **Logları kontrol edin:**
   ```bash
   pm2 logs
   tail -f /var/log/nginx/error.log
   ```

2. **Hostinger Destek:**
   - Hostinger kontrol paneli üzerinden ticket açabilirsiniz

3. **GitHub Issues:**
   - Problemi detaylı açıklayarak issue açın

---

**🎉 Tebrikler! SwiftTrack artık Hostinger VPS'inizde çalışıyor!**

Erişim: http://153.92.221.140
