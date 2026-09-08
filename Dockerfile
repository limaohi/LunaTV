# syntax=docker/dockerfile:1

# ---- 第 1 阶段：安装依赖 ----
FROM node:20-alpine AS deps

WORKDIR /app

RUN corepack enable \
    && corepack prepare pnpm@latest --activate

COPY package.json pnpm-lock.yaml ./

RUN pnpm install --frozen-lockfile


# ---- 第 2 阶段：构建并生成 manifest.json ----
FROM node:20-alpine AS builder

WORKDIR /app

RUN corepack enable \
    && corepack prepare pnpm@latest --activate

COPY --from=deps /app/node_modules ./node_modules
COPY . .

ENV DOCKER_ENV=true

# output: 'standalone' 会在这里生成 .next/standalone/server.js。
# manifest 在构建期写入 public，运行期无需再写文件。
RUN pnpm run build \
    && node scripts/generate-manifest.js


# ---- 第 3 阶段：只读友好的运行镜像 ----
FROM node:20-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production
ENV HOSTNAME=0.0.0.0
ENV PORT=3000
ENV DOCKER_ENV=true

RUN addgroup -g 1001 -S nodejs \
    && adduser -u 1001 -S nextjs -G nodejs

# standalone 中包含 server.js、Next 运行时和追踪到的依赖
COPY --from=builder --chown=1001:1001 /app/.next/standalone ./

# standalone 默认不携带这些静态资源；复制进 standalone 运行目录。
COPY --from=builder --chown=1001:1001 /app/public ./public
COPY --from=builder --chown=1001:1001 /app/.next/static ./.next/static

USER 1001:1001

EXPOSE 3000

# 不调用原项目的 start.js，
# 因此容器启动时不会执行 generate-manifest.js。
CMD ["node", "server.js"]
