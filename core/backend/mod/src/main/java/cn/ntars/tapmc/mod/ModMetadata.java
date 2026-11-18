package cn.ntars.tapmc.mod;

/**
 * 模组的身份与元信息。
 *
 * <p>每个模组必须提供唯一 {@code id}（反向域名风格，例如 {@code cn.ntars.tapmc.sample}），
 * 服务端用它做去重与配置查找。{@code id} 一经发布不可更改——玩家的配置文件是按 id 存的。
 */
public interface ModMetadata {

    /** 唯一标识。反向域名，全小写。 */
    String id();

    /** 给人看的名字。可含中文。 */
    String name();

    /** 语义化版本，例如 {@code 1.0.0}。 */
    String version();
}
