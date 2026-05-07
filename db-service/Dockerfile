FROM node:20-alpine

# Dépendances système pour better-sqlite3
RUN apk add --no-cache python3 make g++

WORKDIR /app

COPY package*.json ./
RUN npm install --omit=dev

COPY src/ ./src/
COPY scripts/ ./scripts/
COPY seed.js ./

# Répertoire pour la base SQLite (monté en volume)
RUN mkdir -p /data

ENV DB_PATH=/data/hospital.db
ENV NODE_ENV=production

EXPOSE 3002

CMD ["node", "src/index.js"]
