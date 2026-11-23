package cn.ntars.tapmc.server.instance;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

public class InstanceManager {
    
    private static final String INSTANCES_DIR = "instances";
    private static final String WORLD_FILE = "world.json";
    
    private final Path baseDir;
    private final Map<String, Instance> loadedInstances;
    
    public InstanceManager(Path baseDir) {
        this.baseDir = baseDir.resolve(INSTANCES_DIR);
        this.loadedInstances = new ConcurrentHashMap<>();
    }
    
    public Path getBaseDir() {
        return baseDir;
    }
    
    public Instance createInstance(String name) throws IOException {
        if (name == null || name.isBlank()) {
            throw new IllegalArgumentException("实例名不能为空");
        }
        
        Path instanceDir = getInstancePath(name);
        if (Files.exists(instanceDir)) {
            throw new IllegalArgumentException("实例 " + name + " 已存在");
        }
        
        Files.createDirectories(instanceDir);
        Instance instance = new Instance(name, instanceDir);
        loadedInstances.put(name, instance);
        
        instance.saveWorld();
        
        return instance;
    }
    
    public boolean deleteInstance(String name) throws IOException {
        Instance instance = loadedInstances.remove(name);
        if (instance == null) {
            Path instanceDir = getInstancePath(name);
            if (!Files.exists(instanceDir)) {
                return false;
            }
            Files.deleteIfExists(instanceDir);
            return true;
        }
        
        Path instanceDir = getInstancePath(name);
        if (Files.exists(instanceDir)) {
            Files.walk(instanceDir)
                .sorted(Comparator.reverseOrder())
                .map(Path::toAbsolutePath)
                .forEach(p -> {
                    try {
                        Files.deleteIfExists(p);
                    } catch (IOException e) {
                    }
                });
        }
        
        return true;
    }
    
    public List<Instance> listInstances() {
        List<Instance> instances = new ArrayList<>();
        
        if (!Files.exists(baseDir)) {
            return instances;
        }
        
        try {
            Files.list(baseDir)
                .filter(Files::isDirectory)
                .forEach(dir -> {
                    String name = dir.getFileName().toString();
                    instances.add(new Instance(name, dir));
                });
        } catch (IOException e) {
        }
        
        return instances;
    }
    
    public Optional<Instance> loadInstance(String name) {
        if (loadedInstances.containsKey(name)) {
            return Optional.of(loadedInstances.get(name));
        }
        
        Path instanceDir = getInstancePath(name);
        if (!Files.exists(instanceDir)) {
            return Optional.empty();
        }
        
        Instance instance = new Instance(name, instanceDir);
        loadedInstances.put(name, instance);
        return Optional.of(instance);
    }
    
    public void renameInstance(String oldName, String newName) throws IOException {
        if (oldName == null || oldName.isBlank()) {
            throw new IllegalArgumentException("旧实例名不能为空");
        }
        if (newName == null || newName.isBlank()) {
            throw new IllegalArgumentException("新实例名不能为空");
        }
        
        Path oldPath = getInstancePath(oldName);
        if (!Files.exists(oldPath)) {
            throw new IllegalArgumentException("实例 " + oldName + " 不存在");
        }
        
        Path newPath = getInstancePath(newName);
        if (Files.exists(newPath)) {
            throw new IllegalArgumentException("实例 " + newName + " 已存在");
        }
        
        Files.move(oldPath, newPath);
        
        Instance instance = loadedInstances.remove(oldName);
        if (instance != null) {
            loadedInstances.put(newName, instance);
        }
    }
    
    public void applyTemplate(Instance instance, String templateId) throws IOException {
    }
    
    public String importInstance(String path) throws IOException {
        Path zipPath = Path.of(path);
        if (!Files.exists(zipPath)) {
            throw new IllegalArgumentException("文件不存在: " + path);
        }
        
        String instanceId = "import-" + System.currentTimeMillis();
        Path instanceDir = getInstancePath(instanceId);
        Files.createDirectories(instanceDir);
        
        System.out.println("导入实例: " + path + " -> " + instanceDir);
        
        return instanceId;
    }
    
    public Path getInstancePath(String name) {
        return baseDir.resolve(name);
    }
}
