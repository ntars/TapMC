package cn.ntars.tapmc.mod;

/**
 * {@link ModMetadata} 的现成实现。绝大多数模组直接用这个就够，不必自己写类。
 */
public record SimpleMetadata(String id, String name, String version) implements ModMetadata {
}
