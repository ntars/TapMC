package cn.ntars.tapmc.mod;

/**
 * 一个模组的入口。
 *
 * <p>加载流程由服务端负责：按 {@link #metadata()} 拿身份，调 {@link #onLoad(ModContext)}
 * 让模组注册自己想听的事件，然后进入事件循环。全程不允许模组自己起线程或直接
 * 碰网络——模组只能通过 {@link ModContext} 提供的口子操作世界，这样服务端才能
 * 保证「一次事件内世界状态不会被并发改乱」。
 *
 * <p>生命周期只有三步，没有 {@code onTick} 这类需要持续占用的钩子：
 * 骨架阶段的事件驱动足够，加持续钩子会把「什么时机跑什么」搞复杂。
 *
 * <pre>{@code
 * public final class SampleMod implements TapMcMod {
 *     public ModMetadata metadata() {
 *         return new SimpleMetadata("cn.ntars.tapmc.sample", "示例模组", "1.0.0");
 *     }
 *     public void onLoad(ModContext ctx) {
 *         ctx.onBlockPlace(e -> { ... });
 *     }
 * }
 * }</pre>
 */
public interface TapMcMod {

    /** 模组身份。加载器用它做去重，重名会被拒绝加载。 */
    ModMetadata metadata();

    /**
     * 加载时调用一次。在这里通过 {@code ctx} 注册事件监听。
     *
     * @param ctx 服务端提供的操作口子
     * @throws Exception 抛出即视为加载失败，服务端会把该模组标为 {@code FAILED}
     *                   并继续加载其他模组，不影响整体启动
     */
    void onLoad(ModContext ctx) throws Exception;
}
