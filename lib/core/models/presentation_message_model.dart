import 'message_model.dart';

class PresentationMessage extends Message {
  final String prompt;
  final List<PresentationSlide> slides;
  
  PresentationMessage({
    required String id,
    required this.prompt,
    required this.slides,
    required DateTime timestamp,
    bool isStreaming = false,
    bool hasError = false,
  }) : super(
    id: id,
    content: _slidesToMarkdown(slides),
    type: MessageType.assistant,
    timestamp: timestamp,
    isStreaming: isStreaming,
    hasError: hasError,
  );
  
  PresentationMessage.user({
    required this.prompt,
    this.slides = const [],
  }) : super(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    content: prompt,
    type: MessageType.user,
    timestamp: DateTime.now(),
  );
  
  PresentationMessage.assistant({
    required this.prompt,
    required this.slides,
  }) : super(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    content: _slidesToMarkdown(slides),
    type: MessageType.assistant,
    timestamp: DateTime.now(),
  );

  factory PresentationMessage.generating(String prompt) {
    return PresentationMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString() + '_presentation',
      prompt: prompt,
      slides: [],
      timestamp: DateTime.now(),
      isStreaming: true,
    );
  }
  
  static String _slidesToMarkdown(List<PresentationSlide> slides) {
    final buffer = StringBuffer();
    for (int i = 0; i < slides.length; i++) {
      if (i > 0) buffer.writeln('\n---\n');
      buffer.writeln('## ${slides[i].title}');
      buffer.writeln();
      buffer.writeln(slides[i].content);
    }
    return buffer.toString();
  }
  
  @override
  PresentationMessage copyWith({
    String? id,
    String? content,
    MessageType? type,
    DateTime? timestamp,
    bool? isStreaming,
    bool? hasError,
    String? prompt,
    List<PresentationSlide>? slides,
  }) {
    return PresentationMessage(
      id: id ?? this.id,
      prompt: prompt ?? this.prompt,
      slides: slides ?? this.slides,
      timestamp: timestamp ?? this.timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
      hasError: hasError ?? this.hasError,
    );
  }

  factory PresentationMessage.fromJson(Map<String, dynamic> json, Map<String, dynamic> metadata) {
    return PresentationMessage.assistant(
      prompt: metadata['prompt'] ?? '',
      slides: (metadata['slides'] as List? ?? [])
          .map((s) => PresentationSlide.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PresentationSlide {
  final String title;
  final String content;
  final List<String>? bulletPoints;
  final String? imageUrl;
  final String? notes;
  
  const PresentationSlide({
    required this.title,
    required this.content,
    this.bulletPoints,
    this.imageUrl,
    this.notes,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'content': content,
      'bulletPoints': bulletPoints,
      'imageUrl': imageUrl,
      'notes': notes,
    };
  }
  
  factory PresentationSlide.fromJson(Map<String, dynamic> json) {
    return PresentationSlide(
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      bulletPoints: json['bulletPoints'] != null 
          ? List<String>.from(json['bulletPoints'])
          : null,
      imageUrl: json['imageUrl'],
      notes: json['notes'],
    );
  }
}