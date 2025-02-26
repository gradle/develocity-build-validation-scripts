plugins {
    id("java")
    id("com.github.johnrengelman.shadow") version "8.1.1"
}

repositories {
    mavenCentral()
}

dependencies {
    compileOnly("org.apache.maven:maven-core:3.6.3")  // intentionally compiling against an older version to preserve compatibility with older versions of Maven
    compileOnly("com.gradle:develocity-maven-extension:1.23.2")
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
