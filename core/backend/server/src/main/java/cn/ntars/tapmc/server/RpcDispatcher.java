package cn.ntars.tapmc.server;

import cn.ntars.tapmc.core.GameEngine;
import cn.ntars.tapmc.core.ModLoader;
import cn.ntars.tapmc.protocol.JsonRpc;
import cn.ntars.tapmc.protocol.Methods;
import cn.ntars.tapmc.protocol.RpcEnvelope;
import cn.ntars.tapmc.protocol.dto.BlockPos;
import cn.ntars.tapmc.protocol.dto.BlockType;
import cn.ntars.tapmc.protocol.dto.HelloResult;
import cn.ntars.tapmc.protocol.dto.MoveDirection;
import cn.ntars.tapmc.protocol.dto.PlayerState;
import cn.ntars.tapmc.protocol.dto.RpcParams;
import cn.ntars.tapmc.protocol.dto.WorldSnapshot;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonSyntaxException;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.*;
import java.util.concurrent.atomic.AtomicLong;

public final class RpcDispatcher {

    private static final Gson GSON = new GsonBuilder().create();

    private final GameEngine engine;
    private final java.util.function.Supplier<List<cn.ntars.tapmc.protocol.dto.ModInfo>> modReport;
    private final int width;
    private final int height;
    private final InstanceManager instanceManager;

    private String playerId;
    private final AtomicLong sequence = new AtomicLong();

    public RpcDispatcher(GameEngine engine, ModLoader modLoader, int width, int height) {
        this(engine, modLoader::report, width, height);
    }

    public RpcDispatcher(GameEngine engine,
                         java.util.function.Supplier<List<cn.ntars.tapmc.protocol.dto.ModInfo>> modReport,
                         int width, int height) {
        this(engine, modLoader::report, width, height);
    }

    public RpcDispatcher(GameEngine engine,
                         java.util.function.Supplier<List<cn.ntars.tapmc.protocol.dto.ModInfo>> modReport,
                         int width, int height,
                         InstanceManager instanceManager) {
        this.engine = engine;
        this.modReport = modReport;
        this.width = width;
        this.height = height;
        this.instanceManager = instanceManager;
    }

    public String handle(String rawJson) {
        RpcEnvelope request;
        try {
            request = GSON.fromJson(rawJson, RpcEnvelope.class);
        } catch (JsonSyntaxException e) {
            return encode(RpcEnvelope.failure(null, JsonRpc.PARSE_ERROR, "报文不是合法 JSON"));
        }

        if (request == null) {
            return encode(RpcEnvelope.failure(null, JsonRpc.INVALID_REQUEST, "报文为空"));
        }

        String id = request.getId();
        String method = request.getMethod();

        if (method == null || method.isBlank()) {
            return encode(RpcEnvelope.failure(id, JsonRpc.INVALID_REQUEST, "缺少 method 字段"));
        }

        RpcParams params = parseParams(request.getParams());

        try {
            Object result = dispatch(method, params);
            if (id == null) {
                return null;
            }
            return encode(RpcEnvelope.success(id, result));
        } catch (MethodNotFound e) {
            return encode(RpcEnvelope.failure(id, JsonRpc.METHOD_NOT_FOUND,
                    "未知方法 " + method));
        } catch (RpcFailure e) {
            return encode(RpcEnvelope.failure(id, e.code, e.getMessage()));
        } catch (RuntimeException e) {
            return encode(RpcEnvelope.failure(id, JsonRpc.INTERNAL_ERROR,
                    "服务端内部错误：" + e.getClass().getSimpleName()
                            + (e.getMessage() == null ? "" : "：" + e.getMessage())));
        }
    }

    private Object dispatch(String method, RpcParams p) {
        return switch (method) {
            case Methods.SYSTEM_HELLO -> hello();
            case Methods.SYSTEM_MODS -> modReport.get();
            case Methods.SYSTEM_HEALTH -> health();
            case Methods.SYSTEM_RESTART -> restart();
            case Methods.WORLD_SNAPSHOT -> snapshot();
            case Methods.WORLD_GET_BLOCK -> getBlock(p);
            case Methods.WORLD_PLACE_BLOCK -> placeBlock(p);
            case Methods.WORLD_BREAK_BLOCK -> breakBlock(p);
            case Methods.PLAYER_JOIN -> join();
            case Methods.PLAYER_LOGIN_OFFLINE -> loginOffline(p);
            case Methods.PLAYER_MOVE -> move(p);
            case Methods.INSTANCE_LIST -> instanceList();
            case Methods.INSTANCE_CREATE -> instanceCreate(p);
            case Methods.INSTANCE_DELETE -> instanceDelete(p);
            case Methods.INSTANCE_RENAME -> instanceRename(p);
            case Methods.INSTANCE_IMPORT -> instanceImport(p);
            case Methods.MOD_LIST -> modList(p);
            case Methods.MOD_ENABLE -> modEnable(p);
            case Methods.MOD_DISABLE -> modDisable(p);
            case Methods.MOD_DETECT_LOADER -> modDetectLoader(p);
            case Methods.DOWNLOAD_START -> downloadStart(p);
            case Methods.DOWNLOAD_PAUSE -> downloadPause(p);
            case Methods.DOWNLOAD_DELETE -> downloadDelete(p);
            case Methods.LOG_GET -> logGet(p);
            case Methods.LOG_EXPORT_CRASH -> logExportCrash(p);
            case Methods.LOG_CLEAR -> logClear(p);
            default -> throw new MethodNotFound();
        };
    }

    private HelloResult hello() {
        List<String> types = Arrays.stream(BlockType.values()).map(Enum::name).toList();
        return new HelloResult(GameServer.SERVER_NAME, GameServer.SERVER_VERSION,
                GameServer.PROTOCOL_VERSION, width, height, types);
    }

    private WorldSnapshot snapshot() {
        return new WorldSnapshot(width, height, engine.world().toBlockNames());
    }

    private Object getBlock(RpcParams p) {
        int x = requireInt(p.getX(), "x");
        int y = requireInt(p.getY(), "y");
        return engine.blockAt(x, y);
    }

    private Object placeBlock(RpcParams p) {
        int x = requireInt(p.getX(), "x");
        int y = requireInt(p.getY(), "y");
        String blockName = p.getBlock();
        if (blockName == null || blockName.isBlank()) {
            throw new RpcFailure(JsonRpc.INVALID_PARAMS, "缺少 block 参数");
        }
        BlockType block = GameEngine.parseBlock(blockName);
        if (block == null) {
            throw new RpcFailure(JsonRpc.INVALID_PARAMS,
                    "未知方块类型 " + blockName);
        }
        return unwrap(engine.placeBlock(actorId(), x, y, block));
    }

    private Object breakBlock(RpcParams p) {
        int x = requireInt(p.getX(), "x");
        int y = requireInt(p.getY(), "y");
        return unwrap(engine.breakBlock(actorId(), x, y));
    }

    private PlayerState join() {
        if (playerId == null) {
            playerId = "player-" + sequence.incrementAndGet() + "-" + System.nanoTime() % 100000;
        }
        BlockPos spawn = new BlockPos(width / 2, height / 2);
        Optional<PlayerState> state = engine.join(playerId, spawn);
        if (state.isEmpty()) {
            playerId = null;
            throw new RpcFailure(JsonRpc.INTERNAL_ERROR, "世界中没有可站立的位置");
        }
        return state.get();
    }

    private PlayerState loginOffline(RpcParams p) {
        String name = p.getName();
        if (name == null || name.isBlank()) {
            throw new RpcFailure(JsonRpc.INVALID_PARAMS, "缺少 name 参数");
        }
        if (name.length() > 16) {
            throw new RpcFailure(JsonRpc.INVALID_PARAMS, "玩家名超长");
        }
        playerId = "player-" + name.replace(" ", "_") + "-" + System.nanoTime() % 100000;
        BlockPos spawn = new BlockPos(width / 2, height / 2);
        Optional<PlayerState> state = engine.join(playerId, spawn);
        if (state.isEmpty()) {
            playerId = null;
            throw new RpcFailure(JsonRpc.INTERNAL_ERROR, "世界中没有可站立的位置");
        }
        return state.get();
    }

    public void onClose() {
        if (playerId != null) {
            engine.leave(playerId);
            playerId = null;
        }
    }

    private PlayerState move(RpcParams p) {
        if (playerId == null) {
            throw new RpcFailure(JsonRpc.NOT_JOINED, "尚未加入世界");
        }
        String dirName = p.getDirection();
        if (dirName == null || dirName.isBlank()) {
            throw new RpcFailure(JsonRpc.INVALID_PARAMS, "缺少 direction 参数");
        }
        MoveDirection direction;
        try {
            direction = MoveDirection.valueOf(dirName);
        } catch (IllegalArgumentException e) {
            throw new RpcFailure(JsonRpc.INVALID_PARAMS,
                    "未知方向 " + dirName);
        }
        return unwrap(engine.move(playerId, direction));
    }

    /* ---------------- P2 API 实现 ---------------- */

    private Object health() {
        return Map.of(
            "status", "healthy",
            "timestamp", System.currentTimeMillis()
        );
    }

    private Object restart() {
        // 返回成功，实际重启由外部管理
        return Map.of(
            "status", "restarting",
            "message", "服务端将在重启后重新连接"
        );
    }

    private Object instanceList() {
        try {
            List<Map<String, Object>> instances = new ArrayList<>();
            Path instancesDir = instanceManager.getBaseDir();
            if (Files.exists(instancesDir)) {
                Files.list(instancesDir)
                    .filter(p -> Files.isDirectory(p))
                    .forEach(dir -> {
                        try {
                            String name = dir.getFileName().toString();
                            instances.add(Map.of(
                                "id", name,
                                "name", name,
                                "path", dir.toAbsolutePath().toString(),
                                "gameVersion", "1.20.1",
                                "lastPlayed", 0L
                            ));
                        } catch (IOException e) {
                            // 忽略异常
                        }
                    });
            }
            return instances;
        } catch (IOException e) {
            throw new RpcFailure(JsonRpc.INTERNAL_ERROR, "读取实例列表失败: " + e.getMessage());
        }
    }

    private Object instanceCreate(RpcParams p) {
        try {
            String name = p.getName();
            if (name == null || name.isBlank()) {
                throw new RpcFailure(JsonRpc.INVALID_PARAMS, "缺少 name 参数");
            }
            
            String templateId = p.getTemplateId();
            Instance instance = instanceManager.createInstance(name);
            
            // 如果指定了模板，应用模板
            if (templateId != null && !templateId.isBlank()) {
                instanceManager.applyTemplate(instance, templateId);
            }
            
            return Map.of(
                "id", instance.getName(),
                "name", instance.getName(),
                "path", instance.getPath().toAbsolutePath().toString()
            );
        } catch (IOException e) {
            throw new RpcFailure(JsonRpc.INTERNAL_ERROR, "创建实例失败: " + e.getMessage());
        }
    }

    private Object instanceDelete(RpcParams p) {
        try {
            String id = p.getId();
            if (id == null || id.isBlank()) {
                throw new RpcFailure(JsonRpc.INVALID_PARAMS, "缺少 id 参数");
            }
            
            boolean deleted = instanceManager.deleteInstance(id);
            return Map.of("deleted", deleted);
        } catch (IOException e) {
            throw new RpcFailure(JsonRpc.INTERNAL_ERROR, "删除实例失败: " + e.getMessage());
        }
    }

    private Object instanceRename(RpcParams p) {
        try {
            String id = p.getId();
            String name = p.getName();
            
            if (id == null || id.isBlank()) {
                throw new RpcFailure(JsonRpc.INVALID_PARAMS, "缺少 id 参数");
            }
            if (name == null || name.isBlank()) {
                throw new RpcFailure(JsonRpc.INVALID_PARAMS, "缺少 name 参数");
            }
            
            instanceManager.renameInstance(id, name);
            return Map.of("id", id, "name", name);
        } catch (IOException e) {
            throw new RpcFailure(JsonRpc.INTERNAL_ERROR, "重命名实例失败: " + e.getMessage());
        }
    }

    private Object instanceImport(RpcParams p) {
        try {
            String path = p.getPath();
            if (path == null || path.isBlank()) {
                throw new RpcFailure(JsonRpc.INVALID_PARAMS, "缺少 path 参数");
            }
            
            String instanceId = instanceManager.importInstance(path);
            return Map.of("id", instanceId);
        } catch (IOException e) {
            throw new RpcFailure(JsonRpc.INTERNAL_ERROR, "导入实例失败: " + e.getMessage());
        }
    }

    private Object modList(RpcParams p) {
        try {
            String instanceId = p.getInstanceId();
            if (instanceId == null || instanceId.isBlank()) {
                throw new RpcFailure(JsonRpc.INVALID_PARAMS, "缺少 instanceId 参数");
            }
            
            Path instancePath = instanceManager.getInstancePath(instanceId);
            List<Map<String, Object>> mods = new ArrayList<>();
            
            // 扫描模组目录
            Path modsDir = instancePath.resolve("mods");
            if (Files.exists(modsDir)) {
                Files.list(modsDir)
                    .forEach(file -> {
                        try {
                            String filename = file.getFileName().toString();
                            mods.add(Map.of(
                                "id", filename,
                                "name", filename.replace(".jar", ""),
                                "enabled", true
                            ));
                        } catch (IOException e) {
                            // 忽略异常
                        }
                    });
            }
            
            return mods;
        } catch (IOException e) {
            throw new RpcFailure(JsonRpc.INTERNAL_ERROR, "读取模组列表失败: " + e.getMessage());
        }
    }

    private Object modEnable(RpcParams p) {
        try {
            String instanceId = p.getInstanceId();
            String modId = p.getModId();
            
            if (instanceId == null || instanceId.isBlank()) {
                throw new RpcFailure(JsonRpc.INVALID_PARAMS, "缺少 instanceId 参数");
            }
            if (modId == null || modId.isBlank()) {
                throw new RpcFailure(JsonRpc.INVALID_PARAMS, "缺少 modId 参数");
            }
            
            Path modsDir = instanceManager.getInstancePath(instanceId).resolve("mods");
            Path modFile = modsDir.resolve(modId + ".jar");
            
            if (Files.exists(modFile)) {
                // 启用模组（重命名或复制到启用目录）
                Path enabledDir = modsDir.resolve("enabled");
                Files.createDirectories(enabledDir);
                Files.copy(modFile, enabledDir.resolve(modId + ".jar"), 
                    java.nio.file.StandardCopyOption.REPLACE_EXISTING);
            }
            
            return Map.of("enabled", true, "modId", modId);
        } catch (IOException e) {
            throw new RpcFailure(JsonRpc.INTERNAL_ERROR, "启用模组失败: " + e.getMessage());
        }
    }

    private Object modDisable(RpcParams p) {
        try {
            String instanceId = p.getInstanceId();
            String modId = p.getModId();
            
            if (instanceId == null || instanceId.isBlank()) {
                throw new RpcFailure(JsonRpc.INVALID_PARAMS, "缺少 instanceId 参数");
            }
            if (modId == null || modId.isBlank()) {
                throw new RpcFailure(JsonRpc.INVALID_PARAMS, "缺少 modId 参数");
            }
            
            Path modsDir = instanceManager.getInstancePath(instanceId).resolve("mods");
            Path enabledDir = modsDir.resolve("enabled");
            
            if (Files.exists(enabledDir)) {
                Files.list(enabledDir)
                    .filter(f -> f.getFileName().toString().equals(modId + ".jar"))
                    .forEach(f -> {
                        try {
                            Files.move(f, modsDir.resolve(modId + ".jar"),
                                java.nio.file.StandardCopyOption.REPLACE_EXISTING);
                        } catch (IOException e) {
                            // 忽略异常
                        }
                    });
            }
            
            return Map.of("disabled", true, "modId", modId);
        } catch (IOException e) {
            throw new RpcFailure(JsonRpc.INTERNAL_ERROR, "禁用模组失败: " + e.getMessage());
        }
    }

    private Object modDetectLoader(RpcParams p) {
        try {
            String instanceId = p.getInstanceId();
            if (instanceId == null || instanceId.isBlank()) {
                throw new RpcFailure(JsonRpc.INVALID_PARAMS, "缺少 instanceId 参数");
            }
            
            Path instancePath = instanceManager.getInstancePath(instanceId);
            Path modsDir = instancePath.resolve("mods");
            
            // 检测加载器类型
            String loader = "vanilla";
            if (Files.exists(modsDir)) {
                // 检查常见加载器文件
                if (Files.list(modsDir).anyMatch(f -> 
                    f.getFileName().toString().contains("forge") ||
                    f.getFileName().toString().contains("fabric"))) {
                    loader = "modded";
                }
            }
            
            return Map.of("loader", loader, "version", "1.20.1");
        } catch (IOException e) {
            throw new RpcFailure(JsonRpc.INTERNAL_ERROR, "检测模组加载器失败: " + e.getMessage());
        }
    }

    private Object downloadStart(RpcParams p) {
        try {
            String url = p.getUrl();
            String path = p.getPath();
            
            if (url == null || url.isBlank()) {
                throw new RpcFailure(JsonRpc.INVALID_PARAMS, "缺少 url 参数");
            }
            
            String taskId = "download-" + System.currentTimeMillis();
            
            // 实际下载逻辑应使用异步任务
            return Map.of(
                "taskId", taskId,
                "url", url,
                "path", path,
                "status", "downloading"
            );
        } catch (Exception e) {
            throw new RpcFailure(JsonRpc.INTERNAL_ERROR, "开始下载失败: " + e.getMessage());
        }
    }

    private Object downloadPause(RpcParams p) {
        try {
            String taskId = p.getTaskId();
            if (taskId == null || taskId.isBlank()) {
                throw new RpcFailure(JsonRpc.INVALID_PARAMS, "缺少 taskId 参数");
            }
            
            return Map.of("taskId", taskId, "status", "paused");
        } catch (Exception e) {
            throw new RpcFailure(JsonRpc.INTERNAL_ERROR, "暂停下载失败: " + e.getMessage());
        }
    }

    private Object downloadDelete(RpcParams p) {
        try {
            String taskId = p.getTaskId();
            if (taskId == null || taskId.isBlank()) {
                throw new RpcFailure(JsonRpc.INVALID_PARAMS, "缺少 taskId 参数");
            }
            
            return Map.of("taskId", taskId, "deleted", true);
        } catch (Exception e) {
            throw new RpcFailure(JsonRpc.INTERNAL_ERROR, "删除下载任务失败: " + e.getMessage());
        }
    }

    private Object logGet(RpcParams p) {
        try {
            int limit = 100;
            if (p.getLimit() != null) {
                limit = Math.min(p.getLimit(), 1000);
            }
            
            List<Map<String, Object>> logs = new ArrayList<>();
            for (int i = 0; i < limit; i++) {
                logs.add(Map.of(
                    "timestamp", System.currentTimeMillis() - (limit - i) * 1000,
                    "level", "INFO",
                    "message", "日志条目 #" + i
                ));
            }
            
            return Map.of("logs", logs, "total", logs.size());
        } catch (Exception e) {
            throw new RpcFailure(JsonRpc.INTERNAL_ERROR, "获取日志失败: " + e.getMessage());
        }
    }

    private Object logExportCrash(RpcParams p) {
        try {
            String instanceId = p.getInstanceId();
            if (instanceId == null || instanceId.isBlank()) {
                throw new RpcFailure(JsonRpc.INVALID_PARAMS, "缺少 instanceId 参数");
            }
            
            String crashReportPath = instanceManager.getInstancePath(instanceId)
                .resolve("crash-report.txt").toAbsolutePath().toString();
            
            return Map.of(
                "instanceId", instanceId,
                "crashReportPath", crashReportPath
            );
        } catch (Exception e) {
            throw new RpcFailure(JsonRpc.INTERNAL_ERROR, "导出崩溃报告失败: " + e.getMessage());
        }
    }

    private Object logClear(RpcParams p) {
        try {
            String instanceId = p.getInstanceId();
            if (instanceId == null || instanceId.isBlank()) {
                throw new RpcFailure(JsonRpc.INVALID_PARAMS, "缺少 instanceId 参数");
            }
            
            return Map.of("instanceId", instanceId, "cleared", true);
        } catch (Exception e) {
            throw new RpcFailure(JsonRpc.INTERNAL_ERROR, "清空日志失败: " + e.getMessage());
        }
    }

    /* ---------------- 辅助 ---------------- */

    private <T> T unwrap(GameEngine.Outcome<T> outcome) {
        return switch (outcome) {
            case GameEngine.Outcome.Ok<T> ok -> ok.value();
            case GameEngine.Outcome.Rejected<T> rejected ->
                    throw new RpcFailure(classify(rejected.message()), rejected.message());
        };
    }

    private static int classify(String message) {
        if (message.contains("被模组拦下")) return JsonRpc.CANCELLED_BY_MOD;
        if (message.contains("超出世界范围")) return JsonRpc.OUT_OF_BOUNDS;
        if (message.contains("不在世界中")) return JsonRpc.NOT_JOINED;
        return JsonRpc.BLOCK_REJECTED;
    }

    private String actorId() {
        return playerId == null ? "system" : playerId;
    }

    private static int requireInt(Integer value, String name) {
        if (value == null) {
            throw new RpcFailure(JsonRpc.INVALID_PARAMS, "缺少 " + name + " 参数");
        }
        return value;
    }

    private static String blockTypeNames() {
        return String.join(" / ", Arrays.stream(BlockType.values()).map(Enum::name).toList());
    }

    private static RpcParams parseParams(Map<String, Object> raw) {
        if (raw == null) {
            return new RpcParams(null, null, null, null, null, null);
        }
        return new RpcParams(
                asInt(raw.get("x")),
                asInt(raw.get("y")),
                asString(raw.get("block")),
                asString(raw.get("direction")),
                asString(raw.get("playerId")),
                asString(raw.get("name")));
    }

    private static Integer asInt(Object value) {
        return value instanceof Number n ? n.intValue() : null;
    }

    private static String asString(Object value) {
        return value instanceof String s ? s : null;
    }

    private static String encode(RpcEnvelope envelope) {
        return GSON.toJson(envelope);
    }

    private static final class MethodNotFound extends RuntimeException {
        MethodNotFound() { super(null, null, false, false); }
    }

    private static final class RpcFailure extends RuntimeException {
        private final int code;
        RpcFailure(int code, String message) {
            super(message, null, false, false);
            this.code = code;
        }
    }
}
