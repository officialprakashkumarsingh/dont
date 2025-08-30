import 'message_model.dart';

class FileUploadMessage extends Message {
  final List<String> fileNames;
  final String actualContent; // The extracted content for AI
  
  FileUploadMessage({
    required String id,
    required this.fileNames,
    required this.actualContent,
    required DateTime timestamp,
  }) : super(
          id: id,
          content: '📎 Files uploaded: ${fileNames.join(', ')}', // Display content
          type: MessageType.user,
          timestamp: timestamp,
        );
  
  // Override to provide actual content for AI processing
  String get aiContent => actualContent;
  
  @override
  Map<String, String> toApiFormat() {
    return {
      'role': 'user',
      'content': actualContent, // Send actual content to AI
    };
  }
}