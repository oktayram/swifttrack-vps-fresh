module.exports = {
  apps: [{
    name: 'swifttrack-api',
    script: './server.js',
    instances: 1,  // VPS için tek instance, daha fazla RAM varsa 'max' yapabilirsiniz
    exec_mode: 'fork',
    env: {
      NODE_ENV: 'production',
      PORT: 5000
    },
    env_production: {
      NODE_ENV: 'production'
    },

    // Log ayarları
    log_file: '/var/log/swifttrack/combined.log',
    out_file: '/var/log/swifttrack/out.log',
    error_file: '/var/log/swifttrack/error.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z',

    // Bellek limitleri
    max_memory_restart: '500M',  // 500MB sonra restart

    // Auto-restart
    autorestart: true,
    max_restarts: 10,
    min_uptime: '10s',

    // Güvenlik
    kill_timeout: 5000,
    listen_timeout: 10000,

    // Monitoring
    monitoring: true,
    pmx: true,

    // Cluster mode (isteğe bağlı, daha fazla CPU varsa)
    // instances: 2,
    // exec_mode: 'cluster'
  }],

  deploy: {
    production: {
      user: 'root',
      host: '153.92.221.140',
      ref: 'origin/main',
      repo: 'git@github.com:username/swifttrack.git',
      path: '/var/www/swifttrack',
      'post-deploy': 'cd backend && npm install && pm2 reload ecosystem.config.js --env production'
    }
  }
};
