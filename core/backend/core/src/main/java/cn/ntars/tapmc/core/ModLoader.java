package cn.ntars.tapmc.core;

import cn.ntars.tapmc.mod.ModMetadata;
import cn.ntars.tapmc.mod.TapMcMod;
import cn.ntars.tapmc.protocol.dto.ModInfo;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 模组加载器。骨架阶段只支持「在代码里注册的模组」，不支持从 jar 动态加载——
 * 动态加载需要类加载器隔离与安全沙箱，属于第二阶段的事，先把接口跑通。
 *
 * <p><b>失败隔离</b>：单个模组加载抛异常不影响其他模组，失败的那个被标为
 * {@code FAILED} 并记下原因，前端可见。这比「一个坏模组拖垮全服」有用得多。
 *
 * <p><b>去重</b>：同 id 的模组只加载第一个，后续的标为 {@code DISABLED} 并给出原因。
 */
public final class ModLoader {

    private final GameEngine engine;
    private final Map<String, TapMcMod> loaded = new LinkedHashMap<>();
    private final List<ModInfo> report = new ArrayList<>();

    public ModLoader(GameEngine engine) {
        this.engine = engine;
    }

    /**
     * 按给定顺序加载模组。
     *
     * <p>顺序有意义：先加载的模组先注册监听，事件分发时也先被调用，
     * 因此先加载的模组可以「抢在」后面的模组之前取消事件。
     */
    public void loadAll(List<TapMcMod> mods) {
        for (TapMcMod mod : mods) {
            load(mod);
        }
    }

    /** 加载单个模组，把结果记进报告。 */
    public void load(TapMcMod mod) {
        ModMetadata meta;
        try {
            meta = mod.metadata();
        } catch (RuntimeException e) {
            // 连身份都拿不到，无法登记，只能丢弃。
            report.add(new ModInfo("<unknown>", "<unknown>", "0.0.0",
                    ModInfo.State.FAILED, "读取元信息失败：" + describe(e)));
            return;
        }

        if (meta == null || meta.id() == null || meta.id().isBlank()) {
            report.add(new ModInfo("<blank>", "<blank>", "0.0.0",
                    ModInfo.State.FAILED, "模组 id 为空"));
            return;
        }

        if (loaded.containsKey(meta.id())) {
            report.add(new ModInfo(meta.id(), meta.name(), meta.version(),
                    ModInfo.State.DISABLED, "已存在同 id 模组，此前加载的版本生效"));
            return;
        }

        try {
            mod.onLoad(engine);
            loaded.put(meta.id(), mod);
            report.add(new ModInfo(meta.id(), meta.name(), meta.version(),
                    ModInfo.State.ACTIVE, ""));
        } catch (Exception e) {
            report.add(new ModInfo(meta.id(), meta.name(), meta.version(),
                    ModInfo.State.FAILED, "加载异常：" + describe(e)));
        }
    }

    /** 加载报告，按加载顺序排列。 */
    public List<ModInfo> report() {
        return List.copyOf(report);
    }

    /** 已成功加载的模组数量。 */
    public int loadedCount() {
        return loaded.size();
    }

    private static String describe(Exception e) {
        String msg = e.getMessage();
        return e.getClass().getSimpleName() + (msg == null || msg.isBlank() ? "" : "：" + msg);
    }
}
