const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const dotenv = require('dotenv');
const { setupTelemetry } = require('./telemetry');
const { trace, context, SpanStatusCode } = require('@opentelemetry/api');
const promClient = require('prom-client');

// Initialize Prometheus metrics
const collectDefaultMetrics = promClient.collectDefaultMetrics;
collectDefaultMetrics({ timeout: 5000 });

// Create custom metrics
const httpRequestDurationMicroseconds = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.1, 0.5, 1, 2, 5]
});

const httpRequestsTotal = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code']
});

const activeRequests = new promClient.Gauge({
  name: 'http_requests_in_progress',
  help: 'Number of HTTP requests in progress',
  labelNames: ['method', 'route']
});

const requestSize = new promClient.Histogram({
  name: 'http_request_size_bytes',
  help: 'Size of HTTP requests in bytes',
  labelNames: ['method', 'route'],
  buckets: [100, 500, 1000, 5000, 10000]
});

const responseSize = new promClient.Histogram({
  name: 'http_response_size_bytes',
  help: 'Size of HTTP responses in bytes',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [100, 500, 1000, 5000, 10000]
});

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

  // Prometheus metrics middleware
  app.use((req, res, next) => {
    const start = Date.now();
    const route = req.route ? req.route.path : req.path;
    
    // Track request size
    const requestSizeBytes = parseInt(req.headers['content-length'] || '0');
    requestSize.labels(req.method, route).observe(requestSizeBytes);
    
    // Increment active requests
    activeRequests.labels(req.method, route).inc();

    // Track response
    const originalSend = res.send;
    res.send = function (body) {
      const responseSizeBytes = Buffer.byteLength(body || '');
      responseSize.labels(req.method, route, res.statusCode.toString()).observe(responseSizeBytes);
      return originalSend.call(this, body);
    };

    res.on('finish', () => {
      const duration = Date.now() - start;
      const statusCode = res.statusCode.toString();
      
      // Record request duration
      httpRequestDurationMicroseconds
        .labels(req.method, route, statusCode)
        .observe(duration / 1000);
      
      // Increment total requests
      httpRequestsTotal
        .labels(req.method, route, statusCode)
        .inc();
      
      // Decrement active requests
      activeRequests.labels(req.method, route).dec();
    });
    next();
  });

  // Telemetry middleware
  app.use((req, res, next) => {
    console.log(`[TRACE] Incoming request: ${req.method} ${req.path}`);
    const tracer = trace.getTracer('express-tracer');
    const span = tracer.startSpan(`${req.method} ${req.path}`);
    
    span.setAttributes({
      'http.method': req.method,
      'http.url': req.url,
      'http.route': req.path,
      'http.user_agent': req.headers['user-agent'],
      'http.request_size': req.headers['content-length'] || '0',
      'http.client_ip': req.ip
    });

    const ctx = trace.setSpan(context.active(), span);
    context.with(ctx, () => {
      next();
    });

    res.on('finish', () => {
      span.setAttributes({
        'http.status_code': res.statusCode,
        'http.response_size': res.getHeader('content-length') || '0'
      });
      if (res.statusCode >= 400) {
        span.setStatus({ code: SpanStatusCode.ERROR });
      }
      span.end();
    });
  });

  // Prometheus metrics endpoint
  app.get('/metrics', async (req, res) => {
    res.set('Content-Type', promClient.register.contentType);
    res.end(await promClient.register.metrics());
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