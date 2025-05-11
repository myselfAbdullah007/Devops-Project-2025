import { WebTracerProvider } from '@opentelemetry/sdk-trace-web';
import { getWebAutoInstrumentations } from '@opentelemetry/auto-instrumentations-web';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { Resource } from '@opentelemetry/resources';
import { SemanticResourceAttributes } from '@opentelemetry/semantic-conventions';
import { BatchSpanProcessor } from '@opentelemetry/sdk-trace-base';
import { trace, context, SpanStatusCode } from '@opentelemetry/api';

// Create a custom tracer for frontend operations
const tracer = trace.getTracer('frontend-tracer');

// Function to track page views
export function trackPageView(pageName: string) {
  const span = tracer.startSpan('page-view');
  span.setAttributes({
    'page.name': pageName,
    'page.url': window.location.href,
    'page.referrer': document.referrer
  });
  span.end();
}

// Function to track user interactions
export function trackUserInteraction(action: string, details: Record<string, any> = {}) {
  const span = tracer.startSpan('user-interaction');
  span.setAttributes({
    'interaction.action': action,
    'interaction.details': JSON.stringify(details)
  });
  span.end();
}

// Function to track API calls
export function trackApiCall(url: string, method: string, status: number) {
  const span = tracer.startSpan('api-call');
  span.setAttributes({
    'http.url': url,
    'http.method': method,
    'http.status_code': status
  });
  if (status >= 400) {
    span.setStatus({ code: SpanStatusCode.ERROR });
  }
  span.end();
}

export function setupTelemetry() {
  const provider = new WebTracerProvider({
    resource: new Resource({
      [SemanticResourceAttributes.SERVICE_NAME]: 'frontend-service',
      [SemanticResourceAttributes.SERVICE_VERSION]: '1.0.0',
      [SemanticResourceAttributes.DEPLOYMENT_ENVIRONMENT]: 'development'
    }),
  });

  const exporter = new OTLPTraceExporter({
    url: 'http://otel-collector:4318/v1/traces',
  });

  provider.addSpanProcessor(new BatchSpanProcessor(exporter));

  // Register the provider with auto-instrumentations
  const instrumentations = getWebAutoInstrumentations({
    // Enable all instrumentations
    '@opentelemetry/instrumentation-document-load': {},
    '@opentelemetry/instrumentation-fetch': {},
    '@opentelemetry/instrumentation-xml-http-request': {},
    '@opentelemetry/instrumentation-user-interaction': {},
  });

  provider.register();
  instrumentations.forEach(instrumentation => instrumentation.enable());

  // Track initial page load
  trackPageView('initial-load');

  console.log('Frontend telemetry initialized');
}

export default setupTelemetry; 