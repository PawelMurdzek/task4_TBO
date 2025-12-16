# ---- Build Stage ----
# Use Maven base image from the Docker Hub
FROM maven:3.8.8-eclipse-temurin-11 AS build

# Set the current working directory inside the image
WORKDIR /app

# Copy the source code to the container
COPY src /app/src
COPY pom.xml /app

# Package the application
RUN mvn clean install -DskipTests

# ---- Deploy Stage ----
FROM eclipse-temurin:11-jdk

# Copy the built JAR from the build stage
COPY --from=build /app/target/thymeleaf-0.0.1-SNAPSHOT.jar /app.jar

# Run the application
ENTRYPOINT ["java", "-jar", "/app.jar"]