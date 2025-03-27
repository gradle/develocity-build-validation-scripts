plugins {
    id("com.gradle.develocity") version "3.19.2"
    id("com.gradle.common-custom-user-data-gradle-plugin") version "2.2"
    id("org.gradle.toolchains.foojay-resolver-convention") version "0.9.0"
}

val isCI = System.getenv("GITHUB_ACTIONS") != null

develocity {
    server = "https://ge.solutions-team.gradle.com"
    buildScan {
        uploadInBackground = !isCI
        publishing.onlyIf { it.isAuthenticated }
        obfuscation.ipAddresses { addresses -> addresses.map { "0.0.0.0" } }
    }
}

buildCache {
    remote(develocity.buildCache) {
        isEnabled = true
        // Check access key presence to avoid build cache errors on PR builds when access key is not present
        val accessKey = System.getenv("DEVELOCITY_ACCESS_KEY")
        isPush = isCI && !accessKey.isNullOrEmpty()
    }
}

rootProject.name = "build-validation-scripts"

include("components/configure-develocity-maven-extension")

project(":components/configure-develocity-maven-extension").name = "configure-develocity-maven-extension"

val develocityCiInjectionProjectDir = providers.gradleProperty("develocityCiInjectionProjectDir")
if (develocityCiInjectionProjectDir.isPresent) {
    includeBuild(develocityCiInjectionProjectDir) {
        dependencySubstitution {
            substitute(module("com.gradle:develocity-injection")).using(project(":"))
        }
    }
}
