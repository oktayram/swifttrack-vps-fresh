const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const http = require('http');
const socketIo = require('socket.io');
const morgan = require('morgan');
require('dotenv').config();

const app = express();
const server = http.createServer(app);

// CORS yapılandırması
const corsOptions = {
  origin: process.env.CORS_ORIGINS?.split(',') || ['http://153.92.221.140', 'http://localhost:3000'],
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true
};

const io = socketIo(server, {
  cors: corsOptions
});

// Security Middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "blob:"],
    },
  },
}));

// Rate Limiting
const limiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000, // 15 dakika
  max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 100,
  message: {
    success: false,
    message: 'Çok fazla istek gönderdiniz. Lütfen daha sonra tekrar deneyin.'
  },
  standardHeaders: true,
  legacyHeaders: false,
});

app.use('/api/', limiter);

// Logging
app.use(morgan('combined'));

// Body parsing
app.use(cors(corsOptions));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// MongoDB Bağlantısı
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/swifttrack';

mongoose.connect(MONGODB_URI)
  .then(() => console.log('✅ MongoDB bağlantısı başarılı'))
  .catch(err => {
    console.error('❌ MongoDB bağlantı hatası:', err);
    process.exit(1);
  });

// MongoDB bağlantı olayları
mongoose.connection.on('connected', () => {
  console.log('🗄️  MongoDB bağlı');
});

mongoose.connection.on('error', (err) => {
  console.error('🗄️  MongoDB hata:', err);
});

mongoose.connection.on('disconnected', () => {
  console.log('🗄️  MongoDB bağlantısı koptu');
});

// Routes
app.use('/api/auth', require('./routes/auth'));
app.use('/api/orders', require('./routes/orders'));
app.use('/api/couriers', require('./routes/couriers'));
app.use('/api/stats', require('./routes/stats'));

// Socket.io - Real-time updates
io.on('connection', (socket) => {
  console.log('🔌 Yeni bağlantı:', socket.id);

  socket.on('join', (courierId) => {
    socket.join(courierId);
    console.log(`👤 Koerier ${courierId} odaya katıldı`);
  });

  socket.on('order-update', (data) => {
    socket.to(data.courierId).emit('order-updated', data);
  });

  socket.on('courier-location', (data) => {
    // Kurye konumunu diğer client'lara bildir (admin paneli için)
    socket.broadcast.emit('location-update', data);
  });

  socket.on('disconnect', () => {
    console.log('❌ Bağlantı koptu:', socket.id);
  });
});

// Socket.io'yu global olarak erişilebilir yap
app.set('io', io);

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    timestamp: new Date().toISOString(),
    database: mongoose.connection.readyState === 1 ? 'connected' : 'disconnected',
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    version: process.env.npm_package_version || '1.0.0'
  });
});

// Static files (frontend) - Production için
if (process.env.NODE_ENV === 'production') {
  const path = require('path');
  app.use(express.static(path.join(__dirname, '../')));

  app.get('*', (req, res) => {
    res.sendFile(path.join(__dirname, '../index.html'));
  });
}

// 404 handler
app.use((req, res) => {
  res.status(404).json({ 
    success: false,
    message: 'Endpoint bulunamadı',
    path: req.path,
    method: req.method
  });
});

// Error handler
app.use((err, req, res, next) => {
  console.error('❌ Hata:', err);

  // Mongoose validation error
  if (err.name === 'ValidationError') {
    return res.status(400).json({
      success: false,
      message: 'Validasyon hatası',
      errors: Object.values(err.errors).map(e => e.message)
    });
  }

  // JWT error
  if (err.name === 'JsonWebTokenError') {
    return res.status(401).json({
      success: false,
      message: 'Geçersiz token'
    });
  }

  // MongoDB duplicate key
  if (err.code === 11000) {
    return res.status(409).json({
      success: false,
      message: 'Bu kayıt zaten mevcut'
    });
  }

  res.status(err.status || 500).json({ 
    success: false,
    message: process.env.NODE_ENV === 'production' 
      ? 'Sunucu hatası oluştu' 
      : err.message,
    ...(process.env.NODE_ENV !== 'production' && { stack: err.stack })
  });
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM alındı, sunucu kapatılıyor...');
  server.close(() => {
    console.log('Sunucu kapandı');
    mongoose.connection.close(false, () => {
      console.log('MongoDB bağlantısı kapandı');
      process.exit(0);
    });
  });
});

const PORT = process.env.PORT || 5000;
server.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Server ${PORT} portunda çalışıyor`);
  console.log(`📱 API: http://153.92.221.140:${PORT}/api`);
  console.log(`🔧 Environment: ${process.env.NODE_ENV || 'development'}`);
});

module.exports = { app, io };
