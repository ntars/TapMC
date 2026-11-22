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

    // JUnit 的 jar 附件用于动态加载测试：测试自己生成一个带 Service 文件的 jar，
    // 再让加载器像加载第三方模组一样从磁盘读入。
    testImplementation("org.junit.jupiter:junit-jupiter-api")
}

sourceSets {
    test {
        resources {
            // 测试用模组 jar 是二进制 fixture，放 src/test/resources 会被 Gradle 复制。
            srcDir("src/test/java/cn/ntars/tapmc/server/fixtures")
            include("*.jar")
        }
    }
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

// 让 `./gradlew build` 顺带产出 fatJar。
// 少了这一行会踩到一个很难看的坑：验证脚本按通配找 server-*-all.jar，找到的是
// 上一轮留下的旧产物，于是「代码改了但脚本测的是旧代码」，失败信息还指向别处。
tasks.named("assemble") {
    dependsOn("fatJar")
}
