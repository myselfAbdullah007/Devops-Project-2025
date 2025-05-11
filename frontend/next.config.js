/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',
  experimental: {
    instrumentationHook: true
  },
  assetPrefix: process.env.NEXT_PUBLIC_ASSET_PREFIX,
  basePath: process.env.NEXT_PUBLIC_BASE_PATH,
  images: {
    unoptimized: true
  },
  async headers() {
    return [
      {
        source: "/_next/static/:path*",
        headers: [
          {
            key: "Cache-Control",
            value: "public, max-age=31536000, immutable"
          }
        ]
      }
    ];
  }
}

module.exports = nextConfig
