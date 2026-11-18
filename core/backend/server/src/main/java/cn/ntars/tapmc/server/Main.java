package cn.ntars.tapmc.server;

import java.net.InetSocketAddress;

/**
 * 服务端入口。启动后可被 Flutter 前端以 WebSocket 连上。
 *
 * <p>用法：
 * <pre>{@code
 * ./gradlew :server:run                 # 监听 127.0.0.1:8777
 * ./gradlew :server:run --args="9000"   # 换端口
 * java -jar server-0.1.0-all.jar        # 直接跑打包产物
 * }</pre>
 *
 * <p>默认只绑 127.0.0.1 而不是 0.0.0.0：这是个本地游戏服务，不该默认对局域网开放。
 * 要联机时显式传 {@code --host 0.0.0.0}。
 */
public final class Main {

    private static final int DEFAULT_PORT = 8777;
    private static final String DEFAULT_HOST = "127.0.0.1";

    private Main() {
    }

    public static void main(String[] args) throws InterruptedException {
        int port = DEFAULT_PORT;
        String host = DEFAULT_HOST;

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

        GameServer server = new GameServer();
        WebSocketGateway gateway = new WebSocketGateway(new InetSocketAddress(host, port), server);
        gateway.start();

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

                参数：
                  --port <n>   监听端口，默认 8777
                  --host <ip>  绑定地址，默认 127.0.0.1（仅本机）
                  --help       显示本帮助
                """);
    }
}
