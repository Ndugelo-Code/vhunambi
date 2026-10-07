import dotenv from 'dotenv';
dotenv.config();

export interface AppEnv {
  PORT: number;
  NODE_ENV: string;
  RUNPOD_API_KEY?: string;
  RUNPOD_ENDPOINT_ID?: string;
  ANTHROPIC_API_KEY?: string;
  GROK_API_KEY?: string;
  ZR_LLM_PROVIDER: 'claude' | 'grok' | 'mock';
  R2_ACCESS_KEY_ID?: string;
  R2_SECRET_ACCESS_KEY?: string;
  R2_ENDPOINT?: string;
  R2_BUCKET: string;
  ZR_WEBHOOK_SECRET: string;
}

export const env: AppEnv = {
  PORT: Number(process.env.PORT || 3000),
  NODE_ENV: process.env.NODE_ENV || 'development',
  RUNPOD_API_KEY: process.env.RUNPOD_API_KEY || undefined,
  RUNPOD_ENDPOINT_ID: process.env.RUNPOD_ENDPOINT_ID || undefined,
  ANTHROPIC_API_KEY: process.env.ANTHROPIC_API_KEY || undefined,
  GROK_API_KEY: process.env.GROK_API_KEY || undefined,
  ZR_LLM_PROVIDER: (process.env.ZR_LLM_PROVIDER as 'claude' | 'grok' | 'mock') || 'mock',
  R2_ACCESS_KEY_ID: process.env.R2_ACCESS_KEY_ID || undefined,
  R2_SECRET_ACCESS_KEY: process.env.R2_SECRET_ACCESS_KEY || undefined,
  R2_ENDPOINT: process.env.R2_ENDPOINT || undefined,
  R2_BUCKET: process.env.R2_BUCKET || 'vhunambi-audio',
  ZR_WEBHOOK_SECRET: process.env.ZR_WEBHOOK_SECRET || 'dev_webhook_secret_vhunambi_2026',
};
