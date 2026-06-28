import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// A GitHub repository (subset of fields we use).
class GitHubRepo {
  final String name;
  final String fullName;
  final String cloneUrl;
  final bool private;
  final String? description;
  final String? language;
  final int stars;

  GitHubRepo({
    required this.name,
    required this.fullName,
    required this.cloneUrl,
    required this.private,
    this.description,
    this.language,
    this.stars = 0,
  });

  factory GitHubRepo.fromJson(Map<String, dynamic> j) => GitHubRepo(
        name: j['name'] as String? ?? '',
        fullName: j['full_name'] as String? ?? '',
        cloneUrl: j['clone_url'] as String? ?? '',
        private: j['private'] as bool? ?? false,
        description: j['description'] as String?,
        language: j['language'] as String?,
        stars: (j['stargazers_count'] as num?)?.toInt() ?? 0,
      );
}

class GitHubException implements Exception {
  final String message;
  GitHubException(this.message);
  @override
  String toString() => message;
}

class GitHubService {
  static const _base = 'https://api.github.com';

  /// Fetches the authenticated user's repositories (most recently updated).
  static Future<List<GitHubRepo>> fetchRepos(String token) async {
    final repos = <GitHubRepo>[];
    for (var page = 1; page <= 3; page++) {
      final res = await http.get(
        Uri.parse(
            '$_base/user/repos?per_page=100&sort=updated&page=$page&affiliation=owner,collaborator,organization_member'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
        },
      );
      if (res.statusCode == 401) {
        throw GitHubException('Invalid token (401). Check your GitHub token.');
      }
      if (res.statusCode != 200) {
        throw GitHubException('GitHub API error ${res.statusCode}: ${res.body}');
      }
      final list = jsonDecode(res.body) as List;
      repos.addAll(list.map((e) => GitHubRepo.fromJson(e as Map<String, dynamic>)));
      if (list.length < 100) break;
    }
    return repos;
  }

  /// Clones [repo] into [destDir]/[repo.name] using the token for auth.
  /// Returns the cloned path on success, or throws.
  static Future<String> clone(
      GitHubRepo repo, String destDir, String token) async {
    final target = p.join(destDir, repo.name);
    if (Directory(target).existsSync() &&
        Directory(target).listSync().isNotEmpty) {
      throw GitHubException('Folder already exists and is not empty: $target');
    }
    // Authenticated URL for private repos.
    final authUrl = repo.cloneUrl
        .replaceFirst('https://', 'https://x-access-token:$token@');
    final res = await Process.run(
      'git',
      ['clone', authUrl, target],
      runInShell: true,
    );
    if (res.exitCode != 0) {
      throw GitHubException('git clone failed: ${res.stderr}');
    }
    return target;
  }
}
