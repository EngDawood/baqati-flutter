allprojects {
    repositories {
        google()
        mavenCentral()
        // Fallbacks: used only if the official hosts above can't be reached, which
        // happens on networks where dl.google.com / repo.maven.apache.org time out.
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        maven { url = uri("https://storage.flutter-io.cn/download.flutter.io") }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

// Some plugins declare their own Android Gradle Plugin on their buildscript
// classpath — flutter_local_notifications 20.1.0 pins 8.6.0. That classpath is
// resolved separately from the `allprojects.repositories` above, so it neither
// sees the mirrors nor reuses the AGP this project already builds with.
//
// Both problems are fixed here: give those buildscripts the same mirrors, and
// pin every AGP request to the version the root build already uses, so no extra
// AGP tree has to be downloaded at all.
val agpVersion = "8.9.1"

subprojects {
    buildscript {
        repositories {
            google()
            mavenCentral()
            maven { url = uri("https://maven.aliyun.com/repository/google") }
            maven { url = uri("https://maven.aliyun.com/repository/public") }
        }
        configurations.configureEach {
            resolutionStrategy.eachDependency {
                if (requested.group == "com.android.tools.build" &&
                    requested.name == "gradle"
                ) {
                    useVersion(agpVersion)
                    because("reuse the AGP the app builds with; avoids fetching a second AGP tree")
                }
            }
        }
    }
}

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
