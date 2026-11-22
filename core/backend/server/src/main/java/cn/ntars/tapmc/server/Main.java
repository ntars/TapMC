package cn.ntars.tapmc.server;

import cn.ntars.tapmc.server.storage.JsonWorldStore;

import java.net.InetSocketAddress;
import java.nio.file.Path;

/**
 * 服务端入口。启动后可被 Flutter 前端以 WebSocket 连上。
 *
 * <p>用法：
 * <pre>{@code
 * ./gradlew :server:run                 # 监听 127.0.0.1:8777，存档到 ./world.json
 * ./gradlew :server:run --args="9000"   # 换端口
 * java -jar server-0.1.0-all.jar --no-save   # 纯内存，不落盘
 * }</pre>
 *
 * <p>默认只绑 127.0.0.1 而不是 0.0.0.0：这是个本地游戏服务，不该默认对局域网开放。
 * 要联机时显式传 {@code --host 0.0.0.0}。
 *
 * <p><b>存档默认开启</b>：不存档的版本一重启就抹掉玩家成果，作为可交付产品不合适，
 * 因此默认写 {@code world.json}（相对当前工作目录）。想跑一次性验证就传
 * {@code --no-save}，或在 {@code macos_verify.sh} 这类脚本里给独立路径，避免污染。
 */
public final class Main {

    private static final int DEFAULT_PORT = 8777;
    private static final String DEFAULT_HOST = "127.0.0.1";
    private static final String DEFAULT_SAVE_FILE = "world.json";
    private static final String DEFAULT_MOD_DIR = "mods";

    private Main() {
    }

    public static void main(String[] args) throws InterruptedException {
        int port = DEFAULT_PORT;
        String host = DEFAULT_HOST;
        String savePath = DEFAULT_SAVE_FILE;
        String modDir = DEFAULT_MOD_DIR;
        boolean persist = true;
        // 定时保存的默认周期。只在有改动时写盘，见 SaveDaemon。
        long autosaveSeconds = 60;

        for (int i = 0; i < args.length; i++) {
            switch (args[i]) {
                case "--port" -> {
                    if (i + 1 < args.length) {
                        port = Integer.parseInt(args[++i]);
                    }
                }
                case "--host" -> {
                    if (i + 1 < args.length) {
                        host = args[++i];
                    }
                }
                case "--save" -> {
                    persist = true;
                    if (i + 1 < args.length && !args[i + 1].startsWith("-")) {
                        savePath = args[++i];
                    }
                }
                case "--no-save" -> persist = false;
                case "--mods" -> {
                    if (i + 1 < args.length) {
                        modDir = args[++i];
                    }
                }
                case "--save-file" -> {
                    if (i + 1 < args.length) {
                        savePath = args[++i];
                    }
                }
                case "--autosave" -> {
                    if (i + 1 < args.length) {
                        autosaveSeconds = Long.parseLong(args[++i]);
                    }
                }
                case "--help", "-h" -> {
                    printUsage();
                    return;
                }
                default -> {
                    if (!args[i].startsWith("-")) {
                        port = Integer.parseInt(args[i]);
                    }
                }
            }
        }

        JsonWorldStore store = persist ? new JsonWorldStore(Path.of(savePath)) : null;
        GameServer server = new GameServer(
                GameServer.defaultWidth(), GameServer.defaultHeight(), java.util.List.of(), store);
        server.reloadModsFrom(Path.of(modDir));
        WebSocketGateway gateway = new WebSocketGateway(new InetSocketAddress(host, port), server);

        if (store != null) {
            System.out.println("[TapMC] 存档文件 " + store.file()
                    + (server.loadedFromStore() ? "（已恢复上次世界）" : "（本次新建世界）"));
        } else {
            System.out.println("[TapMC] 存档已关闭（--no-save）：退出后世界不保留");
        }

        // 退出保存：Ctrl+C 触发的是 JVM shutdown hook，不是进程被 KILL。
        // 被 KILL -9 时任何措施都无效，这种情况靠 autosave 的周期写入兜底。
        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            if (server.persistent()) {
                boolean ok = server.save();
                System.out.println("[TapMC] 退出存档" + (ok ? "完成" : "失败"));
            }
        }, "tapmc-shutdown-save"));

        gateway.start();

        if (server.persistent() && autosaveSeconds > 0) {
            Thread autosave = new Thread(
                    new SaveDaemon(server, autosaveSeconds * 1000L), "tapmc-autosave");
            autosave.setDaemon(true);
            autosave.start();
        }

        System.out.println("[TapMC] 端口 " + port + "，按 Ctrl+C 停止");

        // Java-WebSocket 的 start() 是异步的，主线程需要在这里驻留。
        Thread.currentThread().join();
    }

    private static void printUsage() {
        System.out.println("""
                TapMC 游戏服务端

                用法：
                  java -jar tapmc-server.jar [端口]
                  java -jar tapmc-server.jar --port 8777 --host 127.0.0.1
                  java -jar tapmc-server.jar --save-file ~/.tapmc/world.json --autosave 30

                参数：
                  --port <n>       监听端口，默认 8777
                  --host <ip>      绑定地址，默认 127.0.0.1（仅本机）
                  --save [路径]     开启存档（默认，路径默认 ./world.json）
                  --save-file <路径> 指定存档路径
                  --autosave <秒>   定时存档周期，默认 60；0 表示只在退出时存
                  --no-save        关闭存档，世界只存在内存里
                  --mods <目录>    模组 jar 目录，默认 ./mods；扫描 *.jar 并按 SPI 加载
                  --help           显示本帮助

                退出码：
                  0 正常停止（存档已在退出钩子里写好）
                  1 启动失败（端口被占等）
                """);
    }
}
