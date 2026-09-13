
# ============================================================
# STAGE 1 — BUILD
# ============================================================

FROM node:22-alpine AS builder

WORKDIR /app

# Instala exatamente as versões do package-lock.json.
# Mantém devDependencies disponíveis para o TypeScript.
COPY package.json package-lock.json ./
RUN npm ci

# Copia somente os arquivos necessários para o build.
COPY tsconfig.json ./
COPY src ./src

# Compila TypeScript para dist/
RUN npm run build

# Remove dependências de desenvolvimento.
RUN npm prune --omit=dev


# ============================================================
# STAGE 2 — RUNTIME
# ============================================================

FROM node:22-alpine AS runtime

ENV NODE_ENV=production \
    PORT=3000

# Usuário sem privilégios.
RUN addgroup -S appgroup \
    && adduser -S appuser -G appgroup

WORKDIR /app

# Copia somente o necessário para execução.
COPY --from=builder --chown=appuser:appgroup /app/node_modules ./node_modules
COPY --from=builder --chown=appuser:appgroup /app/dist ./dist
COPY --from=builder --chown=appuser:appgroup /app/package.json ./package.json

USER appuser

EXPOSE 3000

# Verifica a saúde da API.
HEALTHCHECK --interval=30s \
    --timeout=5s \
    --start-period=20s \
    --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://127.0.0.1:3000/api/health || exit 1

CMD ["node", "dist/server.js"]
