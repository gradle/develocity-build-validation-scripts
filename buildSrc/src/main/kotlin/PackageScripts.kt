import org.gradle.api.file.ConfigurableFileCollection
import org.gradle.api.provider.Property
import org.gradle.api.tasks.Input
import org.gradle.api.tasks.InputFiles
import org.gradle.api.tasks.PathSensitive
import org.gradle.api.tasks.PathSensitivity
import org.gradle.api.tasks.bundling.Zip
import org.gradle.work.DisableCachingByDefault

@DisableCachingByDefault(because = "Not worth caching")
abstract class PackageScripts : Zip() {

    @get:Input
    abstract val distributionName: Property<String>

    @get:Input
    abstract val distributionVersion: Property<String>

    @get:InputFiles
    @get:PathSensitive(PathSensitivity.RELATIVE)
    abstract val distributionContents: ConfigurableFileCollection

    init {
        archiveBaseName.set(distributionName)
        archiveFileName.set(distributionName.zip(distributionVersion) { name, version -> "$name-$version.zip" })
        from(distributionContents) {
            include("**/*.sh")
            filePermissions {
                user {
                    execute = true
                }
            }
        }
        from(distributionContents) {
            exclude("**/*.sh")
        }
        into(archiveBaseName)
    }
}
