# 1. Build Stage
FROM node:22-alpine AS builder

RUN corepack enable && corepack prepare pnpm@10.7.1 --activate

WORKDIR /frontend

ARG NEXT_PUBLIC_KAKAO_APP_KEY
ARG NEXT_PUBLIC_API_URL
ARG NEXT_PUBLIC_SHOW_UNRELEASED
ARG NEXT_PUBLIC_COMPETITION_START_HOUR
ARG NEXT_PUBLIC_COMPETITION_START_MINUTE
ARG NEXT_PUBLIC_COMPETITION_DURATION_MS
ARG NEXT_PUBLIC_COMPETITION_AGGREGATE_MS

RUN echo "NEXT_PUBLIC_KAKAO_APP_KEY=${NEXT_PUBLIC_KAKAO_APP_KEY}" >> .env && \
    echo "NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL}" >> .env && \
    echo "NEXT_PUBLIC_SHOW_UNRELEASED=${NEXT_PUBLIC_SHOW_UNRELEASED}" >> .env && \
    echo "NEXT_PUBLIC_COMPETITION_START_HOUR=${NEXT_PUBLIC_COMPETITION_START_HOUR}" >> .env && \
    echo "NEXT_PUBLIC_COMPETITION_START_MINUTE=${NEXT_PUBLIC_COMPETITION_START_MINUTE}" >> .env && \
    echo "NEXT_PUBLIC_COMPETITION_DURATION_MS=${NEXT_PUBLIC_COMPETITION_DURATION_MS}" >> .env && \
    echo "NEXT_PUBLIC_COMPETITION_AGGREGATE_MS=${NEXT_PUBLIC_COMPETITION_AGGREGATE_MS}" >> .env
    
COPY package.json pnpm-lock.yaml ./
RUN pnpm install

COPY . .

RUN pnpm build

RUN corepack enable && corepack prepare pnpm@10.7.1 --activate

# 2. Runner Stage
FROM node:22-alpine AS runner

WORKDIR /frontend

COPY --from=builder /frontend/.next ./.next
COPY --from=builder /frontend/public ./public
COPY --from=builder /frontend/package.json ./
COPY --from=builder /frontend/node_modules ./node_modules

EXPOSE 5173

CMD ["pnpm", "start"]