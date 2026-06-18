import com.github.megatronking.stringfog.plugin.StringFogExtension
import com.sqwerty.core.utils.ifNotExist
import com.sqwerty.res_guard.configureResGuardPlugin
import com.sqwerty.res_guard.extensions.ResGuardExtensions
import com.sqwerty.res_guard.extensions.ResResizeExtensions
import com.sqwerty.res_guard.utils.ResType
import io.github.valacuz.proguard.dictionary.DictionaryGeneratorPluginExtension
import io.github.valacuz.proguard.dictionary.tasks.generate.strategy.ObfuscationStrategy
import java.security.SecureRandom
import kotlin.random.Random

buildscript {
    repositories {
        mavenCentral()
        gradlePluginPortal()
        maven { url = uri("https://jitpack.io") }
    }
    dependencies {
        classpath("gradle.plugin.ru.cleverpumpkin.proguard-dictionaries-generator:plugin:1.0.8")
        classpath("io.github.valacuz:proguard-dict-generator:1.0.1")
        classpath("com.github.sq-dsl.SqGuard:sq.res-guard:0.0.1")
        classpath("com.github.megatronking.stringfog:gradle-plugin:5.2.0")
        classpath("com.github.megatronking.stringfog:xor:5.0.0")
    }
}

plugins {
    alias(libs.plugins.androidApplication)
    alias(libs.plugins.kotlinAndroid)
    alias(libs.plugins.composeCompiler)
    //id("com.google.gms.google-services") version "4.4.4" apply false
    //id("com.google.firebase.crashlytics") version "3.0.6" apply false
}

apply(plugin = "io.github.valacuz.proguard-dictionary-generator")
apply(plugin = "stringfog")
apply(plugin = "sq.res-guard")
apply(plugin = "ru.cleverpumpkin.proguard-dictionaries-generator")

configureResGuardPlugin<ResResizeExtensions> {
    enabled = true
    resizeHard = true
    pathToMagick = "/opt/homebrew/bin/magick"
}
if (
    file("$projectDir\\setup.txt").ifNotExist {
        createNewFile()
        writeText(
            "Resource obfuscation: ${Random.nextInt(0, 2)}${System.lineSeparator()}Strings obfuscation: ${Random.nextInt(0, 2)}${System.lineSeparator()}Code obfuscation: ${Random.nextInt(0, 3)}"
        )
    }.readLines().map {
        it.split(": ")[1]
    }[1].also {
        when (it) {
            "0" -> writeWithYellow("Code obfuscation: none")
            "1" -> writeWithYellow("Code obfuscation: valacuz")
            "2" -> writeWithYellow("Code obfuscation: CleverPumpkin")
        }
    }.toInt() in 1..2
) {
    if (
        file("$projectDir\\setup.txt").ifNotExist {
            createNewFile()
            writeText(
                "Resource obfuscation: ${Random.nextInt(0, 2)}${System.lineSeparator()}Strings obfuscation: ${Random.nextInt(0, 2)}${System.lineSeparator()}Code obfuscation: ${Random.nextInt(0, 3)}"
            )
        }.readLines().map {
            it.split(": ")[1]
        }[1] == "1"
    ) {
        extensions.configure(DictionaryGeneratorPluginExtension::class) {
            createConfigFile = true
            configFilePath = DictionaryGeneratorPluginExtension.DEFAULT_CONFIG_FILE_PATH
            fieldMethodObfuscationStrategy = ObfuscationStrategy.RANDOM_CHARACTERS
            classObfuscationStrategy = ObfuscationStrategy.RANDOM_CHARACTERS
            packageObfuscationStrategy = ObfuscationStrategy.RANDOM_CHARACTERS
            variantNameFilter = null // Regex pattern
        }
    } else {
        withGroovyBuilder {
            "proguardDictionaries" {
                setProperty("dictionaryNames", listOf(
                    "build/class-dictionary",
                    "build/package-dictionary",
                    "build/obfuscation-dictionary"
                ))
                setProperty("minLineLength", 20)
                setProperty("maxLineLength", 50)
                setProperty("linesCountInDictionary", 80000)
            }
        }
    }
}


configureResGuardPlugin<ResGuardExtensions> {
    enabled = (
            file("$projectDir\\setup.txt").ifNotExist {
                createNewFile()
                writeText(
                    "Resource obfuscation: ${Random.nextInt(0, 2)}${System.lineSeparator()}Strings obfuscation: ${Random.nextInt(0, 2)}${System.lineSeparator()}Code obfuscation: ${Random.nextInt(0, 3)}"
                )
            }.readLines().map {
                it.split(": ")[1]
            }[0] != "0"
            ).also {
            writeWithYellow("Resources obfuscation: $it")
        }
    maxNameLength = 255
    minNameLength = 16
    resTypes = listOf<ResType>(ResType.DRAWABLE)
    outputMappingPath = projectDir.path
}


configure<StringFogExtension> {
    enable = (
            file("$projectDir\\setup.txt").ifNotExist {
                createNewFile()
                writeText(
                    "Resource obfuscation: ${Random.nextInt(0, 2)}${System.lineSeparator()}Strings obfuscation: ${Random.nextInt(0, 2)}${System.lineSeparator()}Code obfuscation: ${Random.nextInt(0, 3)}"
                )
            }.readLines().map {
                it.split(": ")[1]
            }[1] != "0"
            ).also {
            writeWithYellow("Strings obfuscation: $it")
        }
    implementation = "com.github.megatronking.stringfog.xor.StringFogImpl"
    fogPackages = arrayOf(rootProject.extra["bundle"] as String)
    kg = com.github.megatronking.stringfog.plugin.kg.RandomKeyGenerator()
    mode = com.github.megatronking.stringfog.plugin.StringFogMode.base64
}

android {
    applicationVariants.all {
        val appName = rootProject.extra["app_name"] as String
        resValue("string", "app_name", appName)
    }

    namespace = rootProject.extra["bundle"] as String

    compileSdk = rootProject.extra["compileSdk"] as Int

    defaultConfig {
        applicationId = rootProject.extra["bundle"] as String
        minSdk = rootProject.extra["minSdk"] as Int
        targetSdk = rootProject.extra["targetSdk"] as Int
        versionCode = rootProject.extra["versionCode"] as Int
        versionName = rootProject.extra["versionName"] as String
    }
    buildTypes {
        release {
            isMinifyEnabled = rootProject.extra["isMinifyEnabled"] as Boolean
            isShrinkResources = rootProject.extra["isShrinkResources"] as Boolean
            when (
                //noinspection WrongGradleMethod
                file("$projectDir\\setup.txt").ifNotExist {
                    createNewFile()
                    writeText(
                        "Resource obfuscation: ${Random.nextInt(0, 2)}${System.lineSeparator()}Strings obfuscation: ${Random.nextInt(0, 2)}${System.lineSeparator()}Code obfuscation: ${Random.nextInt(0, 3)}"
                    )
                }.readLines().map {
                    it.split(": ")[1]
                }[1]
            ) {
                "0" -> proguardFiles(
                    getDefaultProguardFile("proguard-android-optimize.txt"),
                    "proguard-rules.pro"
                )
                "1" -> proguardFiles(
                    getDefaultProguardFile("proguard-android-optimize.txt"),
                    "proguard-rules.pro", "valacuz.pro"
                )
                "2" -> proguardFiles(
                    getDefaultProguardFile("proguard-android-optimize.txt"),
                    "proguard-rules.pro", "pumpkin.pro"
                )
            }

        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.valueOf(rootProject.extra["javaVersion"] as String)
        targetCompatibility = JavaVersion.valueOf(rootProject.extra["javaVersion"] as String)
    }
    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
    kotlin {
        compileOptions {
            compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
        }
    }
    buildFeatures {
        compose = true
        buildConfig = true
    }
}

dependencies {
    implementation(projects.composeApp)
    implementation(libs.androidx.activity.compose)
    implementation(libs.compose.uiToolingPreview)

    implementation("com.github.megatronking.stringfog:xor:5.0.0")
    implementation(platform("com.google.firebase:firebase-bom:34.11.0"))
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-crashlytics")
    implementation("com.google.firebase:firebase-messaging")
}


gradle.addBuildListener(
    object : BuildListener {
        @Deprecated("Deprecated in Java")
        override fun buildFinished(result: BuildResult) {
            val manifest = rootProject.file("app\\src\\main\\AndroidManifest.xml")
            val googleServices = rootProject.file("app\\google-services.json")
            if (manifest.readText().contains("drawable/mock")) {
                writeWithRed("###################################")
                writeWithRed("#${getStringWithXInvisibleSymbols(33)}#")
                writeWithRed("#${getStringWithXInvisibleSymbols(3)}You didn`t change push icon${getStringWithXInvisibleSymbols(3)}#")
                writeWithRed("#${getStringWithXInvisibleSymbols(33)}#")
                writeWithRed("###################################")
            }
            if (googleServices.exists().not()) {
                writeWithRed("###################################")
                writeWithRed("#${getStringWithXInvisibleSymbols(33)}#")
                writeWithRed("#${getStringWithXInvisibleSymbols(2)}You didn`t add google-services${getStringWithXInvisibleSymbols(1)}#")
                writeWithRed("#${getStringWithXInvisibleSymbols(33)}#")
                writeWithRed("###################################")
            }
        }

        override fun settingsEvaluated(settings: Settings) {}
        override fun projectsLoaded(gradle: Gradle) {}
        override fun projectsEvaluated(gradle: Gradle) {}
    }
)

afterEvaluate {
    try {
        tasks.named("uploadCrashlyticsMappingFileRelease").configure { enabled = false }
    } catch (_ : Exception) {}
    tasks.named("preBuild") {
        finalizedBy("rebundle")
    }
}

tasks.register("rebundle") {
    val newBundle = rootProject.extra["bundle"] as String
    val oldBundle = getCurrentBundleViaRecursion(file("${projectDir}/src/main/kotlin"))
        .replace("kotlin.", "")

    onlyIf { newBundle != oldBundle }

    doLast {
        changeBundleInManifest(oldBundle, newBundle)
        val newFolder = file("${projectDir}/src/main/kotlin/${newBundle.replace(".", "/")}")
        val currentFolder = file("${projectDir}/src/main/kotlin/${oldBundle.replace(".", "/")}")
        // Copy to temp first to avoid recursive nesting when paths overlap
        val tempFolder = file("${projectDir}/src/main/kotlin/_rebundle_temp")
        if (tempFolder.exists()) tempFolder.deleteRecursively()
        currentFolder.copyRecursively(tempFolder)
        currentFolder.deleteRecursively()
        deleteOldFiles(currentFolder)
        tempFolder.copyRecursively(newFolder)
        tempFolder.deleteRecursively()
        getAllProjectFilesViaRecursion(newFolder).forEach { file ->
            file.inputStream().use { fis ->
                val reBundled = fis.readBytes().decodeToString()
                    .replace(oldBundle, newBundle)
                file.outputStream().use { fos ->
                    fos.write(reBundled.encodeToByteArray())
                }
            }
        }
    }
}

fun changeBundleInManifest(oldBundle: String, newBundle: String) {
    file("${projectDir}/src/main/AndroidManifest.xml").apply {
        this.inputStream().use { fis ->
            val reBundled = fis.readBytes().decodeToString()
                .replace(oldBundle, newBundle)
            this.outputStream().use { fos ->
                fos.write(reBundled.encodeToByteArray())
            }
        }
    }
}

fun getCurrentBundleViaRecursion(file: File): String {
    if (!file.isDirectory) return file.nameWithoutExtension
    val children = file.listFiles()?.filter { it.name != ".DS_Store" } ?: emptyList()
    val hasFiles = children.any { it.isFile }
    val dirs = children.filter { it.isDirectory }
    return if (hasFiles || dirs.size != 1) file.name
    else file.name + "." + getCurrentBundleViaRecursion(dirs[0])
}

fun deleteOldFiles(file: File) {
    val list = file.listFiles()?.filter { it.name != ".DS_Store" } ?: emptyList()
    if (list.isEmpty()) {
        file.delete()
        deleteOldFiles(file.parentFile)
    }
}

fun getAllProjectFilesViaRecursion(file: File): List<File> {
    return if (file.listFiles() == null) listOf(file)
    else file.listFiles()!!.map {
        getAllProjectFilesViaRecursion(it)
    }.flatten()
}
fun getStringWithXInvisibleSymbols(x : Int) : String {
    val sb = StringBuilder()
    repeat(x) {
        sb.append("\u200E ")
    }
    return sb.toString()
}
fun writeWithRed(text : String) {
    logger.lifecycle("\u001B[31m$text\u001B[0m")
}
fun writeWithYellow(text: String) {
    logger.lifecycle("\u001B[33m$text\u001B[0m")
}
fun generateRandom() : String {
    val chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    val random = SecureRandom()
    return (1..50)
        .map { chars[random.nextInt(chars.length)] }
        .joinToString("")
}
