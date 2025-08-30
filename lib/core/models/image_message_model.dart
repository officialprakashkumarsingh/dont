import 'message_model.dart';

class ImageMessage extends Message {
  final String imageUrl;
  final String prompt;
  final String model;
  final bool isGenerating;

  const ImageMessage({
    required super.id,
    required super.content,
    required super.type,
    required super.timestamp,
    required this.imageUrl,
    required this.prompt,
    required this.model,
    this.isGenerating = false,
    super.isStreaming = false,
    super.hasError = false,
  });

  @override
  ImageMessage copyWith({
    String? id,
    String? content,
    MessageType? type,
    DateTime? timestamp,
    bool? isStreaming,
    bool? hasError,
    String? imageUrl,
    String? prompt,
    String? model,
    bool? isGenerating,
  }) {
    return ImageMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
      hasError: hasError ?? this.hasError,
      imageUrl: imageUrl ?? this.imageUrl,
      prompt: prompt ?? this.prompt,
      model: model ?? this.model,
      isGenerating: isGenerating ?? this.isGenerating,
    );
  }

  factory ImageMessage.generating(String prompt, String model) {
    return ImageMessage(
      id: 'image_${DateTime.now().millisecondsSinceEpoch}',
      content: 'Generating image: $prompt',
      type: MessageType.assistant,
      timestamp: DateTime.now(),
      imageUrl: '',
      prompt: prompt,
      model: model,
      isGenerating: true,
    );
  }

  factory ImageMessage.completed(String prompt, String model, String imageUrl) {
    return ImageMessage(
      id: 'image_${DateTime.now().millisecondsSinceEpoch}',
      content: 'Generated image: $prompt',
      type: MessageType.assistant,
      timestamp: DateTime.now(),
      imageUrl: imageUrl,
      prompt: prompt,
      model: model,
      isGenerating: false,
    );
  }

  factory ImageMessage.error(String prompt, String model, String error) {
    return ImageMessage(
      id: 'image_${DateTime.now().millisecondsSinceEpoch}',
      content: 'Failed to generate image: $error',
      type: MessageType.assistant,
      timestamp: DateTime.now(),
      imageUrl: '',
      prompt: prompt,
      model: model,
      isGenerating: false,
      hasError: true,
    );
  }

  factory ImageMessage.fromJson(Map<String, dynamic> json, Map<String, dynamic> metadata) {
    return ImageMessage(
      id: json['id'],
      content: json['content'],
      type: MessageType.assistant, // Image messages are always from assistant
      timestamp: DateTime.parse(json['created_at']),
      imageUrl: metadata['imageUrl'] ?? '',
      prompt: metadata['prompt'] ?? '',
      model: metadata['model'] ?? '',
    );
  }
}