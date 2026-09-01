allprojects {
    repositories {
        // 02.09.2026: RuStore SDK (ru.rustore.sdk, ru.ok.tracer) yalnız VK'nın
        // artifactory'sinde yayınlanıyor; 01.09 gecesi o sunucu tümden 404 verince
        // CI build'i düştü. Kopyalar repo içinde (android/local-maven, ~3 MB) —
        // önce buraya bakılır, eksik olan varsa sıradaki depolar denenir.
        maven { url = uri("${rootProject.projectDir}/local-maven") }
        google()
        mavenCentral()
    }
}

subprojects {
    plugins.withId("com.android.library") {
        extensions.configure<com.android.build.gradle.LibraryExtension> {
            if (namespace == null) {
                val manifestFile = file("src/main/AndroidManifest.xml")
                if (manifestFile.exists()) {
                    val pkg = groovy.xml.XmlSlurper().parse(manifestFile)
                        .getProperty("@package")?.toString()
                    if (!pkg.isNullOrEmpty()) namespace = pkg
                }
            }
        }
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

// Eski compileSdk'lı pluginler (appmetrica) APK'nın verifyReleaseResources adımında
// lStar hatası veriyor. Plugin kendi build script'inde compileSdk'yı sonradan
// yazdığı için zorlama afterEvaluate'te yapılmalı — plugins.withId anında yapılan
// atama eziliyor (#607 kanıtı).
subprojects {
    afterEvaluate {
        extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)
            ?.takeIf { it.compileSdk == null || it.compileSdk!! < 31 }
            ?.compileSdk = 36
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
