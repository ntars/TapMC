package cn.ntars.tapmc.server;

/**
 * 一条客户端连接。RPC 分发器只知道「能往这里发文本」，不关心底层是 WebSocket
 * 还是进程内管道——测试里用假实现，线上用 WebSocket 实现。
 */
public interface ClientSession {

    /** 连接标识，用于日志与玩家 id 前缀。 */
    String id();

    /**
     * 发送一段文本。实现必须容忍「连接已断」的情况（静默丢弃即可），
     * 否则广播时一个断连客户端会让整轮广播失败。
     */
    void send(String text);
}
