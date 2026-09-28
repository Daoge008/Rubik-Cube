allprojects {
    repositories {
        // See settings.gradle.kts for why the mirrors come first.
        maven("https://maven.aliyun.com/repository/google")
        maven("https://maven.aliyun.com/repository/public")
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Some plugins still declare an outdated compileSdk in their own build.gradle
// (e.g. vibration 2.1.0 pins compileSdkVersion 33). The AndroidX libraries the
// app pulls in require at least API 34, so such projects fail the
// checkDebugAarMetadata task. compileSdk only controls which APIs the code is
// compiled against - it is backward compatible - so raise every plugin
// subproject that lags behind to the app's level.
subprojects {
    // :app is force-evaluated by the block above, so afterEvaluate can no
    // longer be registered on it (it already declares compileSdk itself).
    if (!state.executed) {
        afterEvaluate {
            val androidExt = extensions.findByName("android") ?: return@afterEvaluate
            try {
                androidExt.withGroovyBuilder { setProperty("compileSdkVersion", 36) }
            } catch (e: Exception) {
                logger.lifecycle("compileSdk override skipped for ${project.name}: ${e.message}")
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
