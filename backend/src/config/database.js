require('dotenv').config();
const mysql = require('mysql2/promise');

const numberFromEnv = (value, fallback) => {
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
};

const pool = mysql.createPool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  connectTimeout: numberFromEnv(process.env.DB_CONNECT_TIMEOUT_MS, 10000),
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  timezone: process.env.DB_TIMEZONE || '-06:00',
  dateStrings: true
});

module.exports = pool;
