import org.gradle.api.tasks.compile.JavaCompile
import org.gradle.api.tasks.testing.Test
import org.gradle.api.tasks.testing.logging.TestExceptionFormat

// 根构建脚本：只给四个子模块施加统一配置，自身不产出构件。
subprojects {
    // 用 java-library 而非 java：只有前者提供 api / implementation 的可见性区分，
    // 让「哪些类型是跨模块契约、哪些是实现细节」能写在构建脚本里。
    apply(plugin = "java-library")

    group = "cn.ntars.tapmc"
    version = "0.1.0"

    tasks.withType<JavaCompile>().configureEach {
        options.encoding = "UTF-8"
        // 字节码固定 Java 21（LTS）。用更新的 JDK 编译也能产出 21 兼容的 class，
        // 安卓端内置运行时与用户机器都不必追新版本。
        options.release.set(21)
        options.compilerArgs.addAll(listOf("-Xlint:all", "-Xlint:-serial"))
    }

    tasks.withType<Test>().configureEach {
        useJUnitPlatform()
        testLogging {
            events("passed", "skipped", "failed")
            exceptionFormat = TestExceptionFormat.FULL
        }
    }

    dependencies {
        "testImplementation"(platform("org.junit:junit-bom:6.1.3"))
        "testImplementation"("org.junit.jupiter:junit-jupiter")
        "testRuntimeOnly"("org.junit.platform:junit-platform-launcher")
    }
}
