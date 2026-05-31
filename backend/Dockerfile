# 多阶段构建：先用 JDK 构建，再用 JRE 运行
FROM eclipse-temurin:21-jdk AS build
WORKDIR /app
# 国内构建加速：阿里云 Maven 镜像（init script 经 ~/.gradle/init.d 自动加载，不改 build.gradle.kts）
COPY docker/gradle-init.gradle /root/.gradle/init.d/gradle-init.gradle
COPY gradlew settings.gradle.kts build.gradle.kts gradle.properties ./
COPY gradle ./gradle
# 预热依赖缓存
RUN ./gradlew --no-daemon dependencies > /dev/null 2>&1 || true
COPY src ./src
RUN ./gradlew --no-daemon clean bootJar

FROM eclipse-temurin:21-jre AS runtime
WORKDIR /app
RUN useradd -r -u 1001 appuser
COPY --from=build /app/build/libs/*.jar app.jar
USER appuser
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
