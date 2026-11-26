rootProject.name = "tapmc-backend"

// 后端四个模块，依赖方向单向向下，不允许反向引用：
//   server  -> core -> mod
//   server  -> protocol
//   core    -> protocol
// protocol 与 mod 不依赖任何兄弟模块。
include("protocol")
include("mod")
include("core")
include("server")

// 使用阿里云镜像解决 Gradle SSL 问题
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    
    repositories {
        maven {
            url = uri("https://maven.aliyun.com/repository/public")
            // 允许不安全协议（如果需要）
        }
        mavenCentral()
    }
}
