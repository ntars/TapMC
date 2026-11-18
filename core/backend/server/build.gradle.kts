plugins {
    java
    application
}

// 服务端：唯一职责是「把网络字节翻译成 core 的方法调用，再把结果翻译回去」。
// 这里可以出现 JSON、WebSocket、线程调度；游戏规则一律不写在这一层。
dependencies {
    implementation(project(":core"))
    implementation(project(":protocol"))

    // WebSocket 实现。选 Java-WebSocket 而不是 Jakarta WebSocket：
    // 后者需要一个 Servlet 容器（Tomcat/Jetty），为了一个本地服务端起容器太重。
    implementation("org.java-websocket:Java-WebSocket:1.6.0")
    implementation("org.slf4j:slf4j-api:2.0.17")
    runtimeOnly("org.slf4j:slf4j-simple:2.0.17")
}

application {
    mainClass.set("cn.ntars.tapmc.server.Main")
}

// 打一个包含全部依赖的可执行 jar，前端或用户直接 java -jar 就能起服务。
tasks.register<Jar>("fatJar") {
    archiveClassifier.set("all")
    duplicatesStrategy = DuplicatesStrategy.EXCLUDE
    manifest {
        attributes["Main-Class"] = "cn.ntars.tapmc.server.Main"
    }
    from(sourceSets.main.get().output)
    dependsOn(configurations.runtimeClasspath)
    from({
        configurations.runtimeClasspath.get()
            .filter { it.name.endsWith(".jar") }
            .map { zipTree(it) }
    })
}
