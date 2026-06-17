# Multi-stage Dockerfile for Android Application
# Stage 1: Build the Android application
FROM gradle:8.7-jdk17 AS builder

# Set working directory
WORKDIR /app

# Set environment variables for Android SDK
ENV ANDROID_HOME=/opt/android-sdk
ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV PATH=${PATH}:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools

# Install Android SDK dependencies
USER root
RUN apt-get update && apt-get install -y \
    wget \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Download and install Android SDK Command Line Tools
RUN mkdir -p ${ANDROID_HOME}/cmdline-tools && \
    wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O /tmp/cmdline-tools.zip && \
    unzip -q /tmp/cmdline-tools.zip -d ${ANDROID_HOME}/cmdline-tools && \
    mv ${ANDROID_HOME}/cmdline-tools/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest && \
    rm /tmp/cmdline-tools.zip

# Accept Android SDK licenses
RUN yes | ${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager --licenses || true

# Install required Android SDK components
RUN ${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager \
    "platform-tools" \
    "platforms;android-36" \
    "build-tools;34.0.0" \
    "extras;google;m2repository" \
    "extras;android;m2repository"

# Copy gradle wrapper and properties first for better caching
COPY gradle gradle
COPY gradlew gradlew.bat gradle.properties settings.gradle.kts ./
RUN chmod +x gradlew

# Download dependencies (cached layer)
COPY build.gradle.kts ./
RUN ./gradlew dependencies --no-daemon || true

# Copy application source code
COPY app ./app

# Build the application
# Use assembleRelease for production builds
RUN ./gradlew assembleRelease --no-daemon --stacktrace

# Verify build output
RUN ls -la app/build/outputs/apk/release/

# Stage 2: Create minimal runtime image
FROM alpine:3.19

# Install runtime dependencies
RUN apk add --no-cache \
    openjdk17-jre-headless \
    bash \
    curl

# Create non-root user
RUN addgroup -g 1001 appuser && \
    adduser -D -u 1001 -G appuser appuser

# Set working directory
WORKDIR /app

# Copy built APK from builder stage
COPY --from=builder /app/app/build/outputs/apk/release/*.apk ./app-release.apk

# Copy gradle wrapper for verification tasks
COPY --from=builder /app/gradlew ./
COPY --from=builder /app/gradle ./gradle

# Set ownership


# Switch to non-root user
USER appuser

# Add labels for metadata
LABEL maintainer="DevOps Team"
LABEL version="1.0"
LABEL description="Android Application - Deployment Ready"
LABEL app.name="SampleAppForDevopsPersonaTesting"

# Health check - verify APK exists
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD test -f /app/app-release.apk || exit 1

# Default command - can be overridden
CMD ["sh", "-c", "echo 'Android APK built successfully' && ls -lh /app/app-release.apk && echo 'Deployment Persona Test Successful'"]
