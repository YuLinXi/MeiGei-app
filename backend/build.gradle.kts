plugins {
    java
    id("org.springframework.boot") version "3.3.5"
    id("io.spring.dependency-management") version "1.1.6"
}

group = "com.meigei"
version = "0.0.1-SNAPSHOT"

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(21)
    }
}

repositories {
    mavenCentral()
}

val mybatisPlusVersion = "3.5.9"
val mapstructVersion = "1.6.3"
val springdocVersion = "2.6.0"
val uuidCreatorVersion = "6.0.0"

dependencies {
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("org.springframework.boot:spring-boot-starter-validation")
    implementation("org.springframework.boot:spring-boot-starter-actuator")
    implementation("org.springframework.boot:spring-boot-starter-security")

    // Apple identityToken 验签（JWKS）+ 签发自有 JWT
    implementation("com.nimbusds:nimbus-jose-jwt:9.41.2")
    // APNs 推送（.p8 token 认证）
    implementation("com.eatthepath:pushy:0.15.4")

    implementation("com.baomidou:mybatis-plus-spring-boot3-starter:$mybatisPlusVersion")
    // 3.5.6+ 把分页/JSqlParser 相关拦截器拆出为独立模块
    implementation("com.baomidou:mybatis-plus-jsqlparser:$mybatisPlusVersion")
    runtimeOnly("org.postgresql:postgresql")
    implementation("org.flywaydb:flyway-core")
    implementation("org.flywaydb:flyway-database-postgresql")

    implementation("org.springdoc:springdoc-openapi-starter-webmvc-ui:$springdocVersion")

    // 错误监控（DSN 为空时自动禁用，安全）
    implementation("io.sentry:sentry-spring-boot-starter-jakarta:7.18.1")

    // UUID v7 生成（PostgreSQL 16 无原生 uuidv7()，统一应用层生成）
    implementation("com.github.f4b6a3:uuid-creator:$uuidCreatorVersion")

    implementation("org.mapstruct:mapstruct:$mapstructVersion")
    annotationProcessor("org.mapstruct:mapstruct-processor:$mapstructVersion")

    compileOnly("org.projectlombok:lombok")
    annotationProcessor("org.projectlombok:lombok")
    // Lombok + MapStruct 协同，保证生成器先处理 Lombok
    annotationProcessor("org.projectlombok:lombok-mapstruct-binding:0.2.0")

    testImplementation("org.springframework.boot:spring-boot-starter-test")
}

tasks.withType<Test> {
    useJUnitPlatform()
}
