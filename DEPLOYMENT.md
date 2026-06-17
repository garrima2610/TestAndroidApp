# Deployment Guide - Sample Android App

This guide provides comprehensive instructions for deploying the Android application using Docker and IBM Code Engine.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Configuration](#configuration)
- [Local Development](#local-development)
- [Building the Docker Image](#building-the-docker-image)
- [Deploying to IBM Code Engine](#deploying-to-ibm-code-engine)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Tools
- **Docker**: Version 20.10 or higher
- **IBM Cloud CLI**: Latest version
- **Code Engine Plugin**: `ibmcloud plugin install code-engine`
- **Git**: For version control
- **Java JDK**: 17 (for local development)

### IBM Cloud Setup
1. Create an IBM Cloud account at https://cloud.ibm.com
2. Create a Code Engine project
3. Set up a container registry (IBM Container Registry or Docker Hub)

## Configuration

### 1. Environment Variables

Copy the example environment file:
```bash
cp .env.example .env
```

Edit `.env` with your configuration:
```bash
GRADLE_OPTS=-Dorg.gradle.daemon=false
JAVA_OPTS=
```

### 2. Update Code Engine Configuration

Edit `code-engine.yaml` and replace the placeholders:
- `<REGISTRY_URL>`: Your container registry URL (e.g., `us.icr.io`)
- `<NAMESPACE>`: Your registry namespace (e.g., `my-namespace`)

Example:
```yaml
image: us.icr.io/my-namespace/sample-android-app:latest
```

## Local Development

### Running Validation Script

Execute the deployment validation script:
```bash
chmod +x deploy-test.sh
./deploy-test.sh
```

This script validates:
- Required files presence
- Gradle setup
- Docker configuration
- Code Engine YAML syntax
- Environment configuration

### Building Locally with Gradle

```bash
./gradlew assembleRelease
```

The APK will be generated at:
```
app/build/outputs/apk/release/app-release.apk
```

## Building the Docker Image

### 1. Build the Image

```bash
docker build -t sample-android-app:latest .
```

### 2. Test the Image Locally

```bash
docker run --rm sample-android-app:latest
```

Expected output:
```
Android APK built successfully
-rw-r--r-- 1 appuser appuser 5.2M app-release.apk
Deployment Persona Test Successful
```

### 3. Tag for Registry

For IBM Container Registry:
```bash
docker tag sample-android-app:latest us.icr.io/<namespace>/sample-android-app:latest
```

For Docker Hub:
```bash
docker tag sample-android-app:latest <dockerhub-username>/sample-android-app:latest
```

### 4. Push to Registry

For IBM Container Registry:
```bash
# Login to IBM Cloud
ibmcloud login

# Login to Container Registry
ibmcloud cr login

# Push image
docker push us.icr.io/<namespace>/sample-android-app:latest
```

For Docker Hub:
```bash
docker login
docker push <dockerhub-username>/sample-android-app:latest
```

## Deploying to IBM Code Engine

### 1. Login to IBM Cloud

```bash
ibmcloud login
ibmcloud target -r <region> -g <resource-group>
```

### 2. Select Code Engine Project

```bash
ibmcloud ce project select --name <project-name>
```

### 3. Create the Job (First Time Only)

```bash
ibmcloud ce job create \
  --name android-gradle-build-job \
  --image us.icr.io/<namespace>/sample-android-app:latest \
  --cpu 1 \
  --memory 4G \
  --maxexecutiontime 1800 \
  --retrylimit 3
```

### 4. Submit a Job Run

```bash
ibmcloud ce jobrun submit \
  --name android-build-run-$(date +%s) \
  --job android-gradle-build-job
```

### 5. Monitor Job Execution

```bash
# List job runs
ibmcloud ce jobrun list

# Get job run details
ibmcloud ce jobrun get --name <jobrun-name>

# View logs
ibmcloud ce jobrun logs --name <jobrun-name>
```

### 6. Using YAML Configuration

Alternatively, apply the configuration directly:
```bash
kubectl apply -f code-engine.yaml
```

## Docker Image Details

### Multi-Stage Build

The Dockerfile uses a two-stage build process:

**Stage 1: Builder**
- Base: `gradle:8.7-jdk17`
- Installs Android SDK
- Builds the release APK
- Size: ~3-4 GB


- Base: `alpine:3.19`
- Contains only the built APK
- Size: ~50-100 MB
- Runs as non-root user for security

### Image Features

- ✅ Multi-stage build for minimal size
- ✅ Non-root user execution
- ✅ Health checks included
- ✅ Optimized layer caching
- ✅ Automatic SDK license acceptance
- ✅ Production-ready configuration

## Troubleshooting

### Build Failures

**Issue**: Gradle build fails
```bash
# Check Gradle version
./gradlew --version

# Clean build
./gradlew clean

# Build with stacktrace
./gradlew assembleRelease --stacktrace
```

**Issue**: Docker build fails
```bash
# Build with no cache
docker build --no-cache -t sample-android-app:latest .

# Check Docker logs
docker logs <container-id>
```

### Memory Issues

If builds fail due to memory:

1. Increase Docker memory allocation (Docker Desktop settings)
2. Update Code Engine job memory:
```bash
ibmcloud ce job update android-gradle-build-job --memory 8G
```

### Registry Authentication

**IBM Container Registry**:
```bash
# Create API key
ibmcloud iam api-key-create my-api-key

# Login with API key
docker login -u iamapikey -p <api-key> us.icr.io
```

**Docker Hub**:
```bash
docker login -u <username>
```

### Code Engine Issues

**Check job status**:
```bash
ibmcloud ce jobrun get --name <jobrun-name>
```

**View detailed logs**:
```bash
ibmcloud ce jobrun logs --name <jobrun-name> --follow
```

**Delete failed job run**:
```bash
ibmcloud ce jobrun delete --name <jobrun-name>
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Build and Deploy

on:
  push:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Build Docker image
        run: docker build -t sample-android-app:latest .
      
      - name: Push to registry
        run: |
          echo "${{ secrets.REGISTRY_PASSWORD }}" | docker login -u "${{ secrets.REGISTRY_USERNAME }}" --password-stdin
          docker push sample-android-app:latest
      
      - name: Deploy to Code Engine
        run: |
          ibmcloud login --apikey ${{ secrets.IBM_CLOUD_API_KEY }}
          ibmcloud ce jobrun submit --name android-build-$(date +%s) --job android-gradle-build-job
```

## Best Practices

1. **Version Tagging**: Always tag images with version numbers
   ```bash
   docker tag sample-android-app:latest sample-android-app:v1.0.0
   ```

2. **Security Scanning**: Scan images for vulnerabilities
   ```bash
   docker scan sample-android-app:latest
   ```

3. **Resource Limits**: Set appropriate CPU and memory limits

4. **Monitoring**: Set up logging and monitoring for production deployments

5. **Secrets Management**: Use IBM Cloud Secrets Manager for sensitive data

## Additional Resources

- [IBM Code Engine Documentation](https://cloud.ibm.com/docs/codeengine)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Android Build Documentation](https://developer.android.com/studio/build)
- [Gradle Documentation](https://docs.gradle.org/)

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review IBM Code Engine logs
3. Contact your DevOps team
4. Open an issue in the project repository
