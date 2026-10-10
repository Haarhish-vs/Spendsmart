const express = require('express');
const cors = require('cors');
const routes = require('./routes');

const app = express();

app.use(cors());
app.use(express.json());

// Health check endpoint
app.get('/api/v1/health', (req, res) => {
  res.json({
    success: true,
    message: 'SpendSmart API is running',
  });
});

// Mount all API v1 routes
app.use('/api/v1', routes);

module.exports = app;
