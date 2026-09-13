# ============================================================
# STAGE 1 — BUILD
# ============================================================

FROM node:22-bookworm-slim AS builder

WORKDIR /app

ENV NODE_ENV=development

# Atualiza o npm para uma versão com correções de segurança
RUN npm install --global npm@11.19.1 \
    && npm --version

# Copia os manifests primeiro para aproveitar o cache do Docker
COPY package.json package-lock.json ./

# Instala todas as dependências necessárias para o build
RUN npm ci

# Copia os arquivos necessários para a compilação
COPY tsconfig.json ./
COPY src ./src

# Compila o TypeScript
RUN npm run build


# ============================================================
# STAGE 2 — PRODUCTION DEPENDENCIES
# ============================================================

FROM node:22-bookworm-slim AS production-deps

WORKDIR /app

ENV NODE_ENV=production

# Atualiza o npm para uma versão com correções de segurança
RUN npm install --global npm@11.19.1 \
    && npm --version

# Copia os manifests
COPY package.json package-lock.json ./

# Instala somente as dependências de produção
RUN npm ci --omit=dev \
    && npm cache clean --force


# ============================================================
# STAGE 3 — RUNTIME
# ============================================================

FROM node:22-bookworm-slim AS runtime

ENV NODE_ENV=production \
    PORT=3000

WORKDIR /app

# Atualiza os pacotes do Debian para receber correções de segurança
RUN apt-get update \
    && apt-get upgrade -y \
    && rm -rf /var/lib/apt/lists/*

# Cria usuário sem privilégios
RUN groupadd --system appgroup \
    && useradd --system \
       --gid appgroup \
       --create-home \
       appuser

# Remove npm e npx do runtime.
# A aplicação executa somente o Node.js.
RUN rm -rf /usr/local/lib/node_modules/npm \
    && rm -f /usr/local/bin/npm \
              /usr/local/bin/npx

# Copia somente as dependências de produção
COPY --from=production-deps \
     --chown=appuser:appgroup \
     /app/node_modules \
     ./node_modules

# Copia somente o código compilado
COPY --from=builder \
     --chown=appuser:appgroup \
     /app/dist \
     ./dist

# Executa a aplicação como usuário não-root
USER appuser

EXPOSE 3000

# Healthcheck sem necessidade de curl ou wget
HEALTHCHECK --interval=30s \
            --timeout=5s \
            --start-period=20s \
            --retries=3 \
    CMD node -e "\
        require('http').get(\
          'http://127.0.0.1:3000/api/health',\
          res => process.exit(res.statusCode === 200 ? 0 : 1)\
        ).on('error', () => process.exit(1))"

CMD ["node", "dist/server.js"]
