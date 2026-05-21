# Stage 1: Build Flutter web app
FROM ghcr.io/cirruslabs/flutter:3.24.5 AS builder

WORKDIR /app

COPY frontend_flutter/pubspec.yaml frontend_flutter/pubspec.lock ./
RUN flutter pub get

COPY frontend_flutter/ .

RUN dart run sqflite_common_ffi_web:setup
RUN flutter build web --release

RUN cp web/sqflite_sw.js build/web/
RUN cp web/sqlite3.wasm build/web/

# Stage 2: Serve with Nginx
FROM nginx:alpine

RUN rm -rf /usr/share/nginx/html/*

COPY --from=builder /app/build/web /usr/share/nginx/html

COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
