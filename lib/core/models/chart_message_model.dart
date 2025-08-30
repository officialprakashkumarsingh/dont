import 'message_model.dart';

class ChartMessage extends Message {
  final String prompt;
  final String chartConfig;
  final String chartType;

  ChartMessage({
    required super.id,
    required this.prompt,
    required this.chartConfig,
    this.chartType = 'bar',
    required super.timestamp,
    super.isStreaming = false,
    super.hasError = false,
  }) : super(
          content: chartConfig,
          type: MessageType.assistant,
        );

  factory ChartMessage.generating(String prompt) {
    return ChartMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString() + '_chart',
      prompt: prompt,
      chartConfig: '',
      timestamp: DateTime.now(),
      isStreaming: true,
    );
  }

  @override
  ChartMessage copyWith({
    String? id,
    String? content,
    MessageType? type,
    DateTime? timestamp,
    bool? isStreaming,
    bool? hasError,
    String? prompt,
    String? chartConfig,
    String? chartType,
  }) {
    return ChartMessage(
      id: id ?? this.id,
      prompt: prompt ?? this.prompt,
      chartConfig: (content != null && content != this.content)
          ? content
          : (chartConfig ?? this.chartConfig),
      chartType: chartType ?? this.chartType,
      timestamp: timestamp ?? this.timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
      hasError: hasError ?? this.hasError,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'type': type.toString(),
      'timestamp': timestamp.toIso8601String(),
      'isStreaming': isStreaming,
      'hasError': hasError,
      'prompt': prompt,
      'chartConfig': chartConfig,
      'chartType': chartType,
    };
  }

  factory ChartMessage.fromJson(Map<String, dynamic> json, Map<String, dynamic> metadata) {
    return ChartMessage(
      id: json['id'],
      prompt: metadata['prompt'] ?? '',
      chartConfig: metadata['chartConfig'] ?? '',
      chartType: metadata['chartType'] ?? 'bar',
      timestamp: DateTime.parse(json['created_at']),
      isStreaming: false,
      hasError: json['hasError'] ?? false,
    );
  }
}