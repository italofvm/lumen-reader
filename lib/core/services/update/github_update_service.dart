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

  Future<GitHubReleaseInfo?> fetchLatestRelease() async {
    final res = await _client.get(
      _latestReleaseUri(),
      headers: const {
        'Accept': 'application/vnd.github+json',
      },
    );

    if (res.statusCode == 404) return null;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('GitHub API erro: HTTP ${res.statusCode}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
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
