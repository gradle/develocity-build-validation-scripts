# Develocity Build Validation Scripts for Gradle

The purpose of the build validation scripts is to assist you in validating that your Gradle build is in an optimal state in terms of maximizing work avoidance. The validation scripts do not actually modify your build, but they surface what can be improved in your build to avoid unnecessary work in several scenarios.

Each script represents a so-called _experiment_. Each experiment has a very specific focus of what it validates in your build. The experiments are organized in a logical sequence that should be followed diligently to achieve incremental build improvements in an efficient manner. The experiments can be run on a fully unoptimized build, and they can also be run on a build that had already been optimized in the past in order to surface potential regressions.

There are currently five experiments for Gradle. You could also perform these experiments fully manually, but relying on the automation provided by the validation scripts will be faster, less error-prone, and more reproducible.

## Requirements

You must have the following tooling in order to use the Develocity Build Validation Scripts:

- [Develocity](https://gradle.com/develocity/)
- [Bash](https://www.gnu.org/software/bash/)

For users running on Windows, you will need to [install Windows Subsystem for Linux (WSL)](https://docs.microsoft.com/en-us/windows/wsl/install).
The scripts work well on the WSL default distribution (Ubuntu).
Note how to deal with the eventuality of facing filename too long errors [here](#dealing-with-filename-too-long-errors-on-windows).

### User permissions

The Develocity Build Validation Scripts involve running builds on your local machine and in your CI environment.
The builds run on your local machine require a different set of Develocity user permissions than those run in your CI environment.

#### Develocity user permissions required on local developer machines

| User permission                 | Reason                                                                                                                                                                           |
|---------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Publish build scans             | Analyzing the experiment results relies on build scans published to Develocity.                                                                                                  |
| Read build cache data           | Reading from the remote build cache during the experiments that depend on the remote build cache.                                                                                |
| View build scans and build data | Performing a deeper analysis of the experiment results in Develocity.                                                                                                            |
| Access build data via the API   | Retrieving the published build data from Develocity to summarize the experiment results. See [Authenticating with Develocity](#authenticating-with-develocity) for more details. |

> [!IMPORTANT]
> Your Develocity user must be granted one of `View build scans and build data` or `Access build data via the API`.
> If you have neither, you will have no way to view the experiment results.

#### Develocity user permissions required on CI

| User permission                 | Reason                                                                                                                                                                           |
|---------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Publish build scans             | Analyzing the experiment results relies on build scans published to Develocity.                                                                                                  |
| Read and write build cache data | Reading from and writing to the remote build cache.                                                                                                                              |
| Access build data via the API   | Retrieving the published build data from Develocity to summarize the experiment results. See [Authenticating with Develocity](#authenticating-with-develocity) for more details. |

### Common Custom User Data Gradle plugin

To get the most out of the experiments and also when building with Develocity during daily development, it is highly recommended that you apply the [Common Custom User Data Gradle plugin](https://github.com/gradle/common-custom-user-data-gradle-plugin) to your build.
This free, open-source plugin enhances build scans with additional tags, links, and custom values that are considered during the experiments.

You can find a complete example of how to apply the Common Custom User Data Gradle plugin to your build [here](https://github.com/gradle/develocity-build-config-samples/tree/main/common-develocity-gradle-configuration-groovy/settings.gradle) for Groovy DSL and [here](https://github.com/gradle/develocity-build-config-samples/blob/main/common-develocity-gradle-configuration-kotlin/settings.gradle.kts) for Kotlin DSL.

## Compatibility

The build validation scripts are compatible with a large range of Gradle versions, as laid out in the table below. Getting the best user experience when running an experiment and when being presented with the results of an experiment requires access to the Develocity server that holds the captured build data. Fetching that build data requires a compatible version of Develocity, as laid out in the table below.

| Build Validation Scripts version | Compatible Gradle versions | Compatible Develocity versions        |
|----------------------------------|----------------------------|---------------------------------------|
| 2.0+                             | 5.0+                       | 2022.1+                               |
| 1.0 - 1.0.2                      | 5.0+                       | 2021.2+                               |

## Installation

Use the following command to download and unpack the build validation scripts for Gradle to the current directory:

```bash
curl -s -L -O https://github.com/gradle/develocity-build-validation-scripts/releases/download/v2.7.3/develocity-gradle-build-validation-2.7.3.zip && unzip -q -o develocity-gradle-build-validation-2.7.3.zip
```

## Structure

In the top-level folder, there are five different scripts that you can execute, each one representing
a specific experiment of the build validation process:

- 01-validate-incremental-building.sh
- 02-validate-local-build-caching-same-location.sh
- 03-validate-local-build-caching-different-locations.sh
- 04-validate-remote-build-caching-ci-ci.sh
- 05-validate-remote-build-caching-ci-local.sh

<details>
  <summary>Click to see more details about the experiment that each script represents.</summary>

| Script | Experiment |
| :----- | :------ |
| 01-validate-incremental-building.sh | Validates that a Gradle build is optimized for incremental building, implicitly invoked from the same location. |
| 02-validate-local-build-caching-same-location.sh | Validates that a Gradle build is optimized for local build caching when invoked from the same location. |
| 03-validate-local-build-caching-different-locations.sh | Validates that a Gradle build is optimized for local build caching when invoked from different locations. |
| 04-validate-remote-build-caching-ci-ci.sh | Validates that a Gradle build is optimized for remote build caching when invoked from different CI agents. |
| 05-validate-remote-build-caching-ci-local.sh | Validates that a Gradle build is optimized for remote build caching when invoked on CI agent and local machine. |
</details>

All intermediate and final output produced while running a given script is stored under `.data/<script_name>/<timestamp>-<run_id>`.

## Invocation

The scripts accept command line arguments of which some are the same for all scripts and some are
specific to a given script. The following arguments are present on all scripts:

- `-h`, `--help`: Shows a help message including all command line arguments supported by the script
- `-v`, `--version`: Shows the version number of the script
- `-i`, `--interactive`: Runs the script in interactive mode, providing extra context and guidance along the way

It is recommended that you run a given script in _interactive_ mode for the first time to make yourself familiar
with the flow of that experiment. In the example below, the script is executed interactively.

```bash
./02-validate-local-build-caching-same-location.sh -i
```

Once you are familiar with a given experiment, you can run the script in _non-interactive_ mode. In the example below,
the script is run autonomously with the provided configuration options.

```bash
./02-validate-local-build-caching-same-location.sh -r https://github.com/gradle/gradle-build-scan-quickstart -t build
```

You can also combine the _interactive_ mode with some configuration options already provided at the time the script
is invoked, as shown in the example below.

```bash
./02-validate-local-build-caching-same-location.sh -i -r https://github.com/gradle/gradle-build-scan-quickstart
```

The scripts return with an exit code that depends on the outcome of running a given experiment.

| Exit Code | Reason                                                                                                                         |
|-----------|--------------------------------------------------------------------------------------------------------------------------------|
| 0         | The experiment completed successfully                                                                                          |
| 1         | An invalid input was provided while attempting to run the experiment                                                           |
| 2         | One of the builds that is part of the experiment failed                                                                        |
| 3         | Option `--fail-if-not-fully-cacheable` was set and the build was not fully cacheable for the given task graph                  |
| 4         | Option `--fail-if-not-fully-cacheable` was set and performance characteristics are unknown, e.g., due to a failed API response |
| 100       | An unclassified, fatal error happened while running the experiment                                                             |

## Verifying the setup

You can verify that the script can properly interact with your Develocity server. In the example below, the script will configure 
the local builds to publish their build scans to a Develocity server reachable at develocity.example.io.

```bash
./01-validate-incremental-building.sh -t assemble -r https://github.com/gradle/gradle-build-scan-quickstart -e -s https://develocity.example.io
```

## Authenticating with Develocity

Some scripts fetch data from build scans that were published as part of running an experiment. The build scan data is fetched by leveraging the [Develocity API](https://docs.gradle.com/develocity/api-manual/). It is not strictly necessary that you have permission to call these APIs to execute a script successfully, but the summary provided once the script has finished running its experiment will be more comprehensive if the build scan data is accessible.

You can check your granted permissions by navigating in the browser to the 'My Settings' section from the user menu of your Develocity UI. You need the 'Access build data via the API' permission. Additionally, the script needs an access key to authenticate with the APIs. See [Authenticating with Develocity](https://docs.gradle.com/develocity/gradle-plugin/current/#authenticating) for details on how to create an access key and storing it locally.

By default, the scripts fetching build scan data try to find the access key in the `develocity/keys.properties` file within the Gradle user home directory (`~/.gradle` by default). Alternatively, the access key can be specified via the `DEVELOCITY_ACCESS_KEY` environment variable. You can also authenticate with the APIs using username and password instead by setting the `DEVELOCITY_USERNAME` and `DEVELOCITY_PASSWORD` environment variables.

## Configuring the network settings to connect to Develocity

The scripts that fetch build scan data can be configured to use a HTTP(S) proxy, to use a custom Java trust store, and to disable SSL certificate validation when connecting to Develocity. The network settings configuration is automatically picked up by the build validation scripts from a `network.settings` file put in the same location as where the scripts are run. A [configuration file template](components/scripts/network.settings) can be found at the same location as where the scripts are located.

If your Develocity server can only be reached via a HTTP(S) proxy, edit the `network.settings` file and uncomment and update the lines that start with `http.` and `https.`, using the values required by your HTTP(S) proxy server.

If your Develocity server is using a certificate signed by an internal Certificate Authority (CA), edit the `network.settings` file and uncomment and update the lines that start with `javax.net.ssl.trustStore`, specifying where your custom trust store is, what type of trust store it is, and the password required to access the trust store.

In the unlikely and insecure case that your Develocity server is using a self-signed certificate, edit the `network.settings` file and uncomment and update the lines that start with `ssl`.

If the requests to fetch the build scan data from your Develocity server are timing out, edit the `network.settings` file and uncomment and update the lines that end with `timeout`.

## Configuring custom value lookup names

The scripts that fetch build scan data expect some of it to be present as custom values (Git repository, branch name, and commit id). By default, the scripts assume that these custom values have been created by the [Common Custom User Data Gradle plugin](https://plugins.gradle.org/plugin/com.gradle.common-custom-user-data-gradle-plugin). If you are not using that plugin but your build still captures the same data under different custom value names, you can provide a mapping file so that the required data can be extracted from your build scans. An example mapping file named [mapping.example](components/scripts/mapping.example) can be found at the same location as where the scripts are located.

```bash
./04-validate-remote-build-caching-ci-ci.sh -i -m mapping.custom
```

## Redirecting build scan publishing

The scripts that run one or more builds locally can be configured to publish build scans to a different
Develocity server than the one that the builds point to by passing the `-s` or `--develocity-server`
command line argument. In the example below, the script will configure the local builds to publish their build scans
to develocity.example.io regardless of what server is configured in the build.

```bash
./02-validate-local-build-caching-same-location.sh -i -s https://develocity.example.io
```

## Instrumenting the build with Develocity

The scripts that run one or more builds locally can be configured to connect the builds to a given Develocity
server in case the builds are not already connected to Develocity by passing the `-e` or `--enable-develocity`
command line argument. In the example below, the script will configure the non-instrumented builds to connect to the
Develocity server at develocity.example.io.

```bash
./02-validate-local-build-caching-same-location.sh -i -e -s https://develocity.example.io
```

## Specifying the JVM used to analyze the build data

The scripts use a Java-based utility to fetch and analyze the captured build data.
If you need to run the utility with a different Java Virtual Machine than what is configured by default on your system and used when running your builds,
then you can set the `CLIENT_JAVA_HOME` environment variable when invoking the scripts:

```bash
CLIENT_JAVA_HOME="/opt/java/temurin-17.0.7+7" ./02-validate-local-build-caching-same-location.sh -i
```

If `CLIENT_JAVA_HOME` is not specified, then the utility will use the JVM referenced by the `JAVA_HOME` environment variable.
If `JAVA_HOME` is not defined, then the utility will use the Java executable found on the system path.

## Analyzing the results

Once a script has finished running its experiment, a summary of what was run and what the outcome was is printed on
the console. The outcome is primarily a set of links pointing to build scans that were captured as part of running the
builds of the experiment. Some links also point to build scan comparison. The links have been carefully crafted such that
they bring you right to where it is revealed how well your build avoids unnecessary work.

The summary looks typically like in the screenshot below.

![image](https://user-images.githubusercontent.com/5797900/234092400-0be22de4-678f-4f1f-9a42-ff13c6346096.png)

### Performance characteristics

<details>
  <summary>Click to see more details about each of the calculated performance characteristics.</summary>

#### Initial build time

The elapsed time of the first build without any build performance acceleration measures explicitly applied by the experiment.

#### Build time with instant savings

The elapsed time of the second build with build performance acceleration measures explicitly applied by the experiment. The experienced build performance acceleration typically comes from the incremental build feature (experiment 1) or build caching (experiments 2 to 5).

Achieving the build time with instant savings does not require any changes to the tasks of the build.

#### Build time with pending savings

The projected elapsed build time of the second build with build performance acceleration measures explicitly applied by the experiment. The projection assumes that all cacheability issues of the executed cacheable tasks get resolved, and it takes into account the degree of parallelization in task execution.

Achieving the build time with pending savings requires changes to the executed cacheable tasks of the build.

#### Avoided cacheable tasks

The estimated reduction in serial execution time of the tasks of the second build due to reusing the task outputs from the first build. The avoidance savings are calculated as the difference between the time required to reuse the task outputs and the time it took to create the task outputs originally.

#### Executed cacheable tasks

The serial execution time of the tasks executed in the second build that Gradle considered cacheable. These tasks stored their outputs in the build cache during the first build but were unable to reuse the outputs during the second build.

These executed cacheable tasks can usually be fixed such that their outputs are reused in the second build of the experiment.

####  Executed non-cacheable tasks

The serial execution time of the tasks executed in the second build that Gradle considered non-cacheable. These tasks did not store their outputs in the build cache during the first build and did not try to reuse the outputs during the second build.

These executed non-cacheable tasks can oftentimes be made cacheable through the proper declaration of their inputs and outputs such that their outputs can be stored during the first build of the experiment and reused in the second build of the experiment.

#### Serialization factor

An indicator for the degree of parallelization in task execution. The higher the number, the higher the parallelization of the executed tasks. The serialization factor allows approximately converting serial execution time to elapsed time, aka wall-clock time.

</details>

## Investigating file resources on the local file system

For the scripts that run one or more builds locally, the file resources that are used and produced by the builds can be investigated on the local file system. This is helpful when trying to understand cache misses due to changes in file inputs of the executed tasks. All intermediate and final output produced while running a given script is stored under `.data/<script_name>/<timestamp>-<run_id>`.

Note that even when a script needs to run two builds from the same physical location, the individual builds are always preserved in separate folders, allowing to compare the same files from the two builds with each other.

The folder hierarchy produced by the scripts under the `.data` folder looks typically like in the screenshot below.

![image](https://user-images.githubusercontent.com/231070/147548879-27a77148-bf24-4f9a-902e-460ce2f0c39d.png)

## Using a local Git repository to accelerate the validation process

For the scripts that run one or more builds locally, the scripts can be pointed at a local checkout of the Git repository that contains the build. Even though the scripts always perform a shallow clone of the investigated Git repository to improve performance and to save disk space, it may still be expensive to repeatedly clone the Git repository over the network while going through cycles of validating and optimizing the build.

In the example below, the Git repository is first checked out to a location on the local disc. The script is then invoked and instructed to clone the local copy instead of the remote repository, avoiding any network overhead.

```bash
git clone https://github.com/gradle/gradle-build-scan-quickstart $HOME/gradle-build-scan-quickstart
./02-validate-local-build-caching-same-location.sh -i -r file://$HOME/gradle-build-scan-quickstart
```

> [!IMPORTANT]
> Regardless of whether you use a local or remote Git repository, any changes _must be_ commited for them to be picked up by the experiments.
> The benefit of using a local Git repository is that the changes don't need to be pushed to the remote repository.

## Dealing with filename too long errors on Windows

When the scripts clone the Git project, an error might occur on Windows when the absolute paths of the checked out files are longer than 260 characters. This problem can be addressed by passing the `core.longpaths` Git configuration option to the scripts.

```bash
./02-validate-local-build-caching-same-location.sh -i -o "--depth=1 -c core.longpaths=true"
```
