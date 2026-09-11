allprojects {
    repositories {
        google()
        mavenCentral()

        // What every consumer of this plugin has to add today, and the reason
        // the README says so: an app resolves its dependencies itself, so the
        // one-artifact repository the plugin carries for the Sanbuk SDK is
        // invisible from here unless the app names it too. This line goes away
        // the day ir.sanbuk:sdk-android is published somewhere reachable.
        maven { url = uri("${rootDir}/../../android/repo") }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
