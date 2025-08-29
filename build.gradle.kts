@file:Suppress("HasPlatformType")

import com.felipefzdz.gradle.shellcheck.Shellcheck
import org.gradle.crypto.checksum.Checksum

plugins {
    id("base")
    id("com.felipefzdz.gradle.shellcheck") version "1.5.0"
    id("com.github.breadmoirai.github-release") version "2.5.2"
    id("org.gradle.crypto.checksum") version "1.4.0"
}

group = "com.gradle"

repositories {
    exclusiveContent {
        forRepository {
            ivy {
                url = uri("https://github.com/matejak/")
                patternLayout {
                    artifact("[module]/archive/refs/tags/[revision].[ext]")
                }
                metadataSources {
                    artifact()
                }
            }
        }
        filter {
            includeModule("argbash", "argbash")
        }
    }
    exclusiveContent {
        forRepository {
            ivy {
                url = uri("https://raw.githubusercontent.com/gradle/develocity-ci-injection/")
                patternLayout {
                    artifact("refs/tags/v[revision]/reference/develocity-injection.init.gradle")
                }
                metadataSources {
                    artifact()
                }
            }
        }
        filter {
            includeModule("com.gradle", "develocity-injection")
        }
    }
    exclusiveContent {
        forRepository {
            maven("https://repo.gradle.org/artifactory/solutions")
        }
        filter {
            includeModule("com.gradle", "build-scan-summary")
        }
    }
    mavenCentral()
}

val isDevelopmentRelease = !hasProperty("finalRelease")
val releaseVersion = releaseVersion()
val releaseNotes = releaseNotes()
val buildScanSummaryVersion = "1.0.5-2024.1"

allprojects {
    version = releaseVersion.get()
}

val argbash by configurations.creating
val develocityInjection = configurations.dependencyScope("develocityInjection") {
    attributes.attribute(Category.CATEGORY_ATTRIBUTE, objects.named("develocity-injection-script"))
}.get()
val develocityInjectionResolvable = configurations.resolvable("${develocityInjection.name}Resolvable") {
    extendsFrom(develocityInjection)
    attributes.attribute(Category.CATEGORY_ATTRIBUTE, objects.named("develocity-injection-script"))
}
val develocityComponents by configurations.creating {
    attributes.attribute(
        TargetJvmEnvironment.TARGET_JVM_ENVIRONMENT_ATTRIBUTE,
        objects.named(TargetJvmEnvironment.STANDARD_JVM)
    )
}
val mavenComponents by configurations.creating
val thirdPartyMavenComponents by configurations.creating
val develocityMavenComponents by configurations.creating

dependencies {
    argbash("argbash:argbash:2.10.0@zip")
    develocityInjection("com.gradle:develocity-injection:2.0")
    develocityComponents("com.gradle:build-scan-summary:$buildScanSummaryVersion")
    develocityMavenComponents("com.gradle:gradle-enterprise-maven-extension:1.18.4")
    mavenComponents(project(path = ":configure-develocity-maven-extension", configuration = "shadow"))
    thirdPartyMavenComponents("com.gradle:common-custom-user-data-maven-extension:2.0.4")
}

shellcheck {
    additionalArguments = "-a -x"
    shellcheckVersion = "v0.10.0"
}

val copyDevelocityComponents by tasks.registering(Sync::class) {
    from(develocityComponents)
    into(project.layout.buildDirectory.dir("components/develocity"))
    include("build-scan-summary-$buildScanSummaryVersion.jar")
}

val copyThirdPartyComponents by tasks.registering(Sync::class) {
    from(develocityComponents)
    into(project.layout.buildDirectory.dir("components/third-party"))
    exclude("build-scan-summary-$buildScanSummaryVersion.jar")
}

val unpackArgbash by tasks.registering(Sync::class) {
    group = "argbash"
    description = "Unpacks Argbash."
    from(zipTree(argbash.singleFile)) {
        // All files in the zip are under an "argbash-VERSION/" directory. We only want everything under this directory.
        // We can remove the top-level directory while unpacking the zip by dropping the first directory in each file's relative path.
        eachFile {
            relativePath = RelativePath(true, *relativePath.segments.drop(1).toTypedArray())
        }
        includeEmptyDirs = false
    }
    into(layout.buildDirectory.dir("argbash"))
}

val generateBashCliParsers by tasks.registering(ApplyArgbash::class) {
    group = "argbash"
    description = "Uses Argbash to generate Bash command line argument parsing code."
    argbashHome.set(layout.dir(unpackArgbash.map { it.outputs.files.singleFile }))
    scriptTemplates.set(fileTree("components/scripts") {
        include("**/*-cli-parser.m4")
        exclude("gradle/.data/")
        exclude("maven/.data/")
    })
    supportingTemplates.set(fileTree("components/scripts") {
        include("**/*.m4")
        exclude("gradle/.data/")
        exclude("maven/.data/")
    })
}

val copyGradleScripts by tasks.registering(Sync::class) {
    group = "build"
    description = "Copies the Gradle source and the generated scripts to the output directory."

    // local variable required for configuration cache compatibility
    // https://docs.gradle.org/current/userguide/configuration_cache.html#config_cache:not_yet_implemented:accessing_top_level_at_execution
    val releaseVersion = releaseVersion
    val buildScanSummaryVersion = buildScanSummaryVersion

    inputs.property("project.version", releaseVersion)
    inputs.property("summary.version", buildScanSummaryVersion)

    from(layout.projectDirectory.dir("components/licenses/gradle"))
    from(layout.projectDirectory.file("components/licenses/NOTICE"))
    from(layout.projectDirectory.dir("release").file("version.txt"))
    rename("version.txt", "VERSION")

    from(layout.projectDirectory.dir("components/scripts/gradle")) {
        exclude("gradle-init-scripts")
        filter { line: String -> line.replace("<HEAD>", releaseVersion.get()) }
        filter { line: String -> line.replace("<SUMMARY_VERSION>", buildScanSummaryVersion) }
    }
    from(layout.projectDirectory.dir("components/scripts/gradle")) {
        include("gradle-init-scripts/**")
        into("lib/scripts/")
    }
    from(develocityInjectionResolvable) {
        rename { "develocity-injection.gradle" }
        into("lib/scripts/gradle-init-scripts")
    }
    from(layout.projectDirectory.dir("components/scripts")) {
        include("README.md")
        include("mapping.example")
        include("network.settings")
        filter { line: String -> line.replace("<HEAD>", releaseVersion.get()) }
        filter { line: String -> line.replace("<SUMMARY_VERSION>", buildScanSummaryVersion) }
    }
    from(layout.projectDirectory.dir("components/scripts/lib")) {
        include("**")
        exclude("cli-parsers")
        filter { line: String -> line.replace("<HEAD>", releaseVersion.get()) }
        filter { line: String -> line.replace("<SUMMARY_VERSION>", buildScanSummaryVersion) }
        into("lib/scripts/")
    }
    from(generateBashCliParsers.map { it.outputDir.file("lib/cli-parsers/gradle") }) {
        into("lib/scripts/")
    }
    from(copyDevelocityComponents) {
        into("lib/develocity/")
    }
    from(copyThirdPartyComponents) {
        into("lib/third-party/")
    }
    into(layout.buildDirectory.dir("scripts/gradle"))
}

val copyMavenScripts by tasks.registering(Sync::class) {
    group = "build"
    description = "Copies the Maven source and the generated scripts to the output directory."

    // local variable required for configuration cache compatibility
    // https://docs.gradle.org/current/userguide/configuration_cache.html#config_cache:not_yet_implemented:accessing_top_level_at_execution
    val releaseVersion = releaseVersion
    val buildScanSummaryVersion = buildScanSummaryVersion

    inputs.property("project.version", releaseVersion)
    inputs.property("summary.version", buildScanSummaryVersion)

    from(layout.projectDirectory.dir("components/licenses/maven"))
    from(layout.projectDirectory.file("components/licenses/NOTICE"))
    from(layout.projectDirectory.dir("release").file("version.txt"))
    rename("version.txt", "VERSION")

    from(layout.projectDirectory.dir("components/scripts/maven")) {
        filter { line: String -> line.replace("<HEAD>", releaseVersion.get()) }
        filter { line: String -> line.replace("<SUMMARY_VERSION>", buildScanSummaryVersion) }
    }
    from(layout.projectDirectory.dir("components/scripts/")) {
        include("README.md")
        include("mapping.example")
        include("network.settings")
        filter { line: String -> line.replace("<HEAD>", releaseVersion.get()) }
        filter { line: String -> line.replace("<SUMMARY_VERSION>", buildScanSummaryVersion) }
    }
    from(layout.projectDirectory.dir("components/scripts/lib")) {
        include("**")
        exclude("cli-parsers")
        filter { line: String -> line.replace("<HEAD>", releaseVersion.get()) }
        filter { line: String -> line.replace("<SUMMARY_VERSION>", buildScanSummaryVersion) }
        into("lib/scripts/")
    }
    from(generateBashCliParsers.map { it.outputDir.file("lib/cli-parsers/maven") }) {
        into("lib/scripts/")
    }
    from(copyDevelocityComponents) {
        into("lib/develocity/")
    }
    from(develocityMavenComponents) {
        into("lib/develocity/")
    }
    from(copyThirdPartyComponents) {
        into("lib/third-party/")
    }
    from(thirdPartyMavenComponents) {
        into("lib/third-party/")
    }
    from(mavenComponents) {
        into("lib/scripts/maven-libs/")
    }
    into(layout.buildDirectory.dir("scripts/maven"))
}

val copyLegacyGradleScripts by tasks.registering(Sync::class) {
    group = "build"
    description = "Copies the Gradle source and the generated scripts to the output directory."
    from(copyGradleScripts) {
        exclude("lib/scripts/config.sh")
    }
    from(copyGradleScripts) {
        include("lib/scripts/config.sh")
        filter { line: String -> line.replace("LEGACY_DISTRIBUTION=\"false\"", "LEGACY_DISTRIBUTION=\"true\"") }
    }
    into(layout.buildDirectory.dir("scripts/gradle-legacy"))
}

val copyLegacyMavenScripts by tasks.registering(Sync::class) {
    group = "build"
    description = "Copies the Maven source and the generated scripts to the output directory."
    from(copyMavenScripts) {
        exclude("lib/scripts/config.sh")
    }
    from(copyMavenScripts) {
        include("lib/scripts/config.sh")
        filter { line: String -> line.replace("LEGACY_DISTRIBUTION=\"false\"", "LEGACY_DISTRIBUTION=\"true\"") }
    }
    into(layout.buildDirectory.dir("scripts/maven-legacy"))
}

val packageGradleScripts by tasks.registering(PackageScripts::class) {
    description = "Packages the Gradle experiment scripts in a zip archive."
    distributionName = "develocity-gradle-build-validation"
    distributionContents.from(copyGradleScripts)
}

val packageMavenScripts by tasks.registering(PackageScripts::class) {
    description = "Packages the Maven experiment scripts in a zip archive."
    distributionName = "develocity-maven-build-validation"
    distributionContents.from(copyMavenScripts)
}

val packageLegacyGradleScripts by tasks.registering(PackageScripts::class) {
    description = "Packages the legacy Gradle experiment scripts in a zip archive."
    distributionName = "gradle-enterprise-gradle-build-validation"
    distributionContents.from(copyLegacyGradleScripts)
}

val packageLegacyMavenScripts by tasks.registering(PackageScripts::class) {
    description = "Packages the legacy Maven experiment scripts in a zip archive."
    distributionName = "gradle-enterprise-maven-build-validation"
    distributionContents.from(copyLegacyMavenScripts)
}

tasks.withType<PackageScripts>().configureEach {
    group = "build"
    distributionVersion = distributionVersion()
}

val assembleScripts by tasks.registering {
    dependsOn(tasks.withType<PackageScripts>())
}

tasks.assemble {
    dependsOn(assembleScripts)
}

val shellcheckGradleScripts by tasks.registering(Shellcheck::class) {
    group = "verification"
    description = "Perform quality checks on Gradle build validation scripts using Shellcheck."
    sourceFiles = copyGradleScripts.get().outputs.files.asFileTree.matching {
        include("**/*.sh")
        // scripts in lib/scripts/ are checked when Shellcheck checks the top-level scripts because the top-level scripts include (source) the scripts in lib/
        exclude("lib/scripts/")
    }
    // scripts in lib/ are still inputs to this task (we want shellcheck to run if they change) even though we don't include them explicitly in sourceFiles
    inputs.files(copyGradleScripts.get().outputs.files.asFileTree.matching {
        include("lib/**/*.sh")
    }).withPropertyName("libScripts")
        .withPathSensitivity(PathSensitivity.RELATIVE)
    workingDir = layout.buildDirectory.file("scripts/gradle").get().asFile
    reports {
        html.outputLocation.set(layout.buildDirectory.file("reports/shellcheck-gradle/shellcheck.html"))
        xml.outputLocation.set(layout.buildDirectory.file("reports/shellcheck-gradle/shellcheck.xml"))
        txt.outputLocation.set(layout.buildDirectory.file("reports/shellcheck-gradle/shellcheck.txt"))
    }
}

val shellcheckMavenScripts by tasks.registering(Shellcheck::class) {
    group = "verification"
    description = "Perform quality checks on Maven build validation scripts using Shellcheck."
    sourceFiles = copyMavenScripts.get().outputs.files.asFileTree.matching {
        include("**/*.sh")
        // scripts in lib/scripts/ are checked when Shellcheck checks the top-level scripts because the top-level scripts include (source) the scripts in lib/
        exclude("lib/scripts/")
    }
    // scripts in lib/ are still inputs to this task (we want shellcheck to run if they change) even though we don't include them explicitly in sourceFiles
    inputs.files(copyMavenScripts.get().outputs.files.asFileTree.matching {
        include("lib/**/*.sh")
    }).withPropertyName("libScripts")
        .withPathSensitivity(PathSensitivity.RELATIVE)
    workingDir = layout.buildDirectory.file("scripts/maven").get().asFile
    reports {
        html.outputLocation.set(layout.buildDirectory.file("reports/shellcheck-maven/shellcheck.html"))
        xml.outputLocation.set(layout.buildDirectory.file("reports/shellcheck-maven/shellcheck.xml"))
        txt.outputLocation.set(layout.buildDirectory.file("reports/shellcheck-maven/shellcheck.txt"))
    }
}

tasks.check {
    dependsOn(shellcheckGradleScripts, shellcheckMavenScripts)
}

val generateChecksums by tasks.registering(Checksum::class) {
    group = "distribution"
    description = "Generates checksums for the distribution zip files."
    inputFiles.setFrom(packageGradleScripts, packageMavenScripts, packageLegacyGradleScripts, packageLegacyMavenScripts)
    outputDirectory.set(layout.buildDirectory.dir("distributions/checksums").get().asFile)
    checksumAlgorithm.set(Checksum.Algorithm.SHA512)
}

githubRelease {
    token((findProperty("github.access.token") ?: System.getenv("GITHUB_ACCESS_TOKEN") ?: "").toString())
    owner.set("gradle")
    repo.set("develocity-build-validation-scripts")
    targetCommitish.set("main")
    releaseName.set(gitHubReleaseName())
    tagName.set(gitReleaseTag())
    prerelease.set(isDevelopmentRelease)
    overwrite.set(isDevelopmentRelease)
    generateReleaseNotes.set(false)
    body.set(releaseNotes)
    releaseAssets(packageGradleScripts, packageMavenScripts, packageLegacyGradleScripts, packageLegacyMavenScripts, generateChecksums.map { it.outputs.files.asFileTree })
}

val createReleaseTag by tasks.registering(CreateGitTag::class) {
    // Ensure tag is created only after a successful build
    mustRunAfter("build")
    tagName.set(githubRelease.tagName.map { it.toString() })
    overwriteExisting.set(isDevelopmentRelease)
}

tasks.githubRelease {
    dependsOn(createReleaseTag)
}

fun gitHubReleaseName(): Provider<String> {
    return releaseVersion.map { if (isDevelopmentRelease) "Development release" else it }
}

fun gitReleaseTag(): Provider<String> {
    return releaseVersion.map { if (isDevelopmentRelease) "development-latest" else "v$it" }
}

fun distributionVersion(): Provider<String> {
    return releaseVersion.map { if (isDevelopmentRelease) "dev" else it }
}

fun releaseVersion(): Provider<String> {
    val versionFile = layout.projectDirectory.file("release/version.txt")
    return providers.fileContents(versionFile).asText.map { it.trim() }
}

fun releaseNotes(): Provider<String> {
    val releaseNotesFile = layout.projectDirectory.file("release/changes.md")
    return providers.fileContents(releaseNotesFile).asText.map { it.trim() }
}
