import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class UpdateInfo {
  final String latestVersion;
  final String downloadUrl;
  final bool hasUpdate;

  UpdateInfo({
    required this.latestVersion,
    required this.downloadUrl,
    required this.hasUpdate,
  });
}

class UpdateService {
  static const _repoOwner = 'AnDevOps2409';
  static const _repoName  = 'Apk';
  static const _apiUrl    = 'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest';

  /// Kiểm tra có phiên bản mới không
  Future<UpdateInfo> checkForUpdate() async {
    final info = await PackageInfo.fromPlatform();
    final currentVersion = info.version; // e.g. "1.0.0"
    final currentBuild   = int.tryParse(info.buildNumber) ?? 1;

    final resp = await http.get(
      Uri.parse(_apiUrl),
      headers: {'Accept': 'application/vnd.github.v3+json'},
    ).timeout(const Duration(seconds: 10));

    if (resp.statusCode != 200) {
      throw Exception('GitHub API lỗi: ${resp.statusCode}');
    }

    final data    = jsonDecode(resp.body) as Map<String, dynamic>;
    final tagName = data['tag_name'] as String; // e.g. "v1.0.1+2"

    // Parse tag: v1.0.1+2 → version=1.0.1, build=2
    final tagClean  = tagName.replaceFirst('v', '');
    final parts     = tagClean.split('+');
    final latestVer = parts[0];
    final latestBld = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;

    // Tìm APK asset
    final assets = data['assets'] as List<dynamic>;
    String downloadUrl = '';
    for (final asset in assets) {
      final name = (asset['name'] as String).toLowerCase();
      if (name.endsWith('.apk')) {
        downloadUrl = asset['browser_download_url'] as String;
        break;
      }
    }

    // So sánh build number
    final hasUpdate = latestBld > currentBuild ||
        (latestBld == currentBuild && _versionCompare(latestVer, currentVersion) > 0);

    return UpdateInfo(
      latestVersion: latestVer,
      downloadUrl: downloadUrl,
      hasUpdate: hasUpdate && downloadUrl.isNotEmpty,
    );
  }

  /// Download APK và trả về đường dẫn file
  Future<String> downloadApk(
    String url,
    void Function(double progress) onProgress,
  ) async {
    final dir  = await getTemporaryDirectory();
    final path = '${dir.path}/update.apk';
    final file = File(path);

    final request  = http.Request('GET', Uri.parse(url));
    final response = await request.send();
    final total    = response.contentLength ?? 0;
    int received   = 0;

    final sink = file.openWrite();
    await response.stream.map((chunk) {
      received += chunk.length;
      if (total > 0) onProgress(received / total);
      return chunk;
    }).pipe(sink);
    await sink.flush();
    await sink.close();

    return path;
  }

  /// Mở file APK để cài đặt
  Future<void> installApk(String path) async {
    await OpenFile.open(path);
  }

  int _versionCompare(String a, String b) {
    final ap = a.split('.').map(int.parse).toList();
    final bp = b.split('.').map(int.parse).toList();
    for (int i = 0; i < 3; i++) {
      final ai = i < ap.length ? ap[i] : 0;
      final bi = i < bp.length ? bp[i] : 0;
      if (ai != bi) return ai.compareTo(bi);
    }
    return 0;
  }
}
