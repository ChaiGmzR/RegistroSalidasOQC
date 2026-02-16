require('dotenv').config();
const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const initDatabase = require('./config/initDb');

// Importar rutas
const partNumberRoutes = require('./routes/partNumber.routes');
const esdBoxRoutes = require('./routes/esdBox.routes');
const operatorRoutes = require('./routes/operator.routes');
const exitRecordRoutes = require('./routes/exitRecord.routes');
const boxScanRoutes = require('./routes/boxScan.routes');
const oqcRejectionRoutes = require('./routes/oqcRejection.routes');

const app = express();
const PORT = process.env.PORT || 3000;

// Middlewares
app.use(cors());
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// Rutas
app.use('/api/part-numbers', partNumberRoutes);
app.use('/api/esd-boxes', esdBoxRoutes);
app.use('/api/operators', operatorRoutes);
app.use('/api/exit-records', exitRecordRoutes);
app.use('/api/box-scans', boxScanRoutes);
app.use('/api/oqc-rejections', oqcRejectionRoutes);

// Ruta de estado (incluye verificación de BD)
app.get('/api/health', async (req, res) => {
  try {
    const pool = require('./config/database');
    await pool.query('SELECT 1');
    res.json({ 
      status: 'OK', 
      database: 'connected',
      message: 'OQC Exit Records API Running',
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('Health check - DB error:', error.message);
    res.status(503).json({ 
      status: 'ERROR', 
      database: 'disconnected',
      message: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Ruta raíz
app.get('/', (req, res) => {
  res.json({
    name: 'OQC Exit Records API',
    version: '1.0.0',
    company: 'Ilsan Electronics',
    endpoints: {
      partNumbers: '/api/part-numbers',
      esdBoxes: '/api/esd-boxes',
      operators: '/api/operators',
      exitRecords: '/api/exit-records',
      health: '/api/health'
    }
  });
});

// Manejo de errores
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ success: false, error: 'Error interno del servidor' });
});

// Inicializar base de datos y arrancar servidor
const startServer = async () => {
  try {
    await initDatabase();
    const server = app.listen(PORT, '0.0.0.0', () => {
      console.log(`🚀 Servidor OQC corriendo en http://localhost:${PORT}`);
      console.log(`📊 API disponible en http://localhost:${PORT}/api`);
    });

    // Mantener el servidor activo
    process.on('SIGINT', () => {
      console.log('\n🛑 Cerrando servidor...');
      server.close(() => {
        console.log('👋 Servidor cerrado correctamente');
        process.exit(0);
      });
    });
  } catch (error) {
    console.error('Error al iniciar el servidor:', error);
    process.exit(1);
  }
};

startServer();
