const express = require('express');
const cors = require('cors');
const routes = require('./routes');

const app = express();

app.use(cors());
app.use(express.json());

// Root welcome & status endpoint
app.get('/', (req, res) => {
  res.json({
    success: true,
    message: 'Welcome to SpendSmart API server',
    status: 'healthy',
    timestamp: new Date().toISOString(),
  });
});

// Health check endpoint
app.get('/api/v1/health', (req, res) => {
  res.json({
    success: true,
    message: 'SpendSmart API is running',
  });
});

// Mount all API v1 routes
app.use('/api/v1', routes);

// Handle 404 for undefined routes
const notFoundMiddleware = require('./middleware/not-found.middleware');
app.use(notFoundMiddleware);

// Centralized error handler
const errorMiddleware = require('./middleware/error.middleware');
app.use(errorMiddleware);

module.exports = app;
