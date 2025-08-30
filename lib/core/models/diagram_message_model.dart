import 'message_model.dart';

class DiagramMessage extends Message {
  final String prompt;
  final String mermaidCode;
  
  DiagramMessage({
    required String id,
    required this.prompt,
    required this.mermaidCode,
    required DateTime timestamp,
    bool isStreaming = false,
    bool hasError = false,
  }) : super(
    id: id,
    content: mermaidCode,
    type: MessageType.assistant,
    timestamp: timestamp,
    isStreaming: isStreaming,
    hasError: hasError,
  );
  
  DiagramMessage.user({
    required this.prompt,
    this.mermaidCode = '',
  }) : super(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    content: prompt,
    type: MessageType.user,
    timestamp: DateTime.now(),
  );
  
  DiagramMessage.assistant({
    required this.prompt,
    required this.mermaidCode,
  }) : super(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    content: mermaidCode,
    type: MessageType.assistant,
    timestamp: DateTime.now(),
  );

  factory DiagramMessage.generating(String prompt) {
    return DiagramMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString() + '_diagram',
      prompt: prompt,
      mermaidCode: '',
      timestamp: DateTime.now(),
      isStreaming: true,
    );
  }
  
  @override
  DiagramMessage copyWith({
    String? id,
    String? content,
    MessageType? type,
    DateTime? timestamp,
    bool? isStreaming,
    bool? hasError,
    String? prompt,
    String? mermaidCode,
  }) {
    return DiagramMessage(
      id: id ?? this.id,
      prompt: prompt ?? this.prompt,
      mermaidCode: (content != null && content != this.content) 
          ? content  // If content is explicitly changed, use it as mermaidCode
          : (mermaidCode ?? this.mermaidCode),
      timestamp: timestamp ?? this.timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
      hasError: hasError ?? this.hasError,
    );
  }

  factory DiagramMessage.fromJson(Map<String, dynamic> json, Map<String, dynamic> metadata) {
    return DiagramMessage(
      id: json['id'],
      prompt: metadata['prompt'] ?? '',
      mermaidCode: metadata['mermaidCode'] ?? '',
      timestamp: DateTime.parse(json['created_at']),
      isStreaming: false,
      hasError: json['hasError'] ?? false,
    );
  }
}