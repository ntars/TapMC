package cn.ntars.tapmc.server.instance;

import cn.ntars.tapmc.core.GameEngine;
import cn.ntars.tapmc.protocol.dto.WorldSnapshot;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Optional;

public class Instance {
    
    private final String name;
    private final Path directory;
    private WorldSnapshot world;
    
    public Instance(String name, Path directory) {
        this.name = name;
        this.directory = directory;
        
        Path worldFile = directory.resolve("world.json");
        if (Files.exists(worldFile)) {
            try {
                String content = new String(Files.readAllBytes(worldFile));
                this.world = loadWorldFromJson(content);
            } catch (IOException e) {
                this.world = createEmptyWorld();
            }
        } else {
            this.world = createEmptyWorld();
            saveWorld();
        }
    }
    
    public String getName() {
        return name;
    }
    
    public Path getDirectory() {
        return directory;
    }
    
    public Path getPath() {
        return directory;
    }
    
    public WorldSnapshot getWorld() {
        return world;
    }
    
    public void saveWorld() throws IOException {
        Path worldFile = directory.resolve("world.json");
        String json = serializeWorld(world);
        Files.write(worldFile, json.getBytes());
    }
    
    private WorldSnapshot createEmptyWorld() {
        return new WorldSnapshot(24, 16, new java.util.ArrayList<>());
    }
    
    private WorldSnapshot loadWorldFromJson(String content) {
        return new WorldSnapshot(24, 16, new java.util.ArrayList<>());
    }
    
    private String serializeWorld(WorldSnapshot world) {
        return "{ \"width\": " + world.width() 
            + ", \"height\": " + world.height()
            + ", \"blocks\": [] }";
    }
    
    public void loadMods(Path modsDir) throws IOException {
        if (!Files.exists(modsDir)) {
            Files.createDirectories(modsDir);
        }
    }
    
    public void unloadMods(Path modsDir) throws IOException {
    }
}
