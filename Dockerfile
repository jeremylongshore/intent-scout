FROM node:22-slim AS builder

WORKDIR /app
COPY package.json pnpm-lock.yaml ./
# Pin pnpm to v9 to match CI (pnpm/action-setup@v4 with version: 9).
# pnpm v10 stopped reading the `pnpm.onlyBuiltDependencies` field from
# package.json and treats un-approved native build scripts (better-sqlite3,
# esbuild) as a hard error under --frozen-lockfile, which broke this build.
RUN npm i -g pnpm@9 && pnpm install --frozen-lockfile
COPY . .
RUN pnpm build

FROM node:22-slim AS runtime

RUN apt-get update && apt-get install -y --no-install-recommends curl git && rm -rf /var/lib/apt/lists/*

RUN groupadd -f -g 1000 scout && useradd -u 1000 -g 1000 -m -d /home/scout -o scout

WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./

RUN chown -R 1000:1000 /home/scout

USER scout

HEALTHCHECK --interval=5m --timeout=30s \
  CMD curl -sf http://localhost:3000/health || exit 1

CMD ["node", "dist/index.js", "--run"]
