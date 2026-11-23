import 'dart:io';

/// Java 运行时探测器
class JavaRuntimeDetector {
  /// 可能的 Java 可执行文件路径
  static const List<String> possiblePaths = [
    'java',
    '/usr/bin/java',
    '/usr/local/bin/java',
    '/opt/homebrew/bin/java',
  ];

  /// 可接受的 Java 版本范围
  static const List<String> supportedVersions = [
    '1.8',
    '9', '10', '11', '12', '13', '14', '15',
    '16', '17', '18', '19', '20', '21', '22',
    '23', '24', '25'
  ];

  /// 检测系统中的 Java 版本
  static Future<JavaRuntime?> detect() async {
    for (final path in possiblePaths) {
      if (await _isExecutable(path)) {
        final version = await _getJavaVersion(path);
        if (version != null && supportedVersions.contains(version.major)) {
          return JavaRuntime(
            path: path,
            version: version,
          );
        }
      }
    }
    return null;
  }

  /// 检查路径是否是可执行文件
  static Future<bool> _isExecutable(String path) async {
    final file = File(path);
    if (!file.existsSync()) return false;

    try {
      await Process.run(path, ['--version']);
      return true;
    } on ProcessException {
      return false;
    }
  }

  /// 获取 Java 版本
  static Future<JavaVersion?> _getJavaVersion(String path) async {
    try {
      final result = await Process.run(path, ['-version']);
      
      if (result.exitCode != 0) return null;
      
      final output = result.stdout.toString();
      final errorOutput = result.stderr.toString();
      
      // 尝试从 stdout 或 stderr 提取版本号
      final combinedOutput = '$output$errorOutput';
      
      // 匹配 Java 版本格式
      final versionPattern = RegExp(r'java version "(\d+(?:\.\d+)*)"');
      final match = versionPattern.firstMatch(combinedOutput);
      
      if (match != null) {
        final versionString = match.group(1)!;
        return JavaVersion.parse(versionString);
      }
      
      return null;
    } on ProcessException {
      return null;
    }
  }

  /// 获取推荐的 JVM 参数
  static List<String> getRecommendedJvmArgs(JavaRuntime runtime) {
    final args = <String>[];
    
    // Apple Silicon 优化
    if (Platform.isMacOS) {
      args.add('-XX:+UseG1GC');
      args.add('-XX:MaxGCPauseMillis=200');
    }
    
    // Windows Dark Theme 支持
    if (Platform.isWindows) {
      args.add('-Dsun.java2d.uiScale=1.0');
    }
    
    // 通用优化
    args.add('-Xmx2G'); // 最大堆内存 2GB
    args.add('-XX:+UnlockExperimentalVMOptions');
    
    return args;
  }
}

/// Java 运行时信息
class JavaRuntime {
  final String path;
  final JavaVersion version;

  const JavaRuntime({
    required this.path,
    required this.version,
  });

  @override
  String toString() => 'JavaRuntime($path, v$version)';
}

/// Java 版本信息
class JavaVersion {
  final String major;
  final String? minor;
  final String? patch;

  const JavaVersion({
    required this.major,
    this.minor,
    this.patch,
  });

  static JavaVersion parse(String versionString) {
    final parts = versionString.split('.');
    return JavaVersion(
      major: parts[0],
      minor: parts.length > 1 ? parts[1] : null,
      patch: parts.length > 2 ? parts[2] : null,
    );
  }

  @override
  String toString() => '$major.${minor ?? ''}.${patch ?? ''}';
}

/// Java 启动配置
class JavaLaunchConfig {
  final String jarPath;
  final List<String>? jvmArgs;
  final Map<String, dynamic>? systemProperties;
  final bool headless;

  const JavaLaunchConfig({
    required this.jarPath,
    this.jvmArgs,
    this.systemProperties,
    this.headless = false,
  });

  List<String> toCommand(String path) {
    final cmd = <String>[path];
    
    // 添加 JVM 参数
    if (jvmArgs != null) {
      cmd.addAll(jvmArgs!);
    }
    
    // 添加系统属性
    if (systemProperties != null) {
      for (final entry in systemProperties!.entries) {
        cmd.add('-D${entry.key}=${entry.value}');
      }
    }
    
    // 添加 headless 模式
    if (headless) {
      cmd.add('-Djava.awt.headless=true');
    }
    
    // 添加 JAR 路径
    cmd.add('-jar');
    cmd.add(jarPath);
    
    return cmd;
  }
}
