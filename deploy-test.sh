#!/bin/bash

echo "====================================="
echo "Deployment Persona Test Started"
echo "====================================="

echo "Checking Dockerfile..."

if [ -f Dockerfile ]; then
    echo "SUCCESS : Dockerfile found"
else
    echo "ERROR : Dockerfile missing"
    exit 1
fi

echo "Checking Gradle Wrapper..."

if [ -f gradlew ]; then
    echo "SUCCESS : gradlew found"
else
    echo "ERROR : gradlew missing"
    exit 1
fi

echo "Running Gradle Validation..."

chmod +x gradlew
./gradlew tasks

echo "Deployment Persona Validation Completed"