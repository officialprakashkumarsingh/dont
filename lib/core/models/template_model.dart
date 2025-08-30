class MessageTemplate {
  final String id;
  final String title;
  final String content;
  final String category;
  final String shortcut;
  final bool isBuiltIn;
  final DateTime createdAt;

  const MessageTemplate({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.shortcut,
    this.isBuiltIn = false,
    required this.createdAt,
  });

  factory MessageTemplate.fromJson(Map<String, dynamic> json) {
    return MessageTemplate(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      category: json['category'] as String,
      shortcut: json['shortcut'] as String,
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'category': category,
      'shortcut': shortcut,
      'isBuiltIn': isBuiltIn,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  MessageTemplate copyWith({
    String? id,
    String? title,
    String? content,
    String? category,
    String? shortcut,
    bool? isBuiltIn,
    DateTime? createdAt,
  }) {
    return MessageTemplate(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      shortcut: shortcut ?? this.shortcut,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MessageTemplate && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}