package cn.ntars.tapmc.server;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.Socket;

/** 容器健康检查探针：连得上 WebSocket 监听端口就算存活。 */
public final class HealthProbe {

    private HealthProbe() {
    }

    public static void main(String[] args) {
        String host = args.length > 0 ? args[0] : "127.0.0.1";
        int port;
        try {
            port = args.length > 1 ? Integer.parseInt(args[1]) : 8777;
        } catch (NumberFormatException e) {
            System.err.println("[health] 端口不是数字：" + args[1]);
            System.exit(1);
            return;
        }

        try (Socket socket = new Socket()) {
            socket.connect(new InetSocketAddress(host, port), 2000);
        } catch (IOException e) {
            System.err.println("[health] 无法连接 " + host + ":" + port + "：" + e.getMessage());
            System.exit(1);
        }
    }
}
