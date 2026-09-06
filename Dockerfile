# Stage 1: Build the application using Maven
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app
COPY . .
RUN mvn clean package -DskipTests

# Stage 2: Deploy to Apache Tomcat 10 with Java 17
FROM tomcat:10.0-jdk17-openjdk

# Remove default Tomcat welcome pages
RUN rm -rf /usr/local/tomcat/webapps/*

# Copy the generated WAR file from the build stage and rename it to ROOT.war
COPY --from=build /app/target/*.war /usr/local/tomcat/webapps/ROOT.war

# Expose port 8080 for Render
EXPOSE 8080

# Start Tomcat
CMD ["catalina.sh", "run"]