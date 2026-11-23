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

// 使用国内镜像源解决 Gradle SSL 问题
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_ROOT)
    
    repositories {
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        maven { url = uri("https://mirrors.tuna.tsinghua.edu.cn/maven/repository/") }
        mavenCentral()
    }
}
