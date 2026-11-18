plugins {
    `java-library`
}

// 游戏本体逻辑：世界状态、玩家、规则判定。零网络、零 JSON、零框架依赖。
// 它只依赖 protocol（拿方块类型与坐标这些共享词）与 mod（暴露事件口子），
// 不依赖 server——这样同一套逻辑既能被 WebSocket 服务端驱动，
// 将来也能被别的传输层（进程内直调、命令行、单机存档工具）驱动。
dependencies {
    api(project(":protocol"))
    api(project(":mod"))
}
