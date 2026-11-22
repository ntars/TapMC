package cn.ntars.tapmc.server;

import cn.ntars.tapmc.core.ReloadableModContext;
import cn.ntars.tapmc.mod.ModContext;
import cn.ntars.tapmc.mod.TapMcMod;
import cn.ntars.tapmc.protocol.dto.ModInfo;

import java.io.IOException;
import java.net.URL;
import java.net.URLClassLoader;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.ServiceLoader;
import java.util.jar.JarEntry;
import java.util.jar.JarFile;
import java.util.stream.Stream;

/**
 * 从目录扫描 jar 并按 SPI 加载模组。
 *
 * <p>每个 jar 用独立的子 {@link URLClassLoader} 加载，父加载器只暴露 mod / protocol
 * 的 SPI 接口；子加载器优先加载自己的类。因此不同模组可以携带同名依赖而不互相踩，
 * 卸载时 {@code close()} 释放该加载器持有的文件句柄，目录里的 jar 就能被替换或删除。
 *
 * <p>加载隔离做在「类与监听器」层面，不是安全沙箱：模组代码仍在同一个 JVM 进程里，
 * 能访问网络与文件。只加载可信来源的 jar，这与 {@code system.mods} 的文档一致。
 */
public final class DirectoryModLoader {

    private static final String SPI = "META-INF/services/cn.ntars.tapmc.mod.TapMcMod";
    private static final cn.ntars.tapmc.protocol.dto.ModInfo.State STATE_ACTIVE =
            cn.ntars.tapmc.protocol.dto.ModInfo.State.ACTIVE;
    private static final cn.ntars.tapmc.protocol.dto.ModInfo.State STATE_FAILED =
            cn.ntars.tapmc.protocol.dto.ModInfo.State.FAILED;

    private final Path directory;
    private final ReloadableModContext context;
    private final List<ModAttachment> active = new ArrayList<>();
    private List<ModInfo> report = List.of();

    public DirectoryModLoader(Path directory, ReloadableModContext context) {
        this.directory = directory;
        this.context = context;
    }

    /**
     * 扫描并加载目录下全部 {@code *.jar}，替换当前一批模组。
     *
     * <p>单个 jar 解析失败（坏 jar、没有 SPI、构造函数抛异常）只记入报告，
     * 不中止其余 jar；这样放入一个坏模组不会让服务器起不来。
     */
    public List<ModInfo> loadAll() {
        unloadAll();

        List<ModInfo> next = new ArrayList<>();
        for (Path jar : listJars()) {
            next.add(loadJar(jar));
        }
        report = List.copyOf(next);
        return report;
    }

    /** 卸载全部模组，撤销监听器并释放 jar 文件句柄。 */
    public void unloadAll() {
        context.reset();
        for (ModAttachment attachment : active) {
            attachment.close();
        }
        active.clear();
        report = List.of();
    }

    /** 当前加载报告。 */
    public List<ModInfo> report() {
        return report;
    }

    private List<Path> listJars() {
        if (!Files.isDirectory(directory)) {
            return List.of();
        }
        try (Stream<Path> files = Files.list(directory)) {
            return files.filter(Files::isRegularFile)
                    .filter(p -> p.getFileName().toString().endsWith(".jar"))
                    .sorted(Comparator.comparing(p -> p.getFileName().toString()))
                    .toList();
        } catch (IOException e) {
            System.err.println("[TapMC] 扫描模组目录失败：" + directory + "：" + e.getMessage());
            return List.of();
        }
    }

    private ModInfo loadJar(Path jar) {
        String file = jar.getFileName().toString();
        if (!hasSpi(jar)) {
            return failed(file, file, "0.0.0", "jar 内缺少 " + SPI);
        }

        // child-first：子加载器优先自己的类，父加载器只提供 SPI 接口。
        // Java 9+ 的 URLClassLoader 已支持这个构造。
        ClassLoader parent = TapMcMod.class.getClassLoader();
        URLClassLoader loader = new URLClassLoader(
                new URL[]{toUrl(jar)}, parent) {
            @Override
            protected Class<?> loadClass(String name, boolean resolve) throws ClassNotFoundException {
                synchronized (getClassLoadingLock(name)) {
                    Class<?> found = findLoadedClass(name);
                    if (found == null && name.startsWith("cn.ntars.tapmc.")
                            && !name.startsWith("cn.ntars.tapmc.mod.")
                            && !name.startsWith("cn.ntars.tapmc.protocol.")) {
                        try {
                            found = findClass(name);
                        } catch (ClassNotFoundException ignored) {
                            // 模组没自带这个类，交给父加载器。
                        }
                    }
                    if (found == null) {
                        found = super.loadClass(name, false);
                    }
                    if (resolve) {
                        resolveClass(found);
                    }
                    return found;
                }
            }
        };

        try {
            ServiceLoader<TapMcMod> services = ServiceLoader.load(TapMcMod.class, loader);
            List<ModInfo> loaded = new ArrayList<>();
            for (TapMcMod mod : services) {
                loaded.add(activate(mod, loader, file));
            }
            if (loaded.isEmpty()) {
                loader.close();
                return failed(file, file, "0.0.0", "SPI 文件为空，未提供 TapMcMod 实现");
            }
            return loaded.getFirst();
        } catch (Exception | LinkageError e) {
            closeQuietly(loader);
            return failed(file, file, "0.0.0", describe(e));
        }
    }

    private ModInfo activate(TapMcMod mod, URLClassLoader loader, String file) {
        String id;
        String name;
        String version;
        try {
            var meta = mod.metadata();
            if (meta == null || meta.id() == null || meta.id().isBlank()) {
                throw new IllegalStateException("模组 id 为空");
            }
            id = meta.id();
            name = meta.name();
            version = meta.version();
            mod.onLoad(context);
        } catch (Exception | LinkageError e) {
            closeQuietly(loader);
            return failed(file, file, "0.0.0", describe(e));
        }
        active.add(new ModAttachment(id, loader));
        return new ModInfo(id, name, version, STATE_ACTIVE, "");
    }

    private boolean hasSpi(Path jar) {
        try (JarFile archive = new JarFile(jar.toFile())) {
            JarEntry entry = archive.getJarEntry(SPI);
            return entry != null && !entry.isDirectory();
        } catch (IOException e) {
            return false;
        }
    }

    private static URL toUrl(Path jar) {
        try {
            return jar.toAbsolutePath().normalize().toUri().toURL();
        } catch (IOException e) {
            throw new IllegalStateException("模组路径无法转换为 URL：" + jar, e);
        }
    }

    private static ModInfo failed(String id, String name, String version, String reason) {
        return new ModInfo(id, name, version, STATE_FAILED, reason);
    }

    private static String describe(Throwable e) {
        String msg = e.getMessage();
        return e.getClass().getSimpleName() + (msg == null || msg.isBlank() ? "" : "：" + msg);
    }

    private static void closeQuietly(URLClassLoader loader) {
        try {
            loader.close();
        } catch (IOException ignored) {
            // 关闭失败只影响文件句柄，模组已经判为失败，不再叠加错误。
        }
    }

    private record ModAttachment(String id, URLClassLoader loader) {
        void close() {
            closeQuietly(loader);
        }
    }
}
