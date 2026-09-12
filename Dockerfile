FROM node:20-alpine AS builder

WORKDIR /app

# Copia apenas os manifests primeiro (melhor cache de camadas)
COPY package*.json ./

# Instala TODAS as dependências (inclui devDependencies para o tsc)
RUN npm ci

# Copia o código-fonte e configs necessários para o build
COPY tsconfig.json ./
COPY src ./src

# Compila TypeScript -> dist/
RUN npm run build

# Remove devDependencies para deixar node_modules enxuto
RUN npm prune --omit=dev


# STAGE 2: RUNTIME


FROM node:20-alpine AS runtime

# Cria usuário sem privilégios (não usar root)
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Variáveis de ambiente seguras para produção
ENV NODE_ENV=production \
    PORT=3000

# Copia apenas o necessário da stage anterior
COPY --from=builder --chown=appuser:appgroup /app/node_modules ./node_modules
COPY --from=builder --chown=appuser:appgroup /app/dist ./dist
COPY --from=builder --chown=appuser:appgroup /app/package*.json ./

# Troca para o usuário sem privilégios
USER appuser

# Expõe a porta da aplicação
EXPOSE 3000

# Healthcheck usando o endpoint já existente /api/health
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/api/health || exit 1

# Comando de inicialização
CMD ["node", "dist/server.js"]