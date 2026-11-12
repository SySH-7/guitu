import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/ai_service.dart';

/// Configuration is deliberately separate from exported archive data.
class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _url = TextEditingController();
  final _model = TextEditingController();
  final _key = TextEditingController();
  String? _providerId;
  bool _loading = true;
  bool _saving = false;
  bool _showKey = false;
  String? _loadError;
  bool _canReset = true;
  String? _status;
  bool _connectionOk = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final config = await AiConfigStore().load();
      if (!mounted) return;
      setState(() {
        _providerId = config?.providerId ?? aiProviderPresets.first.id;
        final preset = aiProviderPresets.firstWhere(
          (item) => item.id == _providerId,
          orElse: () => aiProviderPresets.first,
        );
        _providerId = preset.id;
        _url.text = config?.baseUrl ?? preset.baseUrl;
        _model.text = config?.model ?? preset.model;
        _key.text = config?.apiKey ?? '';
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = '无法读取 AI 配置：$error';
        _canReset =
            error is! PlatformException || error.code != 'AI_UNSUPPORTED';
      });
    }
  }

  Future<void> _resetUnreadableConfig() async {
    setState(() => _loading = true);
    try {
      await AiConfigStore().clear();
      if (!mounted) return;
      setState(() => _loadError = null);
      await _load();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = '无法清除 AI 配置，请重试。';
      });
    }
  }

  @override
  void dispose() {
    _url.dispose();
    _model.dispose();
    _key.dispose();
    super.dispose();
  }

  void _selectProvider(String? id) {
    if (id == null || id == _providerId) return;
    final preset = aiProviderPresets.firstWhere((item) => item.id == id);
    setState(() {
      _providerId = id;
      _url.text = preset.baseUrl;
      _model.text = preset.model;
      // Avoid accidentally sending one provider's secret to another provider.
      _key.clear();
      _status = null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _providerId == null) return;
    final config = AiConfig(
      providerId: _providerId!,
      baseUrl: _url.text.trim(),
      model: _model.text.trim(),
      apiKey: _key.text.trim(),
    );
    setState(() {
      _saving = true;
      _status = null;
    });
    try {
      await AiConfigStore().save(config);
      if (!mounted) return;
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _connectionOk = false;
        _status = '保存失败，请重试。';
      });
      return;
    }
    try {
      await AiService()
          .generate(config: config, systemPrompt: '请简短回答。', userPrompt: '你好');
      if (mounted) {
        setState(() {
          _connectionOk = true;
          _status = '设置已保存，连接成功。';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _connectionOk = false;
          final message = error.toString().replaceFirst(
              RegExp(r'^(HttpException|FormatException|Exception):\s*'), '');
          _status = '设置已保存，连接失败：$message';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('AI 助手设置')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_loadError!),
                      if (_canReset) ...[
                        const SizedBox(height: 12),
                        const Text('可以清除无法读取的 AI 配置后重新设置，归途记录不会受到影响。'),
                        TextButton(
                            onPressed: _resetUnreadableConfig,
                            child: const Text('清除 AI 配置并重新设置')),
                      ],
                    ],
                  ),
                ))
              : IgnorePointer(
                  ignoring: _saving,
                  child: Form(
                    key: _formKey,
                    onChanged: () {
                      if (_status != null) setState(() => _status = null);
                    },
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
                      children: [
                        Text('连接你的 AI 助手',
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text('选择服务商并填写 API 密钥。地址与模型均可编辑；自定义服务需使用兼容的接口。',
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(.65))),
                        const SizedBox(height: 24),
                        DropdownButtonFormField<String>(
                          value: _providerId,
                          decoration: const InputDecoration(labelText: '服务商'),
                          items: aiProviderPresets
                              .map((preset) => DropdownMenuItem(
                                    value: preset.id,
                                    child: Text(preset.name),
                                  ))
                              .toList(),
                          onChanged: _selectProvider,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _url,
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'API 地址',
                            hintText: 'https://...',
                            helperText: '填写服务商的 API 基础地址',
                          ),
                          validator: (value) {
                            final uri = Uri.tryParse((value ?? '').trim());
                            if (uri == null ||
                                uri.scheme != 'https' ||
                                uri.host.isEmpty ||
                                uri.userInfo.isNotEmpty ||
                                uri.hasQuery ||
                                uri.hasFragment) {
                              return '请输入不带查询参数或账号信息的 HTTPS 地址';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _model,
                          autocorrect: false,
                          decoration: const InputDecoration(labelText: '模型名称'),
                          validator: (value) =>
                              (value ?? '').trim().isEmpty ? '请填写模型名称' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _key,
                          obscureText: !_showKey,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: InputDecoration(
                            labelText: 'API 密钥',
                            suffixIcon: IconButton(
                              tooltip: _showKey ? '隐藏密钥' : '显示密钥',
                              onPressed: () =>
                                  setState(() => _showKey = !_showKey),
                              icon: Icon(_showKey
                                  ? CupertinoIcons.eye_slash
                                  : CupertinoIcons.eye),
                            ),
                          ),
                          validator: (value) => (value ?? '').trim().isEmpty
                              ? '请填写 API 密钥'
                              : null,
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                                color: theme.dividerColor.withOpacity(.52)),
                          ),
                          child: Text(
                            '测试连接会发送一条简短消息，可能产生少量费用。使用 AI 功能时，相关记录会发送给你选择的服务商。Android 上的配置由系统密钥库保护，不包含在数据导出中。',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(height: 1.55),
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _saving ? null : _save,
                          child: Text(_saving ? '正在测试连接…' : '测试连接并保存'),
                        ),
                        if (_status != null) ...[
                          const SizedBox(height: 14),
                          Text(_status!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: _connectionOk
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.error,
                                height: 1.5,
                              )),
                        ],
                      ],
                    ),
                  )),
    );
  }
}
