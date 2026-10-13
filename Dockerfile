FROM node:22-slim

WORKDIR /app
COPY backend/package.json backend/package-lock.json ./
RUN npm ci
COPY backend/ ./

ENV PORT=3000
EXPOSE 3000
CMD ["npm", "run", "dev"]
