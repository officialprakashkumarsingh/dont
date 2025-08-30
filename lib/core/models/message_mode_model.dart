class MessageMode {
  final String id;
  final String name;
  final String description;
  final String systemPrompt;
  final String icon;
  final bool isBuiltIn;

  const MessageMode({
    required this.id,
    required this.name,
    required this.description,
    required this.systemPrompt,
    required this.icon,
    this.isBuiltIn = true,
  });

  factory MessageMode.fromJson(Map<String, dynamic> json) {
    return MessageMode(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      systemPrompt: json['systemPrompt'] as String,
      icon: json['icon'] as String,
      isBuiltIn: json['isBuiltIn'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'systemPrompt': systemPrompt,
      'icon': icon,
      'isBuiltIn': isBuiltIn,
    };
  }

  MessageMode copyWith({
    String? id,
    String? name,
    String? description,
    String? systemPrompt,
    String? icon,
    bool? isBuiltIn,
  }) {
    return MessageMode(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      icon: icon ?? this.icon,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MessageMode && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}