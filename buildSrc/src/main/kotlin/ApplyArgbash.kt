import org.gradle.api.DefaultTask
import org.gradle.api.file.ConfigurableFileTree
import org.gradle.api.file.DirectoryProperty
import org.gradle.api.file.ProjectLayout
import org.gradle.api.model.ObjectFactory
import org.gradle.api.provider.Property
import org.gradle.api.tasks.CacheableTask
import org.gradle.api.tasks.InputDirectory
import org.gradle.api.tasks.InputFiles
import org.gradle.api.tasks.OutputDirectory
import org.gradle.api.tasks.PathSensitive
import org.gradle.api.tasks.PathSensitivity
import org.gradle.api.tasks.TaskAction
import org.gradle.process.ExecOperations
import javax.inject.Inject

@CacheableTask
abstract class ApplyArgbash @Inject constructor(
    private val layout: ProjectLayout,
    private val objects: ObjectFactory,
    private val execOperations: ExecOperations
) : DefaultTask() {

    @get:InputFiles
    @get:PathSensitive(PathSensitivity.RELATIVE)
    abstract val scriptTemplates: Property<ConfigurableFileTree>

    @get:InputFiles
    @get:PathSensitive(PathSensitivity.RELATIVE)
    abstract val supportingTemplates: Property<ConfigurableFileTree>

    @get:InputDirectory
    @get:PathSensitive(PathSensitivity.RELATIVE)
    val argbashHome: DirectoryProperty = objects.directoryProperty()

    @get:OutputDirectory
    val outputDir: DirectoryProperty = objects.directoryProperty().apply {
      set(layout.buildDirectory.get().dir("generated/scripts"))
    }

    @TaskAction
    fun applyArgbash() {
        val argbash = argbashHome.get().file("bin/argbash").asFile
        scriptTemplates.get().visit {
            if(!isDirectory) {
                val relPath = relativePath.parent.pathString
                val basename = file.nameWithoutExtension
                val outputFile = outputDir.get().file("$relPath/$basename.sh").asFile
                outputFile.parentFile.mkdirs()

                logger.info("Applying argbash to $file")
                execOperations.exec {
                    commandLine("/usr/bin/env", "bash", argbash, file, "-o", outputFile)
                }
            }
        }
    }
}
