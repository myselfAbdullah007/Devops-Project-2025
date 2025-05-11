import { NodeSDK } from '@opentelemetry/sdk-node';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-grpc';
import { Resource } from '@opentelemetry/resources';
import { SemanticResourceAttributes } from '@opentelemetry/semantic-conventions';
import { trace, context, SpanStatusCode } from '@opentelemetry/api';

// Create a custom tracer for backend operations
const tracer = trace.getTracer('backend-tracer');

// Function to track API endpoints
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

// Function to track database operations
export function trackDatabaseOperation(operation: string, collection: string, duration: number) {
  const span = tracer.startSpan('database-operation');
  span.setAttributes({
    'db.operation': operation,
    'db.collection': collection,
    'db.duration_ms': duration
  });
  span.end();
}

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
  try {
    sdk.start();
    console.log('Backend telemetry initialized with gRPC exporter');
  } catch (error) {
    console.error('Error initializing backend telemetry:', error);
  }

  // Graceful shutdown
  process.on('SIGTERM', () => {
    sdk.shutdown()
      .then(() => console.log('Telemetry terminated'))
      .catch((error) => console.error('Error terminating telemetry:', error))
      .finally(() => process.exit(0));
  });
}

export default setupTelemetry; 