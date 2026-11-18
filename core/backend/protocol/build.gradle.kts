plugins {
    `java-library`
}

// 线协议模块：只放「双方约定的数据形状」，不含任何业务逻辑。
// 前端 Dart 侧的字段名必须与本模块的 @SerializedName 完全一致，
// 改动此模块即等于改动协议，需同步 docs/protocol.md。
dependencies {
    api("com.google.code.gson:gson:2.15.0")
}
