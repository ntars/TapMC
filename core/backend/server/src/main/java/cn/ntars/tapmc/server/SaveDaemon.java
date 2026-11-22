package cn.ntars.tapmc.server;

/**
 * 定时存档。只在「自上次存档以来世界真的变过」时写盘。
 *
 * <p><b>为什么需要它</b>：退出钩子只能覆盖「正常退出」。容器被 {@code docker stop}
 * 后超时杀掉、断电、进程被 {@code kill -9}，钩子都不会执行。周期写盘把最坏情况下的
 * 丢失量从「整局」缩小到「一个周期」。
 *
 * <p><b>为什么按 revision 判断</b>：24×16 的地图写一次约几毫秒，但没人玩的时候
 * 每分钟重写同一个文件毫无意义——笔记本用户的磁盘和 SSD 寿命都是真实成本。
 *
 * <p><b>为什么 read 不需要额外加锁</b>：{@code engine.world()} 返回的是同一个可变对象，
 * 序列化过程中若别的线程正在改格子，可能读到「一半旧一半新」的快照。这在存档场景是可
 * 接受的：单格改动只影响一个字符，不会让整份文件损坏（文件本身是原子替换的）。要严格
 * 一致得让世界在存档期间停写，代价与收益不成比例。
 */
final class SaveDaemon implements Runnable {

    private final GameServer server;
    private final long intervalMillis;

    SaveDaemon(GameServer server, long intervalMillis) {
        this.server = server;
        this.intervalMillis = Math.max(1000L, intervalMillis);
    }

    @Override
    public void run() {
        long savedRevision = server.revision();
        while (!Thread.currentThread().isInterrupted()) {
            try {
                Thread.sleep(intervalMillis);
            } catch (InterruptedException e) {
                // 收到中断就安静退场：退出钩子会做最后一次保存。
                Thread.currentThread().interrupt();
                return;
            }
            long current = server.revision();
            if (current == savedRevision) {
                continue;
            }
            if (server.save()) {
                savedRevision = current;
            }
            // 保存失败时故意不更新 savedRevision：下个周期再试一次。
        }
    }
}
