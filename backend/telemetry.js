const opentelemetry = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-http');
const { Resource } = require('@opentelemetry/resources');
const { SemanticResourceAttributes } = require('@opentelemetry/semantic-conventions');

async function setupTelemetry() {
  const traceExporter = new OTLPTraceExporter({
    url: 'http://otel-collector:4318/v1/traces',
    headers: {},
    timeoutMillis: 15000,
  });

  const sdk = new opentelemetry.NodeSDK({
    resource: new Resource({
      [SemanticResourceAttributes.SERVICE_NAME]: 'backend-service',
      [SemanticResourceAttributes.SERVICE_VERSION]: '1.0.0',
      [SemanticResourceAttributes.DEPLOYMENT_ENVIRONMENT]: 'development'
    }),
    traceExporter: traceExporter,
    instrumentations: [getNodeAutoInstrumentations()],
  });

  try {
    await sdk.start();
    console.log('Tracing initialized');
  } catch (error) {
    console.error('Error initializing tracing:', error);
  }

  process.on('SIGTERM', () => {
    sdk.shutdown()
      .then(() => console.log('Tracing terminated'))
      .catch((error) => console.error('Error terminating tracing:', error))
      .finally(() => process.exit(0));
  });
}

module.exports = { setupTelemetry }; 