# Base stage: dev and prod's common setup
FROM node:22-slim AS base
WORKDIR /app
COPY backend/package.json backend/package-lock.json ./
ENV PORT=3000
EXPOSE 3000

# Development stage: every dependency (includes nodemon for hot reloading)
FROM base AS dev
RUN npm ci
COPY backend/ ./
CMD ["npm", "run", "dev"]

# Frontend stage: builds frontend into static files and copies them into frontend folder in container
FROM node:22-slim AS frontend
WORKDIR /frontend
COPY frontend/package.json frontend/package-lock.json ./
RUN npm ci
COPY frontend/ ./
# Set API URL to blank before building
ENV VITE_API_URL=""
RUN npm run build

# Production stage: only dependencies needed to run the app (no dev dependencies)
FROM base AS production
ENV NODE_ENV=production
RUN npm ci --omit=dev
COPY backend/ ./
COPY --from=frontend /frontend/dist ./dist
# Make folder for file uploads and s3 bucket is not set. Owned by the node user.
RUN mkdir -p uploads && chown node:node uploads
USER node
CMD ["node", "src/server.js"]