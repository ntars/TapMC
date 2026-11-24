import 'dart:io';
import 'package:flutter/foundation.dart';

class JavaVersionInfo {
  final String javaHome;
  final String version;
  final String vendor;
  final bool isDefault;

  JavaVersionInfo({
    required this.javaHome,
    required this.version,
    required this.vendor,
    this.isDefault = false,
  });

  factory JavaVersionInfo.fromJson(Map<String, dynamic> json) {
    return JavaVersionInfo(
      javaHome: json['javaHome'] ?? '',
      version: json['version'] ?? '',
      vendor: json['vendor'] ?? 'Unknown',
      isDefault: json['isDefault'] ?? false,
    );
  }

  @override
  String toString() => 'Java $version ($vendor)';
}

class JavaVersionManager extends ChangeNotifier {
  final List<JavaVersionInfo> _javaVersions = [];
  String? _selectedVersion;

  List<JavaVersionInfo> get javaVersions => List.unmodifiable(_javaVersions);
  String? get selectedVersion => _selectedVersion;
  
  JavaVersionInfo? get defaultVersion {
    if (_javaVersions.isEmpty) return null;
    try {
      return _javaVersions.firstWhere((v) => v.isDefault);
    } catch (e) {
      return _javaVersions.first;
    }
  }

  Future<void> detectJavaVersions() async {
    _javaVersions.clear();
    
    final commonPaths = [
      '/usr/lib/jvm/default-java',
      '/Library/Java/JavaVirtualMachines/jdk-21.jdk/Contents/Home',
      '/Library/Java/JavaVirtualMachines/jdk-17.jdk/Contents/Home',
      'C:\\Program Files\\Java\\jdk-21',
    ];
    
    for (final path in commonPaths) {
      try {
        final file = File('$path/bin/java');
        if (await file.exists()) {
          final versionInfo = await _getJavaVersion(path);
          if (versionInfo != null) {
            _javaVersions.add(versionInfo);
          }
        }
      } catch (e) {
        // 忽略无法访问的路径
      }
    }
    
    notifyListeners();
  }

  Future<JavaVersionInfo?> _getJavaVersion(String javaHome) async {
    try {
      final result = await Process.run('$javaHome/bin/java', ['-version']);
      final output = result.stdout.toString();
      
      String? version;
      String vendor = 'Unknown';
      
      if (output.contains('OpenJDK')) {
        final match = RegExp(r'openjdk version "([^"]+)"').firstMatch(output);
        if (match != null) {
          version = match.group(1);
        }
        vendor = 'OpenJDK';
      } else if (output.contains('Java(TM) SE')) {
        final match = RegExp(r'version "([^"]+)"').firstMatch(output);
        if (match != null) {
          version = match.group(1);
        }
        vendor = 'Oracle';
      } else if (output.contains('Eclipse OpenJ9')) {
        final match = RegExp(r'version "([^"]+)"').firstMatch(output);
        if (match != null) {
          version = match.group(1);
        }
        vendor = 'Eclipse OpenJ9';
      }
      
      if (version == null) {
        return null;
      }
      
      return JavaVersionInfo(
        javaHome: javaHome,
        version: version,
        vendor: vendor,
      );
    } catch (e) {
      return null;
    }
  }

  void setSelectedVersion(String? version) {
    _selectedVersion = version;
    notifyListeners();
  }

  void clearSelectedVersion() {
    _selectedVersion = null;
    notifyListeners();
  }
}
