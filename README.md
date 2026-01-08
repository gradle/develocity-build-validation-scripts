> _This repository is maintained by the Develocity Solutions team, as one of several publicly available repositories:_
> - _[Android Cache Fix Gradle Plugin][android-cache-fix-plugin]_
> - _[Common Custom User Data Gradle Plugin][ccud-gradle-plugin]_
> - _[Common Custom User Data Maven Extension][ccud-maven-extension]_
> - _[Common Custom User Data sbt Plugin][ccud-sbt-plugin]_
> - _[Develocity Build Configuration Samples][develocity-build-config-samples]_
> - _[Develocity Build Validation Scripts][develocity-build-validation-scripts] (this repository)_
> - _[Develocity Open Source Projects][develocity-oss-projects]_
> - _[Quarkus Build Caching Extension][quarkus-build-caching-extension]_

# Develocity Build Validation Scripts

[![Verify Build](https://github.com/gradle/develocity-build-validation-scripts/actions/workflows/build-verification.yml/badge.svg?branch=main)](https://github.com/gradle/develocity-build-validation-scripts/actions/workflows/build-verification.yml)
[![Revved up by Develocity](https://img.shields.io/badge/Revved%20up%20by-Develocity-06A0CE?logo=Gradle&labelColor=02303A)](https://ge.solutions-team.gradle.com/scans)

The purpose of the build validation scripts is to assist you in validating that your Gradle and Maven builds are in an optimal state in terms of maximizing work avoidance. The build validation scripts do not actually modify your build, but they surface what can be improved in your build to avoid unnecessary work in several scenarios.

Each script represents a so-called _experiment_. Each experiment has a very specific focus of what it validates in your build. The experiments are organized in a logical sequence that should be followed diligently to achieve incremental build improvements in an efficient manner. The experiments can be run on a fully unoptimized build, and they can also be run on a build that had already been optimized in the past in order to surface potential regressions.

There are currently five experiments for Gradle and four experiments for Maven. You could also perform these experiments fully manually, but relying on the automation provided by the build validation scripts will be faster, less error-prone, and more reproducible.

## Usage

The build validation scripts are available as pre-built, executable Bash scripts. The build validation scripts are bundled and documented separately for Gradle and Maven. There are specific instructions on

* how to use the [build validation scripts for Gradle](Gradle.md)
* how to use the [build validation scripts for Maven](Maven.md)

## Build from source

You can also assemble the build validation scripts from source by running `./gradlew build` from the root folder of this repository.

Once the build has finished successfully, you can find two .zip files in the build/distributions folder: one .zip file containing the build validation scripts for Gradle and one .zip file containing the build validation scripts for Maven.

If the build fails with _You need the 'autom4te' utility_, then you will need to install 'autoconf' before you can run the build successfully. For example, on macOS with Homebrew, you can install autoconf with `brew install autoconf`.

If the build fails with _Error while executing shellcheck: docker: Cannot connect to the Docker daemon_, then you will need to install and launch Docker before you can run the build successfully.

## Learn more

Visit our website to learn more about [Develocity][develocity].

## License

The Develocity build validation scripts are open-source software released under the [Apache 2.0 License][apache-license].

[android-cache-fix-plugin]: https://github.com/gradle/android-cache-fix-gradle-plugin
[ccud-gradle-plugin]: https://github.com/gradle/common-custom-user-data-gradle-plugin
[ccud-maven-extension]: https://github.com/gradle/common-custom-user-data-maven-extension
[ccud-sbt-plugin]: https://github.com/gradle/common-custom-user-data-sbt-plugin
[develocity-build-config-samples]: https://github.com/gradle/develocity-build-config-samples
[develocity-build-validation-scripts]: https://github.com/gradle/develocity-build-validation-scripts
[develocity-oss-projects]: https://github.com/gradle/develocity-oss-projects
[quarkus-build-caching-extension]: https://github.com/gradle/quarkus-build-caching-extension
[develocity]: https://gradle.com/develocity
[apache-license]: https://www.apache.org/licenses/LICENSE-2.0.html
