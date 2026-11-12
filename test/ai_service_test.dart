import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitu/services/ai_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AiConfig config(String provider, String url, [String model = 'test-model']) =>
      AiConfig(
          providerId: provider, baseUrl: url, model: model, apiKey: 'secret');

  group('AI requests', () {
    test(
        'OpenAI compatible endpoints preserve base paths and send system/user roles',
        () {
      final request = AiService.buildRequest(
        config: config('custom', 'https://example.com/compatible/v1/'),
        systemPrompt: 'system',
        userPrompt: 'private',
      );
      expect(request.uri.toString(),
          'https://example.com/compatible/v1/chat/completions');
      expect(request.headers['authorization'], 'Bearer secret');
      expect(request.body['messages'], [
        {'role': 'system', 'content': 'system'},
        {'role': 'user', 'content': 'private'},
      ]);
      final full = AiService.buildRequest(
        config: config('custom', 'https://example.com/v1/chat/completions'),
        systemPrompt: '',
        userPrompt: '',
      );
      expect(full.uri.path, '/v1/chat/completions');
    });

    test('Claude and Gemini use their own authentication and request formats',
        () {
      final claude = AiService.buildRequest(
        config: config('claude', 'https://api.anthropic.com/v1'),
        systemPrompt: 'system',
        userPrompt: 'user',
      );
      expect(claude.uri.path, '/v1/messages');
      expect(claude.headers['x-api-key'], 'secret');
      expect(claude.headers['anthropic-version'], '2023-06-01');
      expect(claude.body['system'], 'system');
      final gemini = AiService.buildRequest(
        config: config(
            'gemini', 'https://generativelanguage.googleapis.com/v1beta'),
        systemPrompt: 'system',
        userPrompt: 'user',
      );
      expect(gemini.uri.path, '/v1beta/models/test-model:generateContent');
      expect(gemini.headers['x-goog-api-key'], 'secret');
      expect(gemini.body['system_instruction'], {
        'parts': [
          {'text': 'system'}
        ]
      });
    });

    test('rejects insecure URLs and invalid Gemini model paths', () {
      for (final url in [
        'http://example.com',
        'https://user@example.com',
        'https://example.com?key=x',
        'https://example.com/#fragment'
      ]) {
        expect(
            () => AiService.buildRequest(
                config: config('custom', url),
                systemPrompt: '',
                userPrompt: ''),
            throwsFormatException);
      }
      expect(
          () => AiService.buildRequest(
              config: config('gemini', 'https://example.com', '../other'),
              systemPrompt: '',
              userPrompt: ''),
          throwsFormatException);
    });
  });

  group('AI responses', () {
    test('extracts content for each protocol without revealing Gemini thoughts',
        () {
      expect(
          AiService.parseResponse(
              AiProtocol.openAi,
              jsonEncode({
                'choices': [
                  {
                    'message': {'content': ' hello '}
                  }
                ]
              })),
          'hello');
      expect(
          AiService.parseResponse(
              AiProtocol.anthropic,
              jsonEncode({
                'content': [
                  {'type': 'text', 'text': 'one'},
                  {'type': 'tool_use'},
                  {'type': 'text', 'text': 'two'}
                ]
              })),
          'one\ntwo');
      expect(
          AiService.parseResponse(
              AiProtocol.gemini,
              jsonEncode({
                'candidates': [
                  {
                    'content': {
                      'parts': [
                        {'thought': true, 'text': 'internal'},
                        {'text': 'answer'}
                      ]
                    }
                  }
                ]
              })),
          'answer');
    });
    test('handles blocked, empty, and malformed responses without echoing data',
        () {
      for (final response in ['{}', '{broken', '{"choices": []}']) {
        expect(
            () => AiService.parseResponse(AiProtocol.openAi, response),
            throwsA(isA<FormatException>().having(
                (e) => e.message, 'message', isNot(contains(response)))));
      }
    });
  });

  test('configuration uses the separate platform channel', () async {
    const channel = MethodChannel('guitu/ai_config');
    String? stored;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'write') {
        stored = (call.arguments as Map)['data'] as String;
      }
      if (call.method == 'clear') stored = null;
      if (call.method == 'read') return stored;
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final store = AiConfigStore();
    expect(await store.load(), isNull);
    await store.save(config('deepseek', 'https://api.deepseek.com/v1'));
    final result = await store.load();
    expect(result?.providerId, 'deepseek');
    expect(result?.apiKey, 'secret');
    await store.clear();
    expect(await store.load(), isNull);
  });
}
