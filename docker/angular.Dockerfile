# syntax=docker/dockerfile:1
# Shared multi-stage build for the Angular apps. Pick the app with --build-arg APP=admin|client.
# Context is the repo root (see docker-compose.yml).

FROM node:22-alpine AS build
ARG APP
WORKDIR /workspace
# Install deps first for caching. --ignore-scripts skips the husky "prepare" hook,
# which has no git repo (and isn't needed) inside the image.
COPY package.json package-lock.json ./
RUN npm ci --ignore-scripts
COPY . .
RUN npx nx build "${APP}" --configuration=production
# Normalize the output path so the runtime stage doesn't need the app name.
RUN cp -r "dist/apps/${APP}/browser" /www

FROM nginx:1.27-alpine AS runtime
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /www /usr/share/nginx/html
EXPOSE 80
