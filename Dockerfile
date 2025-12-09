FROM eclipse-temurin:8-jre
WORKDIR /opt/app
COPY target/*.jar app.jar
USER 1001
ENTRYPOINT ["java", "-jar", "app.jar"]