# ── Multi-Stage Production Dockerfile for Vhunambi API Gateway ────────────────
# Target: Production Cloud Deployment (Node.js 22 LTS on Alpine Linux)

# ── Stage 1: Build & Type Compilation ──────────────────────────────────────────
FROM node:22-alpine AS builder

WORKDIR /app

# Enable pnpm via Corepack
RUN corepack enable && corepack prepare pnpm@latest --activate

# Copy dependency manifests
COPY package.json pnpm-lock.yaml tsconfig.json ./

# Install all dependencies (including devDependencies for TypeScript compilation)
RUN pnpm install --frozen-lockfile

# Copy source tree
COPY src/ ./src/

# Compile TypeScript to JavaScript in /app/dist
RUN pnpm build

# Prune devDependencies to keep production modules lean
RUN pnpm prune --prod

# ── Stage 2: Production Distroless/Alpine Runner ────────────────────────────────
FROM node:22-alpine AS runner

WORKDIR /app

# Set production environment flags
ENV NODE_ENV=production
ENV PORT=3000

# Install wget (if not present) for container orchestrator health checks
RUN apk add --no-cache wget

# Create application directory with non-root ownership
RUN chown -R node:node /app

# Copy production artifacts from builder stage
COPY --from=builder --chown=node:node /app/package.json ./package.json
COPY --from=builder --chown=node:node /app/node_modules ./node_modules
COPY --from=builder --chown=node:node /app/dist ./dist

# Switch to non-root user for hardened security posture
USER node

# Expose standard API Gateway port
EXPOSE 3000

# Orchestrator Health Check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

# Start autonomous API Gateway
CMD ["node", "dist/index.js"]
