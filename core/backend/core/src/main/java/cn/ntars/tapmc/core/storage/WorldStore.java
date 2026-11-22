package cn.ntars.tapmc.core.storage;

import cn.ntars.tapmc.core.WorldGrid;

import java.util.Optional;

/**
 * 世界存档的读写口子。
 *
 * <p><b>为什么要抽接口</b>：{@code core} 模块的定位是「零网络、零 JSON、零框架」，
 * 存档格式（JSON / 二进制 / 数据库）属于实现细节，不该让游戏本体依赖。因此
 * {@code core} 只声明「能读能写一张网格」，具体落盘方式由 {@code server} 提供。
 * 这样同一份本体也能被文件存档、内存存档（测试）、将来的云存档分别驱动。
 *
 * <p><b>失败语义</b>：读不到（文件不存在／内容损坏）返回 {@link Optional#empty()}，
 * 由调用方决定是否新建世界——「没有存档」不是错误。真正写不进去（磁盘满、
 * 无权限）抛 {@link StorageException}，因为这时候静默吞掉等于悄悄丢数据。
 */
public interface WorldStore {

    /**
     * 读取存档。
     *
     * @param expectedWidth  期望宽度；与存档不符时视为不可用
     * @param expectedHeight 期望高度；与存档不符时视为不可用
     * @return 存档中的世界；没有可用存档时返回 {@link Optional#empty()}
     * @throws StorageException 文件存在但读取过程出错（权限、IO）
     */
    Optional<WorldGrid> load(int expectedWidth, int expectedHeight);

    /**
     * 保存世界。整体覆盖上一次存档。
     *
     * @throws StorageException 写入失败
     */
    void save(WorldGrid world);
}
