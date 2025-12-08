FROM eclipse-temurin:8-jdk-alpine
WORKDIR /opt/app
COPY target/*.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar"]