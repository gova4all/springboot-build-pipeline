FROM amazoncorretto:8-alpine
WORKDIR /opt/app
COPY target/*.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar"]