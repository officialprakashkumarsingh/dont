import 'message_model.dart';

class VisionAnalysisMessage extends Message {
  final bool isAnalyzing;
  final String? analysisPrompt;
  final String? analysisResult;

  VisionAnalysisMessage({
    required String id,
    this.isAnalyzing = true,
    this.analysisPrompt,
    this.analysisResult,
    bool hasError = false,
  }) : super(
          id: id,
          content: analysisResult ?? '',
          type: MessageType.assistant,
          timestamp: DateTime.now(),
          isStreaming: isAnalyzing,
          hasError: hasError,
        );

  @override
  Message copyWith({
    String? id,
    String? content,
    MessageType? type,
    DateTime? timestamp,
    bool? isStreaming,
    bool? hasError,
  }) {
    // For VisionAnalysisMessage, we treat content as analysisResult
    return VisionAnalysisMessage(
      id: id ?? this.id,
      isAnalyzing: isStreaming ?? this.isAnalyzing,
      analysisPrompt: analysisPrompt,
      analysisResult: content ?? this.analysisResult,
      hasError: hasError ?? this.hasError,
    );
  }
}