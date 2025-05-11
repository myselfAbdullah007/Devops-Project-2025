# OpenTelemetry Setup Guide

This document explains how OpenTelemetry is set up in our MERN stack application for distributed tracing.

## Architecture Overview

Our application uses the following components for distributed tracing:
- OpenTelemetry Collector (for receiving and processing traces)
- Jaeger (for trace visualization and analysis)
- Node.js OpenTelemetry SDK (for instrumenting our backend)


## Components

### 1. OpenTelemetry Collector
The collector acts as a central hub for receiving, processing, and exporting traces. It's configured to:
- Receive traces via gRPC (port 4317) and HTTP (port 4318)
- Process traces using batch and memory limiter processors
- Export traces to Jaeger

Configuration (`otel-collector-config.yaml`):
```yaml
receivers:
  otlp:
    protocols:
      http:
        endpoint: 0.0.0.0:4318
      grpc:
        endpoint: 0.0.0.0:4317

processors:
  batch:
    timeout: 1s
    send_batch_size: 1024
  memory_limiter:
    check_interval: 1s
    limit_mib: 1500
    spike_limit_mib: 512

exporters:
  otlp:
    endpoint: jaeger:4317
    tls:
      insecure: true
  debug:
    verbosity: detailed

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlp, debug]
```

### 2. Backend Instrumentation
Our Node.js backend is instrumented using the OpenTelemetry SDK. Key features:
- Automatic instrumentation for HTTP, Express, and MongoDB
- Custom spans for API endpoints and database operations
- gRPC exporter for sending traces to the collector

Configuration (`backend/src/utils/telemetry.ts`):
```typescript
export function setupTelemetry() {
  const sdk = new NodeSDK({
    resource: new Resource({
      [SemanticResourceAttributes.SERVICE_NAME]: 'backend-service',
      [SemanticResourceAttributes.SERVICE_VERSION]: '1.0.0',
      [SemanticResourceAttributes.DEPLOYMENT_ENVIRONMENT]: 'development'
    }),
    traceExporter: new OTLPTraceExporter({
      url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://otel-collector:4317',
    }),
    instrumentations: [getNodeAutoInstrumentations()]
  });
}
```

### 3. Docker Compose Setup
All services are connected through a Docker network for proper communication:

```yaml
services:
  otel-collector:
    image: otel/opentelemetry-collector-contrib:latest
    ports:
      - "4317:4317"   # OTLP gRPC
      - "4318:4318"   # OTLP HTTP
    networks:
      - app-network

  jaeger:
    image: jaegertracing/all-in-one:latest
    ports:
      - "16686:16686"  # Jaeger UI
    networks:
      - app-network

  backend:
    environment:
      - OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317
    networks:
      - app-network
```

## How to Use

1. Start the services:
   ```bash
   docker-compose up --build
   ```

2. Access the Jaeger UI:
   - Open http://localhost:16686 in your browser
   - Select "backend-service" from the service dropdown
   - Click "Find Traces"

3. Make requests to your backend API to generate traces

### Jaeger UI Example
![Ope](Screenshots/opentelemetry1.png)
![Jaeger UI](Screenshots/opentelemetry2.png)

## Custom Tracing

We've implemented custom tracing for:
- API endpoints (method, path, status code)
- Database operations (operation type, collection, duration)

Example of custom span creation:
```typescript
export function trackApiEndpoint(method: string, path: string, status: number) {
  const span = tracer.startSpan('api-endpoint');
  span.setAttributes({
    'http.method': method,
    'http.route': path,
    'http.status_code': status
  });
  if (status >= 400) {
    span.setStatus({ code: SpanStatusCode.ERROR });
  }
  span.end();
}
```

## Dependencies

Key OpenTelemetry packages used:
- `@opentelemetry/api`
- `@opentelemetry/sdk-node`
- `@opentelemetry/auto-instrumentations-node`
- `@opentelemetry/exporter-trace-otlp-grpc`
- `@opentelemetry/resources`
- `@opentelemetry/semantic-conventions`

## Troubleshooting

1. If traces aren't appearing in Jaeger:
   - Check if the backend is connected to the collector (logs should show "Backend telemetry initialized")
   - Verify the collector is receiving traces (check collector logs)
   - Ensure all services are on the same Docker network

2. Common issues:
   - Network connectivity between services
   - Incorrect endpoint URLs
   - Missing environment variables
   - Version mismatches between OpenTelemetry packages

