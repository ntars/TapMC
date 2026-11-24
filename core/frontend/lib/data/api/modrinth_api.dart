import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:typed_data';

class ModrinthProject {
  final String id;
  final String slug;
  final String title;
  final String description;
  final List<String> categories;
  final List<String> gameVersions;
  final List<String> loaders;
  final int downloads;
  final String iconUrl;
  final DateTime? updatedAt;

  ModrinthProject({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    required this.categories,
    required this.gameVersions,
    required this.loaders,
    required this.downloads,
    required this.iconUrl,
    required this.updatedAt,
  });

  factory ModrinthProject.fromJson(Map<String, dynamic> json) {
    return ModrinthProject(
      id: json['id'] ?? '',
      slug: json['slug'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      categories: List<String>.from(json['categories'] ?? []),
      gameVersions: List<String>.from(json['game_versions'] ?? []),
      loaders: List<String>.from(json['loaders'] ?? []),
      downloads: json['downloads']?.toInt() ?? 0,
      iconUrl: json['icon_url'] ?? '',
      updatedAt: json['updated'] != null ? DateTime.parse(json['updated']) : null,
    );
  }
}

class ModrinthVersion {
  final String id;
  final String projectId;
  final String versionNumber;
  final String name;
  final List<String> gameVersions;
  final List<String> loaders;
  final bool isDefault;

  ModrinthVersion({
    required this.id,
    required this.projectId,
    required this.versionNumber,
    required this.name,
    required this.gameVersions,
    required this.loaders,
    required this.isDefault,
  });

  factory ModrinthVersion.fromJson(Map<String, dynamic> json) {
    return ModrinthVersion(
      id: json['id'] ?? '',
      projectId: json['project_id'] ?? '',
      versionNumber: json['version_number'] ?? '',
      name: json['name'] ?? '',
      gameVersions: List<String>.from(json['game_versions'] ?? []),
      loaders: List<String>.from(json['loaders'] ?? []),
      isDefault: json['primary_file'] != null,
    );
  }
}

class ModrinthApi {
  static const String baseUrl = 'https://api.modrinth.com/v2';
  
  final http.Client client;

  ModrinthApi([http.Client? client]) : client = client ?? http.Client();

  Future<List<ModrinthProject>> searchMods({
    String? query,
    List<String>? categories,
    List<String>? gameVersions,
    int limit = 20,
    String? offset,
  }) async {
    final params = <String, dynamic>{
      'q': query ?? '',
      'limit': limit,
    };
    
    if (categories != null && categories.isNotEmpty) {
      params['facets'] = '[["categories:${categories.join('|')}"]]';
    }
    
    if (gameVersions != null && gameVersions.isNotEmpty) {
      final existingFacets = params['facets'] ?? '';
      params['facets'] = '$existingFacets[["versions:${gameVersions.join('|')}"]]';
    }
    
    if (offset != null) {
      params['offset'] = offset;
    }

    final uri = Uri.parse('$baseUrl/search').replace(queryParameters: params);
    
    try {
      final response = await client.get(uri);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = (data['hits'] as List)
            .map((item) => ModrinthProject.fromJson(item))
            .toList();
        
        return results;
      } else {
        throw Exception('API error: ${response.statusCode} - ${response.body}');
      }
    } on Exception catch (e) {
      throw Exception('网络错误: $e');
    }
  }

  Future<ModrinthProject> getProject(String projectId) async {
    final uri = Uri.parse('$baseUrl/project/$projectId');
    
    try {
      final response = await client.get(uri);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ModrinthProject.fromJson(data);
      } else {
        throw Exception('API error: ${response.statusCode}');
      }
    } on Exception catch (e) {
      throw Exception('网络错误: $e');
    }
  }

  Future<List<ModrinthVersion>> getProjectVersions(String projectId) async {
    final uri = Uri.parse('$baseUrl/project/$projectId/version');
    
    try {
      final response = await client.get(uri);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final versions = (data as List)
            .map((item) => ModrinthVersion.fromJson(item))
            .toList();
        
        return versions;
      } else {
        throw Exception('API error: ${response.statusCode}');
      }
    } on Exception catch (e) {
      throw Exception('网络错误: $e');
    }
  }

  Future<Uint8List> downloadFile(String url) async {
    try {
      final response = await client.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception('下载失败: ${response.statusCode}');
      }
    } on Exception catch (e) {
      throw Exception('网络错误: $e');
    }
  }

  void close() {
    client.close();
  }
}
