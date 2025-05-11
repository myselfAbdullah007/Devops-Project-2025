import type { AppProps } from 'next/app';
import { useEffect } from 'react';
import setupTelemetry from '../utils/telemetry';

export default function App({ Component, pageProps }: AppProps) {
  useEffect(() => {
    // Initialize telemetry on the client side
    if (typeof window !== 'undefined') {
      setupTelemetry();
    }
  }, []);

  return <Component {...pageProps} />;
} 