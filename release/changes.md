> [!IMPORTANT]
> The distributions of the Develocity Build Validation Scripts prefixed with `gradle-enterprise` are deprecated and will be removed in a future release. Migrate to the distributions prefixed with `develocity` instead.

- [NEW] Support Develocity and Gradle Enterprise remote build cache connectors in the Gradle CI/Local experiment  
- [NEW] Better handling of remote build cache misconfigurations
- [FIX] Scripts do not wait long enough for build scans to become available when `--fail-if-not-fully-cacheable` is used
- [FIX] Successful exit code returned when performance characteristics are unknown and `--fail-if-not-fully-cacheable` is used
- [FIX] Gradle experiments do not disable background Build Scan publication
- [FIX] Common Custom User Data Gradle plugin not injected for Gradle builds
- [FIX] Build Scan publishing is not enforced for the Develocity Gradle plugin
