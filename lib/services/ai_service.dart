import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

/// Protocol used by a provider. Custom endpoints use the OpenAI chat format.
enum AiProtocol { openAi, anthropic, gemini }

class AiProviderPreset {
  const AiProviderPreset(
      this.id, this.name, this.baseUrl, this.model, this.protocol);
  final String id;
  final String name;
  final String baseUrl;
  final String model;
  final AiProtocol protocol;
}

const List<AiProviderPreset> aiProviderPresets = <AiProviderPreset>[
  AiProviderPreset('deepseek', 'DeepSeek', 'https://api.deepseek.com/v1',
      'deepseek-chat', AiProtocol.openAi),
  AiProviderPreset('kimi', 'Kimi', 'https://api.moonshot.cn/v1',
      'moonshot-v1-8k', AiProtocol.openAi),
  AiProviderPreset('glm', 'GLM', 'https://open.bigmodel.cn/api/paas/v4',
      'glm-4-flash', AiProtocol.openAi),
  AiProviderPreset('claude', 'Claude', 'https://api.anthropic.com/v1',
      'claude-sonnet-4-5', AiProtocol.anthropic),
  AiProviderPreset('openai', 'GPT', 'https://api.openai.com/v1', 'gpt-4o-mini',
      AiProtocol.openAi),
  AiProviderPreset(
      'gemini',
      'Gemini',
      'https://generativelanguage.googleapis.com/v1beta',
      'gemini-3.5-flash-lite',
      AiProtocol.gemini),
  AiProviderPreset(
      'qwen',
      'Qwen',
      'https://dashscope.aliyuncs.com/compatible-mode/v1',
      'qwen-plus',
      AiProtocol.openAi),
  AiProviderPreset(
      'grok', 'Grok', 'https://api.x.ai/v1', 'grok-3-mini', AiProtocol.openAi),
  AiProviderPreset('custom', '自定义（OpenAI 兼容）', '', '', AiProtocol.openAi),
];

class AiConfig {
  const AiConfig(
      {required this.providerId,
      required this.baseUrl,
      required this.model,
      required this.apiKey});
  final String providerId;
  final String baseUrl;
  final String model;
  final String apiKey;
  AiProtocol get protocol =>
      aiProviderPresets
          .where((p) => p.id == providerId)
          .firstOrNull
          ?.protocol ??
      AiProtocol.openAi;
  Map<String, String> toJson() => {
        'providerId': providerId,
        'baseUrl': baseUrl,
        'model': model,
        'apiKey': apiKey
      };
  factory AiConfig.fromJson(Map<String, dynamic> json) => AiConfig(
        providerId: json['providerId'] as String? ?? 'custom',
        baseUrl: json['baseUrl'] as String? ?? '',
        model: json['model'] as String? ?? '',
        apiKey: json['apiKey'] as String? ?? '',
      );
}

/// AI credentials are separate from archive snapshots and encrypted on Android.
class AiConfigStore {
  static const MethodChannel _channel = MethodChannel('guitu/ai_config');
  Future<AiConfig?> load() async {
    final data = await _channel.invokeMethod<String>('read');
    if (data == null || data.isEmpty) return null;
    return AiConfig.fromJson(jsonDecode(data) as Map<String, dynamic>);
  }

  Future<void> clear() => _channel.invokeMethod<void>('clear');

  Future<void> save(AiConfig config) => _channel
      .invokeMethod<void>('write', {'data': jsonEncode(config.toJson())});
}

/// The prepared request is testable without sending any user data over the network.
class AiRequest {
  const AiRequest(this.uri, this.headers, this.body);
  final Uri uri;
  final Map<String, String> headers;
  final Map<String, Object> body;
}

class AiService {
  static AiRequest buildRequest(
      {required AiConfig config,
      required String systemPrompt,
      required String userPrompt}) {
    final base = Uri.tryParse(config.baseUrl.trim());
    if (base == null ||
        base.scheme != 'https' ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment) {
      throw const FormatException('请输入有效的 HTTPS API 地址，不要包含查询参数或账号信息');
    }
    final model = config.model.trim();
    final key = config.apiKey.trim();
    if (model.isEmpty || key.isEmpty) {
      throw const FormatException('请先填写模型和 API 密钥');
    }
    final path = base.path.replaceAll(RegExp(r'/+$'), '');
    final headers = <String, String>{};
    final Map<String, Object> body;
    String suffix;
    switch (config.protocol) {
      case AiProtocol.openAi:
        suffix = path.endsWith('/chat/completions') ? '' : '/chat/completions';
        headers[HttpHeaders.authorizationHeader] = 'Bearer $key';
        body = {
          'model': model,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ]
        };
      case AiProtocol.anthropic:
        suffix = path.endsWith('/messages') ? '' : '/messages';
        headers['x-api-key'] = key;
        headers['anthropic-version'] = '2023-06-01';
        body = {
          'model': model,
          'max_tokens': 2048,
          'system': systemPrompt,
          'messages': [
            {'role': 'user', 'content': userPrompt}
          ]
        };
      case AiProtocol.gemini:
        // A model ID must be one path segment; this also prevents it from
        // changing the intended API path.
        if (!RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(model)) {
          throw const FormatException('Gemini 模型名称格式不正确，请填写模型 ID');
        }
        suffix = '/models/$model:generateContent';
        headers['x-goog-api-key'] = key;
        body = {
          'system_instruction': {
            'parts': [
              {'text': systemPrompt}
            ]
          },
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': userPrompt}
              ]
            }
          ]
        };
    }
    return AiRequest(base.replace(path: '$path$suffix'), headers, body);
  }

  static String parseResponse(AiProtocol protocol, String responseBody) {
    try {
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      String text;
      switch (protocol) {
        case AiProtocol.openAi:
          text =
              (json['choices'] as List).first['message']['content'] as String;
        case AiProtocol.anthropic:
          text = (json['content'] as List)
              .where((part) => part['type'] == 'text')
              .map((part) => part['text'])
              .join('\n');
        case AiProtocol.gemini:
          text =
              ((json['candidates'] as List).first['content']['parts'] as List)
                  .where((part) => part['thought'] != true)
                  .map((part) => part['text'] ?? '')
                  .join('\n');
      }
      if (text.trim().isEmpty) throw const FormatException('AI 服务未返回文本');
      return text.trim();
    } catch (_) {
      // Do not include the provider's raw payload: it may echo private data.
      throw const FormatException('AI 服务未返回可用文本，请检查模型或稍后重试');
    }
  }

  Future<String> generate(
      {required AiConfig config,
      required String systemPrompt,
      required String userPrompt}) async {
    final prepared = buildRequest(
        config: config, systemPrompt: systemPrompt, userPrompt: userPrompt);
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client
          .postUrl(prepared.uri)
          .timeout(const Duration(seconds: 20));
      request.followRedirects = false;
      request.headers.contentType = ContentType.json;
      prepared.headers
          .forEach((name, value) => request.headers.set(name, value));
      request.write(jsonEncode(prepared.body));
      final response =
          await request.close().timeout(const Duration(seconds: 90));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
            'AI 服务请求失败（HTTP ${response.statusCode}），请检查地址、密钥和模型');
      }
      final responseBody = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 90));
      return parseResponse(config.protocol, responseBody);
    } on SocketException {
      throw const HttpException('无法连接 AI 服务，请检查网络和服务地址');
    } on TimeoutException {
      throw const HttpException('AI 服务响应超时，请稍后重试');
    } finally {
      client.close(force: true);
    }
  }
}
