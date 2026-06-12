FROM gradle:8.7-jdk17 AS builder

WORKDIR /app

COPY . .

RUN chmod +x gradlew
RUN ./gradlew tasks

CMD ["echo", "Deployment Persona Test Successful"]