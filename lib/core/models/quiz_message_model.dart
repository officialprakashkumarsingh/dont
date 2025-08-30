import 'message_model.dart';

class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctAnswer; // Index of correct option
  final String? explanation;

  QuizQuestion({
    required this.question,
    required this.options,
    required this.correctAnswer,
    this.explanation,
  });

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'options': options,
      'correctAnswer': correctAnswer,
      if (explanation != null) 'explanation': explanation,
    };
  }

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      question: json['question'] as String,
      options: List<String>.from(json['options'] as List),
      correctAnswer: json['correctAnswer'] as int,
      explanation: json['explanation'] as String?,
    );
  }
}

class QuizMessage extends Message {
  final String prompt;
  final List<QuizQuestion> questions;

  QuizMessage({
    required super.id,
    required this.prompt,
    required this.questions,
    required super.timestamp,
    super.isStreaming = false,
    super.hasError = false,
  }) : super(
          content: questions.map((q) => 
            '${q.question}\n${q.options.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}'
          ).join('\n\n'),
          type: MessageType.assistant,
        );

  factory QuizMessage.generating(String prompt) {
    return QuizMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString() + '_quiz',
      prompt: prompt,
      questions: [],
      timestamp: DateTime.now(),
      isStreaming: true,
    );
  }

  @override
  QuizMessage copyWith({
    String? id,
    String? content,
    MessageType? type,
    DateTime? timestamp,
    bool? isStreaming,
    bool? hasError,
    String? prompt,
    List<QuizQuestion>? questions,
  }) {
    return QuizMessage(
      id: id ?? this.id,
      prompt: prompt ?? this.prompt,
      questions: questions ?? this.questions,
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
      'questions': questions.map((q) => q.toJson()).toList(),
    };
  }

  factory QuizMessage.fromJson(Map<String, dynamic> json, Map<String, dynamic> metadata) {
    return QuizMessage(
      id: json['id'],
      prompt: metadata['prompt'] ?? '',
      questions: (metadata['questions'] as List? ?? [])
          .map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>))
          .toList(),
      timestamp: DateTime.parse(json['created_at']),
      isStreaming: false,
      hasError: json['hasError'] ?? false,
    );
  }
}