package cn.ntars.tapmc.server.storage;

import cn.ntars.tapmc.core.WorldGrid;
import cn.ntars.tapmc.core.WorldGenerator;
import cn.ntars.tapmc.core.storage.StorageException;
import cn.ntars.tapmc.protocol.dto.BlockType;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * JSON 存档的读写测试。
 *
 * <p>这些用例都落在真实临时目录上（{@link TempDir}），不做任何文件系统打桩——
 * 存档 bug 的典型形态是「路径拼接 / 编码 / 原子替换」出错，用内存假文件系统测不出来。
 */
@DisplayName("JSON 世界存档")
class JsonWorldStoreTest {

    @Test
    @DisplayName("保存后能原样读回，逐格一致")
    void saveThenLoadIsIdentical(@TempDir Path dir) {
        Path file = dir.resolve("world.json");
        JsonWorldStore store = new JsonWorldStore(file);

        WorldGrid world = new WorldGrid(5, 4);
        world.set(0, 0, BlockType.STONE);
        world.set(4, 3, BlockType.WATER);
        world.set(2, 2, BlockType.WOOD);
        store.save(world);

        assertTrue(Files.exists(file), "保存后文件必须存在");
        Optional<WorldGrid> loaded = store.load(5, 4);
        assertTrue(loaded.isPresent(), "刚存的档必然能读回");
        for (int y = 0; y < 4; y++) {
            for (int x = 0; x < 5; x++) {
                assertEquals(world.get(x, y), loaded.get().get(x, y), "(" + x + "," + y + ") 应一致");
            }
        }
    }

    @Test
    @DisplayName("没有存档文件时返回空，不抛异常")
    void missingFileGivesEmpty(@TempDir Path dir) {
        JsonWorldStore store = new JsonWorldStore(dir.resolve("nope.json"));
        assertTrue(store.load(4, 4).isEmpty(), "「没存档」是正常情况，不该当错误");
    }

    @Test
    @DisplayName("内容损坏时返回空并把坏档改名留档")
    void corruptFileIsQuarantined(@TempDir Path dir) throws IOException {
        Path file = dir.resolve("world.json");
        Files.writeString(file, "{ 这不是合法 JSON ");

        JsonWorldStore store = new JsonWorldStore(file);
        assertTrue(store.load(4, 4).isEmpty());
        assertFalse(Files.exists(file), "坏档应被移走，否则下次还会踩同一个坑");

        try (var stream = Files.list(dir)) {
            long quarantined = stream.filter(p -> p.getFileName().toString().contains(".corrupt-")).count();
            assertEquals(1, quarantined, "应留下一个 .corrupt- 备份，便于事后捞数据");
        }
    }

    @Test
    @DisplayName("存档尺寸与当前世界不符时返回空，不误载入")
    void sizeMismatchIsRejected(@TempDir Path dir) {
        Path file = dir.resolve("world.json");
        JsonWorldStore store = new JsonWorldStore(file);
        store.save(new WorldGrid(8, 6));

        assertTrue(store.load(12, 8).isEmpty(), "尺寸不符必须拒绝，否则前端渲染会错位");
    }

    @Test
    @DisplayName("格式版本不认识时保留原文件（可能是新版本写的档）")
    void unknownFormatVersionKeepsFile(@TempDir Path dir) throws IOException {
        Path file = dir.resolve("world.json");
        Files.writeString(file, """
                {"formatVersion":999,"width":2,"height":1,"savedAt":"x","blocks":["DIRT","DIRT"]}
                """);

        JsonWorldStore store = new JsonWorldStore(file);
        assertTrue(store.load(2, 1).isEmpty());
        assertTrue(Files.exists(file), "不认识的版本不该被改名或删除——可能来自更新版本的程序");
    }

    @Test
    @DisplayName("保存会自动创建不存在的父目录")
    void saveCreatesParentDirectories(@TempDir Path dir) {
        Path file = dir.resolve("nested").resolve("deep").resolve("world.json");
        new JsonWorldStore(file).save(new WorldGrid(2, 2));
        assertTrue(Files.exists(file));
    }

    @Test
    @DisplayName("保存不会残留临时文件")
    void saveLeavesNoTempFile(@TempDir Path dir) throws IOException {
        Path file = dir.resolve("world.json");
        new JsonWorldStore(file).save(new WorldGrid(2, 2));

        try (var stream = Files.list(dir)) {
            List<String> names = stream.map(p -> p.getFileName().toString()).toList();
            assertEquals(List.of("world.json"), names, "目录里只应留下存档本体：" + names);
        }
    }

    @Test
    @DisplayName("目标是目录时保存失败，抛 StorageException 而不是静默丢弃")
    void saveIntoDirectoryFails(@TempDir Path dir) throws IOException {
        Path asDir = dir.resolve("world.json");
        Files.createDirectory(asDir);
        JsonWorldStore store = new JsonWorldStore(asDir);
        assertThrows(StorageException.class, () -> store.save(new WorldGrid(2, 2)));
    }

    @Test
    @DisplayName("大世界（24x16）存档后读回仍逐格一致")
    void defaultWorldRoundTrip(@TempDir Path dir) {
        Path file = dir.resolve("world.json");
        JsonWorldStore store = new JsonWorldStore(file);

        WorldGrid world = WorldGenerator.generate(24, 16);
        store.save(world);
        WorldGrid loaded = store.load(24, 16).orElseThrow();

        assertEquals(world.toBlockNames(), loaded.toBlockNames(), "生成的整张地图应原样回来");
    }
}
