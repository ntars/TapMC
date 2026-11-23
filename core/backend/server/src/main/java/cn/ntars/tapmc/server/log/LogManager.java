package cn.ntars.tapmc.server.log;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Pattern;

/**
 * 日志管理器。提供日志高亮、崩溃报告导出等功能。
 */
public class LogManager {
    
    private static final DateTimeFormatter FORMATTER = 
        DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");
    
    /** 日志颜色标记（ANSI） */
    private static final String RESET = "\u001B[0m";
    private static final String ERROR_COLOR = "\u001B[31;1m";  // 红色高亮
    private static final String WARN_COLOR = "\u001B[33;1m";   // 黄色高亮
    private static final String INFO_COLOR = "\u001B[32;1m";   // 绿色高亮
    private static final String DEBUG_COLOR = "\u001B[36;1m";  // 青色高亮
    
    private final Path logFile;
    private List<LogEntry> cachedLogs;
    
    public LogManager(Path logDirectory) {
        this.logFile = logDirectory.resolve("tapmc.log");
        this.cachedLogs = new ArrayList<>();
    }
    
    /**
     * 读取日志并返回带高亮的版本
     */
    public List<String> readHighlightedLogs(int limit) {
        if (!Files.exists(logFile)) {
            return List.of();
        }
        
        try {
            List<String> lines = Files.readAllLines(logFile);
            if (lines.isEmpty()) {
                return List.of();
            }
            
            // 返回最近 limit 行
            int start = Math.max(0, lines.size() - limit);
            List<String> recentLines = lines.subList(start, lines.size());
            
            // 添加 ANSI 高亮标记
            return recentLines.stream()
                .map(this::highlightLogLine)
                .toList();
        } catch (IOException e) {
            return List.of("读取日志失败: " + e.getMessage());
        }
    }
    
    /**
     * 高亮日志行
     */
    private String highlightLogLine(String line) {
        if (line.contains("[ERROR]") || line.contains("Exception") || line.contains("Error")) {
            return ERROR_COLOR + line + RESET;
        } else if (line.contains("[WARN]")) {
            return WARN_COLOR + line + RESET;
        } else if (line.contains("[INFO]")) {
            return INFO_COLOR + line + RESET;
        } else if (line.contains("[DEBUG]")) {
            return DEBUG_COLOR + line + RESET;
        }
        return line;
    }
    
    /**
     * 导出崩溃报告
     */
    public Path exportCrashReport(String crashReason, String stackTrace) throws IOException {
        Path crashDir = logFile.getParent().resolve("crash-reports");
        Files.createDirectories(crashDir);
        
        String timestamp = LocalDateTime.now().format(FORMATTER);
        Path crashReport = crashDir.resolve("crash-" + timestamp + ".txt");
        
        StringBuilder content = new StringBuilder();
        content.append("=================================\n");
        content.append("TapMC 崩溃报告\n");
        content.append("时间: " + timestamp + "\n");
        content.append("=================================\n\n");
        content.append("崩溃原因:\n");
        content.append(crashReason + "\n\n");
        content.append("堆栈跟踪:\n");
        content.append(stackTrace + "\n\n");
        content.append("=================================\n");
        
        Files.writeString(crashReport, content.toString());
        return crashReport;
    }
    
    /**
     * 解析崩溃日志
     */
    public Optional<CrashInfo> analyzeCrash(String logContent) {
        // 简单匹配常见崩溃模式
        if (logContent.contains("OutOfMemoryError")) {
            return Optional.of(new CrashInfo(
                "内存溢出",
                logContent.contains("Java heap space") ? "堆空间不足" : "元空间溢出"
            ));
        }
        
        if (logContent.contains("StackOverflowError")) {
            return Optional.of(new CrashInfo(
                "栈溢出",
                "递归调用过深或循环依赖"
            ));
        }
        
        if (logContent.contains("NoClassDefFoundError")) {
            return Optional.of(new CrashInfo(
                "类未找到",
                "依赖缺失或版本不兼容"
            ));
        }
        
        return Optional.empty();
    }
    
    /**
     * 日志条目
     */
    public record LogEntry(String level, String message, LocalDateTime timestamp) {}
    
    /**
     * 崩溃信息
     */
    public record CrashInfo(String type, String cause) {}
}
