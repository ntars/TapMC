package cn.ntars.tapmc.core.storage;

/**
 * 存档读写失败。
 *
 * <p>用「非受检异常」而不是 {@code IOException}，是为了让 {@link WorldStore}
 * 的实现者不必在每个调用点套 try-catch——存档失败通常是磁盘满、权限不足这类
 * 环境问题，调用方除了打日志与提示用户之外也做不了别的。真正需要区分成败的地方
 * （比如服务端退出存档）自己 catch 就好。
 */
public class StorageException extends RuntimeException {

    public StorageException(String message) {
        super(message);
    }

    public StorageException(String message, Throwable cause) {
        super(message, cause);
    }
}
