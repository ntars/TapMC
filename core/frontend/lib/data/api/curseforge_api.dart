import 'dart:convert';
import 'package:http/http.dart' as http;

class CurseforgeProject {
  final int id;
  final String name;
  final String slug;
  final String description;
  final String summary;
  final String? iconUrl;
  final int downloads;
  final DateTime? dateModified;
  final List<String> categories;

  CurseforgeProject({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.summary,
    this.iconUrl,
    required this.downloads,
    required this.dateModified,
    required this.categories,
  });

  factory CurseforgeProject.fromJson(Map<String, dynamic> json) {
    return CurseforgeProject(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      description: json['description'] ?? '',
      summary: json['summary'] ?? '',
      iconUrl: json['iconUrl'],
      downloads: json['downloads']?.toInt() ?? 0,
      dateModified: json['dateModified'] != null 
        ? DateTime.parse(json['dateModified']) 
        : null,
      categories: List<String>.from(json['categories'] ?? []),
    );
  }
}

class CurseforgeVersion {
  final int id;
  final int gameId;
  final String modId;
  final String versionNumber;
  final String? fileName;
  final DateTime? fileDate;
  final List<String> gameVersions;

  CurseforgeVersion({
    required this.id,
    required this.gameId,
    required this.modId,
    required this.versionNumber,
    this.fileName,
    required this.fileDate,
    required this.gameVersions,
  });

  factory CurseforgeVersion.fromJson(Map<String, dynamic> json) {
    return CurseforgeVersion(
      id: json['id'] ?? 0,
      gameId: json['gameId']?.toInt() ?? 0,
      modId: json['modId'] ?? '',
      versionNumber: json['versionNumber'] ?? '',
      fileName: json['fileName'],
      fileDate: json['fileDate'] != null 
        ? DateTime.parse(json['fileDate']) 
        : null,
      gameVersions: List<String>.from(json['gameVersions'] ?? []),
    );
  }
}

class CurseforgeApi {
  static const String baseUrl = 'https://api.curseforge.com/v1';
  
  final String apiKey;

  CurseforgeApi(this.apiKey);

  Future<List<CurseforgeProject>> searchMods({
    String? query,
    int? categoryId,
    int gameVersionId = 1465,
    int limit = 20,
  }) async {
    final uri = Uri.parse('$baseUrl/mods/search')
        .replace(queryParameters: {
      'searchFilter': query ?? '',
      'categoryId': categoryId?.toString(),
      'gameVersionId': gameVersionId.toString(),
      'sortField': '1',
      'pageSize': limit.toString(),
    });

    try {
      final response = await http.get(uri, headers: {'x-api-key': apiKey});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = (data['data'] as List)
            .map((item) => CurseforgeProject.fromJson(item))
            .toList();
        
        return results;
      } else {
        throw Exception('API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('网络错误: $e');
    }
  }

  Future<CurseforgeProject> getProject(int projectId) async {
    final uri = Uri.parse('$baseUrl/mods/$projectId');

    try {
      final response = await http.get(uri, headers: {'x-api-key': apiKey});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return CurseforgeProject.fromJson(data);
      } else {
        throw Exception('API error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('网络错误: $e');
    }
  }

  Future<List<CurseforgeVersion>> getProjectVersions(int projectId) async {
    final uri = Uri.parse('$baseUrl/mods/$projectId/files');

    try {
      final response = await http.get(uri, headers: {'x-api-key': apiKey});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final versions = (data['data'] as List)
            .map((item) => CurseforgeVersion.fromJson(item))
            .toList();
        
        return versions;
      } else {
        throw Exception('API error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('网络错误: $e');
    }
  }
}
