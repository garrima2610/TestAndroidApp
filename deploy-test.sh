#!/bin/bash

set -e  # Exit on any error

echo "====================================="
echo "Deployment Persona Test Started"
echo "====================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print success messages
print_success() {
    echo -e "${GREEN}✓ SUCCESS${NC}: $1"
}

# Function to print error messages
print_error() {
    echo -e "${RED}✗ ERROR${NC}: $1"
}

# Function to print info messages
print_info() {
    echo -e "${YELLOW}ℹ INFO${NC}: $1"
}

# Check if running in CI/CD environment
if [ -n "$CI" ] || [ -n "$CONTINUOUS_INTEGRATION" ]; then
    print_info "Running in CI/CD environment"
    export CI_BUILD=true
fi

echo ""
echo "Step 1: Checking Required Files"
echo "-----------------------------------"

# Check Dockerfile
if [ -f Dockerfile ]; then
    print_success "Dockerfile found"
else
    print_error "Dockerfile missing"
    exit 1
fi

# Check Gradle Wrapper
if [ -f gradlew ]; then
    print_success "gradlew found"
else
    print_error "gradlew missing"
    exit 1
fi

# Check build.gradle.kts
if [ -f build.gradle.kts ]; then
    print_success "build.gradle.kts found"
else
    print_error "build.gradle.kts missing"
    exit 1
fi

# Check code-engine.yaml
if [ -f code-engine.yaml ]; then
    print_success "code-engine.yaml found"
else
    print_error "code-engine.yaml missing"
    exit 1
fi

echo ""
echo "Step 2: Validating Gradle Setup"
echo "-----------------------------------"

chmod +x gradlew

print_info "Running Gradle tasks validation..."
if ./gradlew tasks --no-daemon > /dev/null 2>&1; then
    print_success "Gradle validation passed"
else
    print_error "Gradle validation failed"
    exit 1
fi

echo ""
echo "Step 3: Docker Configuration Check"
echo "-----------------------------------"

# Check if Docker is available
if command -v docker &> /dev/null; then
    print_success "Docker is installed"
    DOCKER_VERSION=$(docker --version)
    print_info "Docker version: $DOCKER_VERSION"
    
    # Check if Docker daemon is running
    if docker info &> /dev/null; then
        print_success "Docker daemon is running"
        
        # Validate Dockerfile syntax (optional, can be slow)
        if [ "${SKIP_DOCKER_BUILD:-true}" = "false" ]; then
            print_info "Validating Dockerfile syntax..."
            if docker build --no-cache -t android-app-test -f Dockerfile . > /dev/null 2>&1; then
                print_success "Dockerfile syntax is valid"
                # Clean up test image
                docker rmi android-app-test > /dev/null 2>&1 || true
            else
                print_error "Dockerfile has syntax errors"
                exit 1
            fi
        else
            print_info "Docker build validation skipped (set SKIP_DOCKER_BUILD=false to enable)"
        fi
    else
        print_error "Docker daemon is not running. Please start Docker Desktop or Docker service."

        if [ "${REQUIRE_DOCKER:-false}" = "true" ]; then
            exit 1
        fi
    fi
else
    print_error "Docker is not installed or not in PATH"
    print_info "Docker is required for building and deploying the application."
    print_info "Install Docker from: https://docs.docker.com/get-docker/"
    print_info ""
    print_info "If you want to continue validation without Docker, this is acceptable for initial setup."
    print_info "Set REQUIRE_DOCKER=true to make Docker mandatory."
    
    if [ "${REQUIRE_DOCKER:-false}" = "true" ]; then
        exit 1
    fi
fi

echo ""
echo "Step 4: Code Engine Configuration Check"
echo "-----------------------------------"

# Validate YAML syntax
if command -v yamllint &> /dev/null; then
    if yamllint code-engine.yaml > /dev/null 2>&1; then
        print_success "code-engine.yaml syntax is valid"
    else
        print_error "code-engine.yaml has syntax errors"
        exit 1
    fi
else
    print_info "yamllint not installed, skipping YAML validation"
fi

# Check for required placeholders in code-engine.yaml
if grep -q "<REGISTRY_URL>" code-engine.yaml && grep -q "<NAMESPACE>" code-engine.yaml; then
    print_info "Remember to replace <REGISTRY_URL> and <NAMESPACE> in code-engine.yaml before deployment"
fi

echo ""
echo "Step 5: Environment Configuration"
echo "-----------------------------------"

# Check for .env.example
if [ -f .env.example ]; then
    print_success ".env.example found"
    print_info "Copy .env.example to .env and configure for your environment"
fi

# Check .dockerignore
if [ -f .dockerignore ]; then
    print_success ".dockerignore found"
else
    print_error ".dockerignore missing"
    exit 1
fi

echo ""
echo "Step 6: Build Verification (Optional)"
echo "-----------------------------------"

if [ "${SKIP_BUILD:-false}" = "false" ]; then
    print_info "To perform a full build test, run: docker build -t sample-android-app ."
    print_info "To skip this in future runs, set SKIP_BUILD=true"
else
    print_info "Build verification skipped (SKIP_BUILD=true)"
fi

echo ""
echo "====================================="
echo "Deployment Persona Validation Completed Successfully!"
echo "====================================="
echo ""
print_info "Next Steps:"
echo "  1. Update code-engine.yaml with your registry URL and namespace"
echo "  2. Build the Docker image: docker build -t <your-registry>/sample-android-app:latest ."
echo "  3. Push to registry: docker push <your-registry>/sample-android-app:latest"
echo "  4. Deploy to IBM Code Engine: ibmcloud ce jobrun submit --name android-build --job android-gradle-build-job"
echo ""
