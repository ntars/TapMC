package cn.ntars.tapmc.server.storage;

import cn.ntars.tapmc.core.WorldGrid;
import cn.ntars.tapmc.core.storage.StorageException;
import cn.ntars.tapmc.core.storage.WorldStore;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonParseException;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.AtomicMoveNotSupportedException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.time.Instant;
import java.util.List;

/**
 * 把世界存成一个 JSON 文件。这是 {@code 0.2.0} 路线图「持久化存档」的落盘实现。
 *
 * <p><b>为什么是 JSON 而不是二进制</b>：24×16 = 384 格，文本约 4 KB，体积不构成问题；
 * 换来的是「出问题能直接打开看」。用二进制省下的几 KB 不值得让排障时必须写解析器。
 *
 * <p><b>为什么写入是「临时文件 + 原子改名」</b>：直接覆盖原文件时，若在写一半时
 * 断电／被 kill，存档会变成半截 JSON —— 既读不出来，原来的档也没了。写到同目录的
 * 临时文件再 {@link StandardCopyOption#ATOMIC_MOVE} 改名，保证任何时刻磁盘上要么是
 * 旧档、要么是新档，不会出现中间的残档。
 *
 * <p><b>坏档处理</b>：读不动时把文件改名成 {@code *.corrupt-<时间戳>} 留档再返回空，
 * 让服务端走「新建世界」的老路。改名而不是删除，是因为用户可能还想从里面捞点东西，
 * 而删掉就真没了。
 */
public final class JsonWorldStore implements WorldStore {

    /** 存档格式版本。字段语义变化时递增，旧版本仍应能被新代码识别或明确拒绝。 */
    public static final int FORMAT_VERSION = 1;

    private static final Gson GSON = new GsonBuilder()
            .setPrettyPrinting()
            .disableHtmlEscaping()
            .create();

    private final Path file;

    public JsonWorldStore(Path file) {
        this.file = file.toAbsolutePath().normalize();
    }

    public Path file() {
        return file;
    }

    @Override
    public java.util.Optional<WorldGrid> load(int expectedWidth, int expectedHeight) {
        if (!Files.exists(file)) {
            return java.util.Optional.empty();
        }

        String text;
        try {
            text = Files.readString(file, StandardCharsets.UTF_8);
        } catch (IOException e) {
            throw new StorageException("读取存档失败：" + file + "（" + e.getMessage() + "）", e);
        }

        SaveFile parsed;
        try {
            parsed = GSON.fromJson(text, SaveFile.class);
        } catch (JsonParseException e) {
            quarantine("JSON 解析失败");
            return java.util.Optional.empty();
        }

        if (parsed == null) {
            quarantine("文件为空");
            return java.util.Optional.empty();
        }

        if (parsed.formatVersion != FORMAT_VERSION) {
            // 版本不认识就不动文件：可能是更新版本的程序写的档，改名等于破坏用户数据。
            System.err.println("[TapMC] 存档格式版本 " + parsed.formatVersion
                    + " 无法识别（本程序支持 " + FORMAT_VERSION + "），保留原文件并新建世界：" + file);
            return java.util.Optional.empty();
        }

        if (parsed.width != expectedWidth || parsed.height != expectedHeight) {
            quarantine("尺寸 " + parsed.width + "x" + parsed.height
                    + " 与当前世界 " + expectedWidth + "x" + expectedHeight + " 不符");
            return java.util.Optional.empty();
        }

        try {
            WorldGrid world = WorldGrid.fromBlockNames(parsed.width, parsed.height, parsed.blocks);
            System.out.println("[TapMC] 已载入存档 " + file
                    + "（" + parsed.width + "x" + parsed.height + "，" + parsed.savedAt + "）");
            return java.util.Optional.of(world);
        } catch (IllegalArgumentException e) {
            quarantine(e.getMessage());
            return java.util.Optional.empty();
        }
    }

    @Override
    public void save(WorldGrid world) {
        SaveFile payload = new SaveFile(
                FORMAT_VERSION,
                world.getWidth(),
                world.getHeight(),
                Instant.now().toString(),
                world.toBlockNames());

        Path parent = file.getParent();
        Path temp = null;
        try {
            if (parent != null) {
                Files.createDirectories(parent);
            }
            // 临时文件必须与目标同目录，否则跨文件系统 rename 不原子。
            temp = Files.createTempFile(parent, file.getFileName().toString(), ".tmp");
            Files.writeString(temp, GSON.toJson(payload), StandardCharsets.UTF_8);
            moveAtomically(temp, file);
            temp = null;
        } catch (IOException e) {
            throw new StorageException("写入存档失败：" + file + "（" + e.getMessage() + "）", e);
        } finally {
            if (temp != null) {
                try {
                    Files.deleteIfExists(temp);
                } catch (IOException ignored) {
                    // 临时文件清不掉不影响正确性：名字带 .tmp，下次不会误当成存档读。
                }
            }
        }
    }

    private static void moveAtomically(Path from, Path to) throws IOException {
        try {
            Files.move(from, to, StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING);
        } catch (AtomicMoveNotSupportedException e) {
            // 某些网络盘不支持原子改名。退化成覆盖写：此时不再有原子保证，但仍然完成存档，
            // 比直接失败丢掉本次改动要好；打一行警告让运维知道这台机器的风险。
            System.err.println("[TapMC] 文件系统不支持原子改名，改用普通覆盖写入：" + to);
            Files.move(from, to, StandardCopyOption.REPLACE_EXISTING);
        }
    }

    /** 把读不动的存档改名留档，然后当作「没有存档」。 */
    private void quarantine(String reason) {
        Path backup = file.resolveSibling(
                file.getFileName() + ".corrupt-" + System.currentTimeMillis());
        try {
            Files.move(file, backup, StandardCopyOption.REPLACE_EXISTING);
            System.err.println("[TapMC] 存档不可用（" + reason + "），已另存为 " + backup + "，将新建世界");
        } catch (IOException e) {
            System.err.println("[TapMC] 存档不可用（" + reason + "），且改名失败（"
                    + e.getMessage() + "），将新建世界并覆盖 " + file);
        }
    }

    /**
     * 存档文件的形状。字段名即磁盘格式，改名等于改存档格式，必须同步 {@link #FORMAT_VERSION}。
     *
     * <p>用 record：只做数据搬运，不需要可变性。Gson 通过反射写 record 字段，
     * 因此字段名不能随便改（改了就读不了旧档）。
     */
    private record SaveFile(
            int formatVersion,
            int width,
            int height,
            String savedAt,
            List<String> blocks) {
    }
}
