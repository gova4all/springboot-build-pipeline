FROM eclipse-temurin:17-jre-alpine
WORKDIR /opt/app
COPY target/*.jar app.jar
USER 1001
ENTRYPOINT ["java", "-jar", "app.jar"]