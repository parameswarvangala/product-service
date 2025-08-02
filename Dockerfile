# -------- Stage 1: Build Java Application --------
FROM eclipse-temurin:21-jdk-alpine AS builder

WORKDIR /app

# Install Maven
RUN apk add --no-cache maven

# Copy project files
COPY pom.xml .
RUN mvn dependency:resolve-plugins dependency:resolve -B
COPY src ./src

# Package the application (skip tests for speed)
RUN mvn clean package -DskipTests

# -------- Stage 2: Production Runtime --------
FROM eclipse-temurin:21-jdk-alpine

# Create a non-root user for better security
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Set working directory
WORKDIR /app

# JVM optimizations for container environments
ENV JAVA_OPTS="\
  -XX:+UseContainerSupport \
  -XX:MaxRAMPercentage=75.0 \
  -XX:+AlwaysPreTouch \
  -XX:+UseG1GC \
  -XX:+ExitOnOutOfMemoryError \
  -XX:+UseStringDeduplication \
  -XX:+HeapDumpOnOutOfMemoryError \
  -XX:HeapDumpPath=/tmp/heapdump.hprof \
  -Xlog:gc*:file=/tmp/gc.log:time \
  -Dfile.encoding=UTF-8"


# Copy only the built JAR from the builder stage
COPY --from=builder /app/target/*.jar app.jar

# Set ownership and permissions
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Optional: Expose app port (for documentation and Docker Compose)
EXPOSE 8081

# Start the application with container-friendly JVM options
ENTRYPOINT exec java $JAVA_OPTS -jar app.jar
