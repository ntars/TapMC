plugins {
    `java-library`
}

// 模组 SPI 模块：只定义「模组能做什么」的接口与事件模型，不依赖 core 与 server。
// 这样第三方模组编译时只需依赖本模块这一个 jar，不必把服务端一起拉进来。
// 注意：本模块的接口一旦发布就要保持向后兼容，加方法请用 default 方法。
dependencies {
    api(project(":protocol"))
}
