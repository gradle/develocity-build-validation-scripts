plugins {
    java
    application
    `maven-publish`
    id("com.github.johnrengelman.shadow") version "7.1.2"
}

repositories {
    mavenCentral()
}

dependencies {
    implementation(platform("com.squareup.okhttp3:okhttp-bom:4.9.3"))
    implementation("com.squareup.okhttp3:okhttp")
    implementation("com.squareup.okhttp3:okhttp-sse")

    implementation(platform("com.fasterxml.jackson:jackson-bom:2.13.1"))
    implementation("com.fasterxml.jackson.core:jackson-databind")

    implementation("com.google.guava:guava:31.0.1-jre")
    implementation("info.picocli:picocli:4.6.1")
    annotationProcessor("info.picocli:picocli-codegen:4.6.2")
}

group = "com.gradle"
version = "1.0.0-SNAPSHOT"
description = "Application to fetch build scan data using the Gradle Enterprise Export API"

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(8))
    }
}

tasks.compileJava {
    options.compilerArgs.add("-Aproject=${project.group}/${project.name}")
}

application {
    mainClass.set("com.gradle.enterprise.Main")
}

publishing {
    publications {
        create<MavenPublication>("maven") {
            project.shadow.component(this)
        }
    }
}
