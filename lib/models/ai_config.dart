/// AI 入口模式
enum AiEntryMode {
  tab,       // 底部 Tab 独立页面
  floating,  // 悬浮球
  sidebar,   // 侧边栏
}

/// AI 助手配置
class AiConfig {
  final String endpoint;    // e.g. https://api.openai.com/v1
  final String apiKey;
  final String model;       // e.g. gpt-4o-mini
  final AiEntryMode entryMode;

  const AiConfig({
    this.endpoint = 'https://api.openai.com/v1',
    this.apiKey = '',
    this.model = 'gpt-4o-mini',
    this.entryMode = AiEntryMode.tab,
  });

  AiConfig copyWith({
    String? endpoint,
    String? apiKey,
    String? model,
    AiEntryMode? entryMode,
  }) {
    return AiConfig(
      endpoint: endpoint ?? this.endpoint,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      entryMode: entryMode ?? this.entryMode,
    );
  }

  bool get isValid => endpoint.isNotEmpty && apiKey.isNotEmpty && model.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'endpoint': endpoint,
    'apiKey': apiKey,
    'model': model,
    'entryMode': entryMode.name,
  };

  factory AiConfig.fromJson(Map<String, dynamic> json) => AiConfig(
    endpoint: json['endpoint'] as String? ?? 'https://api.openai.com/v1',
    apiKey: json['apiKey'] as String? ?? '',
    model: json['model'] as String? ?? 'gpt-4o-mini',
    entryMode: AiEntryMode.values.firstWhere(
      (e) => e.name == json['entryMode'],
      orElse: () => AiEntryMode.tab,
    ),
  );
}
