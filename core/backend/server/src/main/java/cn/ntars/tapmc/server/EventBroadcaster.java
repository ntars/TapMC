package cn.ntars.tapmc.server;

import cn.ntars.tapmc.protocol.Methods;
import cn.ntars.tapmc.protocol.RpcEnvelope;
import cn.ntars.tapmc.protocol.dto.WorldChange;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;

import java.util.List;
import java.util.Map;
import java.util.function.Consumer;

/**
 * 把引擎事件转成服务端主动推送的 JSON-RPC 通知，并广播给所有连接。
 *
 * <p>事件没有 {@code id}，前端收到后不该回响应，直接更新界面即可。
 */
final class EventBroadcaster {

    /** 不输出 null 字段：事件不带 id，也不该出现 "id": null。 */
    private static final Gson GSON = new GsonBuilder().create();

    private EventBroadcaster() {
    }

    /** 世界变化的广播器。持有会话列表引用，这样连接增删会自动生效。 */
    static Consumer<WorldChange> worldChange(List<ClientSession> sessions) {
        return change -> {
            String payload = GSON.toJson(RpcEnvelope.event(Methods.EVENT_WORLD_CHANGED,
                    Map.of("change", change)));
            for (ClientSession session : sessions) {
                session.send(payload);
            }
        };
    }
}
