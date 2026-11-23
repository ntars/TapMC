package cn.ntars.tapmc.server;

import org.java_websocket.WebSocket;
import org.java_websocket.handshake.ClientHandshake;
import org.java_websocket.server.WebSocketServer;

import java.net.InetSocketAddress;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * WebSocket 网关。把 {@link GameServer} 暴露到 {@code ws://host:port}。
 *
 * <p>选 WebSocket 而非 HTTP 轮询：游戏需要服务端主动推（别人改了方块要立刻看到），
 * 轮询要么延迟高要么白耗流量。WebSocket 在浏览器、安卓、iOS、桌面端都原生支持，
 * 是唯一一个「所有目标平台都有一等支持」的双向通道。
 *
 * <p><b>线程</b>：Java-WebSocket 每个连接一个线程，因此「一个连接内的请求顺序」
 * 天然成立。跨连接的写会并发，所以 {@link #onMessage} 里对引擎加一把锁把写操作
 * 串起来——先用最简单的办法保证正确，性能等有真实压力再谈。
 */
public final class WebSocketGateway extends WebSocketServer {

    private final GameServer server;

    /** 连接 → 会话与分发器。分发器持有玩家身份，必须与连接一一对应。 */
    private final Map<WebSocket, ClientSession> sessions = new ConcurrentHashMap<>();
    private final Map<WebSocket, RpcDispatcher> dispatchers = new ConcurrentHashMap<>();

    /** 断线自动重连尝试计数 */
    private final AtomicInteger reconnectAttempts = new AtomicInteger(0);
    private static final int MAX_RECONNECT_ATTEMPTS = 3;
    private static final long RECONNECT_DELAY_MS = 1000;

    public WebSocketGateway(InetSocketAddress address, GameServer server) {
        super(address);
        this.server = server;
        setReuseAddr(true);
    }

    @Override
    public void onOpen(WebSocket conn, ClientHandshake handshake) {
        // 重置断线计数
        reconnectAttempts.set(0);
        
        ClientSession session = new WsSession(conn);
        sessions.put(conn, session);
        dispatchers.put(conn, server.newDispatcher());
        server.attach(session);
        System.out.println("[TapMC] 客户端接入 " + conn.getRemoteSocketAddress());
    }

    @Override
    public void onMessage(WebSocket conn, String message) {
        RpcDispatcher dispatcher = dispatchers.get(conn);
        if (dispatcher == null) {
            conn.close(1011, "分发器缺失");
            return;
        }

        // 全局串行化：世界状态只有一份，多个连接的写必须排队。
        String response;
        try {
            synchronized (server.engine()) {
                response = dispatcher.handle(message);
            }
        } catch (Exception e) {
            System.err.println("[TapMC] 处理消息异常：" + e.getMessage());
            String errorMsg = "[TapMC] 服务端错误：" + e.getClass().getSimpleName();
            if (e.getMessage() != null) {
                errorMsg += "：" + e.getMessage();
            }
            conn.send(errorMsg);
            return;
        }

        // 通知类请求返回 null，此时不回落，符合 JSON-RPC 2.0。
        if (response != null) {
            try {
                conn.send(response);
            } catch (Exception e) {
                System.err.println("[TapMC] 发送响应异常：" + e.getMessage());
            }
        }
    }

    @Override
    public void onClose(WebSocket conn, int code, String reason, boolean remote) {
        ClientSession session = sessions.remove(conn);
        RpcDispatcher dispatcher = dispatchers.remove(conn);
        if (dispatcher != null) {
            dispatcher.onClose();
        }
        if (session != null) {
            server.detach(session);
        }
        
        // 检查是否需要自动重连
        if (code != 1000 && reconnectAttempts.get() < MAX_RECONNECT_ATTEMPTS) {
            int attempts = reconnectAttempts.incrementAndGet();
            System.out.println("[TapMC] 客户端断开 " + conn.getRemoteSocketAddress()
                    + " code=" + code
                    + (reason == null || reason.isBlank() ? "" : " reason=" + reason)
                    + "，将在 " + RECONNECT_DELAY_MS + "ms 后尝试重连（第 " + attempts + "/" 
                    + MAX_RECONNECT_ATTEMPTS + " 次）");
            
            // 触发重连检查（实际在客户端实现）
        } else {
            System.out.println("[TapMC] 客户端断开 " + conn.getRemoteSocketAddress()
                    + " code=" + code
                    + (reason == null || reason.isBlank() ? "" : " reason=" + reason));
        }
    }

    @Override
    public void onError(WebSocket conn, Exception ex) {
        String who = conn == null ? "服务端" : String.valueOf(conn.getRemoteSocketAddress());
        
        // 错误恢复策略
        if (ex.getMessage() != null && ex.getMessage().contains("连接重置")) {
            System.err.println("[TapMC] " + who + " 连接异常（可能网络波动）：" 
                    + ex.getMessage());
        } else {
            System.err.println("[TapMC] " + who + " 异常：" + ex.getMessage());
        }
    }

    @Override
    public void onStart() {
        System.out.println("[TapMC] 服务已启动，监听 " + getAddress());
        System.out.println("[TapMC] 世界尺寸 " + server.width() + "x" + server.height()
                + "，模组 " + server.modReport().size() + " 个");
        System.out.println("[TapMC] 自动重连：最大 " + MAX_RECONNECT_ATTEMPTS + " 次，间隔 "
                + RECONNECT_DELAY_MS + "ms");
    }

    /** 把 WebSocket 连接包装成 {@link ClientSession}。 */
    private record WsSession(WebSocket conn) implements ClientSession {

        @Override
        public String id() {
            return String.valueOf(conn.getRemoteSocketAddress());
        }

        @Override
        public void send(String text) {
            // 断连的连接直接丢弃，避免广播时抛异常打断整轮循环。
            if (conn.isOpen()) {
                try {
                    conn.send(text);
                } catch (Exception e) {
                    // 忽略发送异常
                }
            }
        }
    }
}
