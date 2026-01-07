import 'dart:convert';

import 'package:http/http.dart' as http;

class GitHubReleaseInfo {
  final String tagName;
  final String htmlUrl;
  final String? apkDownloadUrl;

  const GitHubReleaseInfo({
    required this.tagName,
    required this.htmlUrl,
    required this.apkDownloadUrl,
  });
}

class GitHubUpdateService {
  final String owner;
  final String repo;
  final http.Client _client;

  GitHubUpdateService({
    required this.owner,
    required this.repo,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Uri _latestReleaseUri() =>
      Uri.parse('https://api.github.com/repos/$owner/$repo/releases/latest');

  Uri _releasesUri({int perPage = 20}) => Uri.parse(
        'https://api.github.com/repos/$owner/$repo/releases?per_page=$perPage',
      );

  Uri _tagsUri({int perPage = 20}) => Uri.parse(
        'https://api.github.com/repos/$owner/$repo/tags?per_page=$perPage',
      );

  Map<String, String> get _headers => const {
        'Accept': 'application/vnd.github+json',
        // Some GitHub setups behave better with a User-Agent.
        'User-Agent': 'lumen-reader',
      };

  GitHubReleaseInfo? _parseRelease(Map<String, dynamic> data) {
    final tagName = (data['tag_name'] as String?)?.trim() ?? '';
    final htmlUrl = (data['html_url'] as String?)?.trim() ?? '';

    String? apkUrl;
    final assets = data['assets'];
    if (assets is List) {
      for (final a in assets) {
        if (a is! Map<String, dynamic>) continue;
        final url = a['browser_download_url'];
        if (url is String && url.toLowerCase().endsWith('.apk')) {
          apkUrl = url;
          break;
        }
      }
    }

    if (tagName.isEmpty || htmlUrl.isEmpty) return null;

    return GitHubReleaseInfo(
      tagName: tagName,
      htmlUrl: htmlUrl,
      apkDownloadUrl: apkUrl,
    );
  }

  Future<GitHubReleaseInfo?> fetchLatestRelease({bool includePreRelease = true}) async {
    final res = await _client.get(
      _latestReleaseUri(),
      headers: _headers,
    );

    // GitHub returns 404 if there is no *published* release (common when only tags exist,
    // or when latest is a draft, or when only prereleases exist).
    if (res.statusCode == 404) {
      return fetchMostRecentRelease(includePreRelease: includePreRelease);
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('GitHub API erro: HTTP ${res.statusCode}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return _parseRelease(data);
  }

  Future<GitHubReleaseInfo?> fetchMostRecentRelease({
    bool includePreRelease = true,
  }) async {
    final res = await _client.get(
      _releasesUri(),
      headers: _headers,
    );

    if (res.statusCode == 404) {
      // Repository not found or private. (GitHub uses 404 for private repos when unauthenticated.)
      throw Exception(
        'Repositório não encontrado ou privado. Para verificar atualizações sem login, o repositório de releases precisa ser público.',
      );
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('GitHub API erro: HTTP ${res.statusCode}');
    }

    final data = jsonDecode(res.body);
    if (data is! List) return null;

    for (final item in data) {
      if (item is! Map<String, dynamic>) continue;
      final isDraft = item['draft'] == true;
      final isPre = item['prerelease'] == true;
      if (isDraft) continue;
      if (!includePreRelease && isPre) continue;

      final parsed = _parseRelease(item);
      if (parsed != null) return parsed;
    }

    // No releases matched; fallback to tags.
    return fetchMostRecentTag();
  }

  Future<GitHubReleaseInfo?> fetchMostRecentTag() async {
    final res = await _client.get(
      _tagsUri(),
      headers: _headers,
    );

    if (res.statusCode == 404) {
      throw Exception(
        'Repositório não encontrado ou privado. Para verificar atualizações sem login, o repositório de releases precisa ser público.',
      );
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('GitHub API erro: HTTP ${res.statusCode}');
    }

    final data = jsonDecode(res.body);
    if (data is! List || data.isEmpty) return null;

    final first = data.first;
    if (first is! Map<String, dynamic>) return null;
    final tagName = (first['name'] as String?)?.trim() ?? '';
    if (tagName.isEmpty) return null;

    // Tags don't have a release page. Use the generic tag URL.
    final htmlUrl = 'https://github.com/$owner/$repo/releases/tag/$tagName';
    return GitHubReleaseInfo(
      tagName: tagName,
      htmlUrl: htmlUrl,
      apkDownloadUrl: null,
    );
  }

  bool isNewer({required String currentVersion, required String latestTag}) {
    final cur = _parseVersionParts(currentVersion);
    final latest = _parseVersionParts(latestTag);

    for (var i = 0; i < 3; i++) {
      final a = cur[i];
      final b = latest[i];
      if (b > a) return true;
      if (b < a) return false;
    }
    return false;
  }

  List<int> _parseVersionParts(String v) {
    var s = v.trim();
    if (s.startsWith('v') || s.startsWith('V')) {
      s = s.substring(1);
    }
    final plusIdx = s.indexOf('+');
    if (plusIdx >= 0) {
      s = s.substring(0, plusIdx);
    }

    final parts = s.split('.');
    int p0 = 0;
    int p1 = 0;
    int p2 = 0;

    if (parts.isNotEmpty) p0 = int.tryParse(_digits(parts[0])) ?? 0;
    if (parts.length > 1) p1 = int.tryParse(_digits(parts[1])) ?? 0;
    if (parts.length > 2) p2 = int.tryParse(_digits(parts[2])) ?? 0;

    return [p0, p1, p2];
  }

  String _digits(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');
}
