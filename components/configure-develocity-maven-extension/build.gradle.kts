plugins {
    id("java")
    id("com.gradleup.shadow") version "9.3.0"
}

repositories {
    mavenCentral()
}

dependencies {
    compileOnly("org.apache.maven:maven-core:3.6.3") {
        because("compatibility with older versions of Maven is required")
    }
    compileOnly("com.gradle:gradle-enterprise-maven-extension:1.20.1") {
        because("compatibility with older versions of the Gradle Enterprise Maven extension is required")
    }
    compileOnly("com.gradle:develocity-maven-extension:2.3")
    implementation("com.gradle:develocity-maven-extension-adapters:1.0")
}

description = "Maven extension to capture the build scan URL"

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(8))
        vendor.set(JvmVendorSpec.AZUL)
    }
}

tasks.withType(JavaCompile::class).configureEach {
    options.encoding = "UTF-8"
}
