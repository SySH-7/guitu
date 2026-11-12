import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

class UpdateService {
  static const channel = MethodChannel('guitu/app_info');
  static const repositoryUrl = 'https://github.com/SySH-7/guitu';
  static const releasesUrl = '$repositoryUrl/releases/latest';

  Future<String> currentVersion() async =>
      (await channel.invokeMethod<String>('version')) ?? '';

  Future<void> openLink(String url) =>
      channel.invokeMethod<void>('openLink', {'url': url});

  Future<String> latestVersion() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(Uri.parse(
          'https://api.github.com/repos/SySH-7/guitu/releases/latest'));
      request.headers.set(HttpHeaders.userAgentHeader, 'Guitu-Android');
      request.headers
          .set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final response =
          await request.close().timeout(const Duration(seconds: 15));
      if (response.statusCode != 200)
        throw HttpException('GitHub 返回 ${response.statusCode}');
      final body = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 15));
      final value = jsonDecode(body);
      if (value is! Map || value['tag_name'] is! String)
        throw const FormatException('版本信息无效');
      final version = value['tag_name'] as String;
      _parts(version);
      return version;
    } finally {
      client.close(force: true);
    }
  }

  static List<int> _parts(String version) {
    final match = RegExp(r'^[vV]?(\d+)\.(\d+)\.(\d+)(?:\+\d+)?$')
        .firstMatch(version.trim());
    if (match == null) throw const FormatException('版本号无法比较');
    return List<int>.generate(3, (i) => int.parse(match.group(i + 1)!));
  }

  static int compare(String a, String b) {
    final left = _parts(a), right = _parts(b);
    for (var i = 0; i < 3; i++) {
      if (left[i] != right[i]) return left[i].compareTo(right[i]);
    }
    return 0;
  }
}
