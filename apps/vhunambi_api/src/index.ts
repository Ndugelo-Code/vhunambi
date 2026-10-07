import { serve } from '@hono/node-server';
import { app } from './server.js';
import { env } from './config/env.js';

console.log(`🎵 VHUNAMBI AI Music API Gateway starting on port ${env.PORT}...`);

serve(
  {
    fetch: app.fetch,
    port: env.PORT,
  },
  (info) => {
    console.log(`🚀 VHUNAMBI API Server running at http://localhost:${info.port}`);
    console.log(`   Health check: http://localhost:${info.port}/health`);
    console.log(`   Lyrics API:   http://localhost:${info.port}/v1/lyrics/generate`);
    console.log(`   Synthesis:    http://localhost:${info.port}/v1/generations`);
  },
);
