# Stage 1: Build Flutter Web
FROM --platform=$BUILDPLATFORM ubuntu:latest AS web-builder

RUN apt-get update && apt-get install -y curl git unzip

WORKDIR /flutter
RUN git clone https://github.com/flutter/flutter.git -b stable
ENV PATH="/flutter/flutter/bin:/flutter/flutter/bin/cache/dart-sdk/bin:${PATH}"

WORKDIR /app
COPY . .
RUN flutter create . --platforms web
RUN flutter build web --release

# Stage 2: Build Dart Backend
FROM dart:stable AS server-builder

WORKDIR /app
COPY server/pubspec.yaml .
RUN dart pub get

COPY server/ .
RUN dart compile exe bin/server.dart -o server

# Stage 3: Final Runtime
FROM dart:stable

WORKDIR /app

# Copy Web Build
COPY --from=web-builder /app/build/web /app/static

# Copy Backend Server
COPY --from=server-builder /app/server /app/server

# Environment
ENV STATIC_PATH=/app/static
ENV DOWNLOAD_PATH=/app/data
ENV PORT=8080

EXPOSE 8080

# Create volume dir
RUN mkdir -p /app/data

CMD ["/app/server"]
