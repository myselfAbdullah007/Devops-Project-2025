const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const dotenv = require('dotenv');
const { setupTelemetry } = require('./telemetry');
const { trace, context, SpanStatusCode } = require('@opentelemetry/api');

// Initialize telemetry and ensure it's awaited before starting the app
(async () => {
  await setupTelemetry();
  startApp();
})();

function startApp() {
  dotenv.config();

  const app = express();

  // CORS Configuration
  app.use(cors({
    origin: true, // Allow all origins in development
    methods: ['GET', 'POST', 'PUT', 'DELETE'],
    credentials: true
  }));

  // Middleware
  app.use(express.json());

  // Telemetry middleware
  app.use((req, res, next) => {
    console.log(`[TRACE] Incoming request: ${req.method} ${req.path}`);
    const tracer = trace.getTracer('express-tracer');
    const span = tracer.startSpan(`${req.method} ${req.path}`);
    
    // Add request details to span
    span.setAttributes({
      'http.method': req.method,
      'http.url': req.url,
      'http.route': req.path,
      'http.user_agent': req.headers['user-agent']
    });

    // Store span in context
    const ctx = trace.setSpan(context.active(), span);
    context.with(ctx, () => {
      next();
    });

    // End span when response is finished
    res.on('finish', () => {
      span.setAttributes({
        'http.status_code': res.statusCode
      });
      if (res.statusCode >= 400) {
        span.setStatus({ code: SpanStatusCode.ERROR });
      }
      span.end();
    });
  });

  // Health Check Endpoint
  app.get('/api/health', (req, res) => {
    const tracer = trace.getTracer('health-check');
    const span = tracer.startSpan('health-check');
    
    try {
      span.setAttributes({
        'health.status': 'checking'
      });
      
      res.status(200).json({ status: 'ok', message: 'Server is healthy' });
      
      span.setAttributes({
        'health.status': 'healthy'
      });
    } catch (error) {
      span.setStatus({ code: SpanStatusCode.ERROR, message: error.message });
      throw error;
    } finally {
      span.end();
    }
  });

  // MongoDB Connection with telemetry
  mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/mern-crud')
    .then(() => {
      const tracer = trace.getTracer('mongodb-connection');
      const span = tracer.startSpan('mongodb-connect');
      span.setAttributes({
        'db.system': 'mongodb',
        'db.operation': 'connect'
      });
      console.log('MongoDB Connected');
      span.end();
    })
    .catch(err => {
      const tracer = trace.getTracer('mongodb-connection');
      const span = tracer.startSpan('mongodb-connect');
      span.setStatus({ code: SpanStatusCode.ERROR, message: err.message });
      console.log('MongoDB Connection Error:', err);
      span.end();
    });

  // Routes
  app.use('/api/users', require('./routes/users'));

  const PORT = process.env.PORT || 5001;
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`Server is running on port ${PORT}`);
  });
} 