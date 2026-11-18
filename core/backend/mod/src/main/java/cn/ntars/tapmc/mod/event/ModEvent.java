package cn.ntars.tapmc.mod.event;

/**
 * 事件基类。所有可被模组干预的动作都继承它。
 *
 * <p>「可取消」是模组生态的关键设计：模组不是只能旁观，它能拦住一个动作。
 * 取消后服务端不执行该动作，并向发起方返回 {@code CANCELLED_BY_MOD} 错误，
 * 让人知道「这次没生效，是模组拦的」，而不是静默失败。
 */
public abstract class ModEvent {

    private boolean cancelled;

    /**
     * 取消这个动作。
     *
     * <p>只有第一个调用者的理由会被记录，后续调用不再覆盖——避免多个模组
     * 同时拦截时，最终给出的理由取决于监听器注册顺序。
     */
    public void cancel(String reason) {
        if (!cancelled) {
            cancelled = true;
            this.reason = reason;
        }
    }

    private String reason = "";

    /** 是否已被取消。 */
    public boolean isCancelled() {
        return cancelled;
    }

    /** 取消理由。未被取消时为空串。 */
    public String getReason() {
        return reason;
    }
}
