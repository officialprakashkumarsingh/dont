import 'message_model.dart';

class VisionMessage extends Message {
  final String imageData;
  final String analysisPrompt;
  final String? model;

  const VisionMessage({
    required super.id,
    required super.content,
    required super.type,
    required super.timestamp,
    required this.imageData,
    required this.analysisPrompt,
    this.model,
    super.isStreaming = false,
    super.hasError = false,
  });

  @override
  VisionMessage copyWith({
    String? id,
    String? content,
    MessageType? type,
    DateTime? timestamp,
    bool? isStreaming,
    bool? hasError,
    String? model,
    String? imageData,
    String? analysisPrompt,
  }) {
    return VisionMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
      hasError: hasError ?? this.hasError,
      model: model ?? this.model,
      imageData: imageData ?? this.imageData,
      analysisPrompt: analysisPrompt ?? this.analysisPrompt,
    );
  }

  // Factory constructor for user vision message
  factory VisionMessage.user({
    required String prompt,
    required String imageData,
    String? model,
  }) {
    return VisionMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: prompt,
      type: MessageType.user,
      timestamp: DateTime.now(),
      imageData: imageData,
      analysisPrompt: prompt,
      model: model,
    );
  }

  // Factory constructor for assistant vision response
  factory VisionMessage.assistant({
    required String response,
    required String originalPrompt,
    required String imageData,
    String? model,
  }) {
    return VisionMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: response,
      type: MessageType.assistant,
      timestamp: DateTime.now(),
      imageData: imageData,
      analysisPrompt: originalPrompt,
      model: model,
    );
  }

  @override
  String toString() {
    return 'VisionMessage(id: $id, type: $type, content: ${content.length > 50 ? '${content.substring(0, 50)}...' : content}, hasImage: ${imageData.isNotEmpty})';
  }

  factory VisionMessage.fromJson(Map<String, dynamic> json, Map<String, dynamic> metadata) {
    return VisionMessage(
      id: json['id'],
      content: json['content'],
      type: MessageType.user, // Vision messages are always from user
      timestamp: DateTime.parse(json['created_at']),
      imageData: metadata['imageData'] ?? '',
      analysisPrompt: metadata['prompt'] ?? json['content'],
      model: metadata['model'],
    );
  }
}