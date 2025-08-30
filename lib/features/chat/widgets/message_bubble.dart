import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/models/message_model.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/models/image_message_model.dart';
import '../../../core/models/vision_message_model.dart';
import '../../../core/models/diagram_message_model.dart';
import '../../../core/models/presentation_message_model.dart';
import '../../../core/models/chart_message_model.dart';
import '../../../core/models/flashcard_message_model.dart';
import '../../../core/models/quiz_message_model.dart';
import '../../../core/models/vision_analysis_message_model.dart';
import '../../../shared/widgets/markdown_message.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/widgets/thinking_animation.dart';
import '../../../shared/widgets/diagram_preview.dart';
import '../../../shared/widgets/presentation_preview.dart';
import '../../../shared/widgets/chart_preview.dart';
import '../../../shared/widgets/flashcard_preview.dart';
import '../../../shared/widgets/quiz_preview.dart';

class MessageBubble extends StatefulWidget {
  final Message message;
  final VoidCallback? onCopy;
  final VoidCallback? onRegenerate;
  final VoidCallback? onExport;
  final String? modelName;
  final String? userMessage;
  final String? aiModel;

  const MessageBubble({
    super.key,
    required this.message,
    this.onCopy,
    this.onRegenerate,
    this.onExport,
    this.modelName,
    this.userMessage,
    this.aiModel,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  bool _showActions = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final GlobalKey _repaintBoundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.message.content));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Message copied to clipboard'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  bool _isExporting = false;

  Future<void> _exportTextAsImage() async {
    if (_isExporting) return;

    setState(() {
      _isExporting = true;
    });

    // Show a loading dialog immediately to provide feedback
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Yield to allow the loading dialog to render before heavy work
      await Future.delayed(const Duration(milliseconds: 100));

      // Get context data
      final userMessage = widget.userMessage ?? '';
      final aiModel = widget.aiModel ?? 'AI Assistant';
      final timestamp = widget.message.timestamp;
      final exportKey = GlobalKey();

      // Render the export widget off-screen to capture it
      // This is the most performance-intensive part
      final RenderRepaintBoundary boundary = await _captureWidget(
        context: context,
        child: _ExportMessageWidget(
          userMessage: userMessage,
          aiMessage: widget.message,
          aiModel: aiModel,
          timestamp: timestamp,
        ),
      );
      
      // Convert boundary to image
      final image = await boundary.toImage(pixelRatio: 4.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData?.buffer.asUint8List();

      if (pngBytes == null) {
        throw Exception('Failed to generate image bytes.');
      }

      // Dismiss the loading dialog
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // Share the generated image
      await _shareImage(pngBytes);
    } catch (e) {
      // Ensure dialog is dismissed on error
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  // Helper to render a widget off-screen and return its boundary
  Future<RenderRepaintBoundary> _captureWidget({
    required BuildContext context,
    required Widget child,
  }) async {
    final GlobalKey key = GlobalKey();
    final completer = Completer<RenderRepaintBoundary>();

    final overlayState = Overlay.of(context);
    OverlayEntry? overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: -2000,
          top: 0,
          child: Material(
            child: Container(
              width: 1800,
              color: Theme.of(context).scaffoldBackgroundColor,
              child: RepaintBoundary(
                key: key,
                child: child,
              ),
            ),
          ),
        );
      },
    );

    overlayState.insert(overlayEntry);

    // Wait for the next frame to ensure the widget is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary != null) {
          completer.complete(boundary);
        } else {
          completer.completeError(Exception('Could not find RenderRepaintBoundary.'));
        }
      } catch (e) {
        completer.completeError(e);
      } finally {
        overlayEntry?.remove();
      }
    });

    return completer.future;
  }
  
  Future<void> _shareImage(Uint8List pngBytes) async {
    // Save to temporary file
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${tempDir.path}/message_$timestamp.png');
    await file.writeAsBytes(pngBytes);

    // Share the image
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Conversation from AhamAI',
    );

    // Clean up after delay
    Future.delayed(const Duration(seconds: 10), () {
      if (file.existsSync()) {
        file.deleteSync();
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Conversation exported as image!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.type == MessageType.user;
    final isStreaming = widget.message.isStreaming;
    final hasError = widget.message.hasError;

    return GestureDetector(
      onTap: () {
        // Haptic feedback on tap
        HapticFeedback.lightImpact();
      },
      onDoubleTap: isUser ? _copyToClipboard : null,
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Message content
          RepaintBoundary(
            key: _repaintBoundaryKey,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.9,
              ),
            padding: isUser
                ? (widget.message is VisionMessage
                    ? const EdgeInsets.symmetric(horizontal: 0, vertical: 8)
                    : const EdgeInsets.symmetric(horizontal: 16, vertical: 12))
                : const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
            decoration: (isUser && widget.message is! VisionMessage)
                ? BoxDecoration(
                    color: _getBubbleColor(context, isUser, hasError),
                    borderRadius: BorderRadius.circular(16).copyWith(
                      bottomRight: const Radius.circular(4),
                    ),
                    border: hasError
                        ? Border.all(
                            color: Theme.of(context).colorScheme.error.withOpacity(0.3),
                            width: 1,
                          )
                        : null,
                  )
                : null, // No decoration for AI messages (transparent)
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image content for image messages
                if (widget.message is ImageMessage) ...[
                  _buildImageContent(widget.message as ImageMessage),
                ] else if (widget.message is VisionMessage) ...[
                  _buildVisionContent(widget.message as VisionMessage),
                ] else if (widget.message is DiagramMessage) ...[
                  _buildDiagramContent(widget.message as DiagramMessage),
                ] else if (widget.message is PresentationMessage) ...[
                  _buildPresentationContent(widget.message as PresentationMessage),
                ] else if (widget.message is ChartMessage) ...[
                  _buildChartContent(widget.message as ChartMessage),
                ] else if (widget.message is FlashcardMessage) ...[
                  _buildFlashcardContent(widget.message as FlashcardMessage),
                ] else if (widget.message is QuizMessage) ...[
                  _buildQuizContent(widget.message as QuizMessage),
                ] else if (widget.message is VisionAnalysisMessage) ...[
                  _buildVisionAnalysisContent(widget.message as VisionAnalysisMessage),
                ] else ...[
                  // Regular message content with markdown support
                  MarkdownMessage(
                    content: widget.message.content,
                    isUser: isUser,
                    isStreaming: isStreaming,
                  ),
                ],
                
                // Streaming indicator - only show if no content yet
                // Don't show for special message types that have their own animations
                if (isStreaming && 
                    widget.message.content.isEmpty &&
                    widget.message is! DiagramMessage &&
                    widget.message is! PresentationMessage &&
                    widget.message is! ChartMessage &&
                    widget.message is! FlashcardMessage &&
                    widget.message is! QuizMessage &&
                    widget.message is! VisionAnalysisMessage) ...[
                  const SizedBox(height: 8),
                  ThinkingAnimation(
                    color: Theme.of(context).colorScheme.primary,
                    size: 8,
                  ),
                ],
              ],
            ),
          ),
        ),

          // Actions - Show different actions based on message type
          if (!isUser && !isStreaming && !hasError)
            Consumer<TtsService>(
              builder: (context, ttsService, child) {
                final isPlaying = ttsService.ttsState == TtsState.playing && ttsService.currentMessageId == widget.message.id;
                return Container(
                  margin: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // For image messages, show export
                      if (widget.message is ImageMessage) ...[
                        if (widget.onExport != null)
                          _ActionButton(
                            icon: CupertinoIcons.cloud_download,
                            onPressed: widget.onExport!,
                          ),
                      ] else if (widget.message is DiagramMessage) ...[
                        // Don't show export here - it's already in the diagram preview
                      ] else if (widget.message is PresentationMessage) ...[
                        // Don't show export here - it's already in the presentation preview
                      ] else if (widget.message is ChartMessage) ...[
                        // Don't show export here - it's already in the chart preview
                      ] else if (widget.message is FlashcardMessage) ...[
                        // Don't show export here - it's already in the flashcard preview
                      ] else if (widget.message is QuizMessage) ...[
                        // Don't show export here - it's already in the quiz preview
                      ] else ...[
                        // For text messages, show all options
                        // Copy - always visible for AI messages
                        if (widget.onCopy != null)
                          _ActionButton(
                            icon: CupertinoIcons.doc_on_doc,
                            onPressed: widget.onCopy!,
                          ),

                        // Read Aloud button
                        const SizedBox(width: 8),
                        _ActionButton(
                          icon: isPlaying ? CupertinoIcons.stop_circle : CupertinoIcons.speaker_2,
                          onPressed: () {
                            if (isPlaying) {
                              ttsService.stop();
                            } else {
                              ttsService.speak(widget.message.content, widget.message.id);
                            }
                          },
                        ),

                        // Regenerate - always visible for AI messages
                        if (widget.onRegenerate != null) ...[
                          const SizedBox(width: 8),
                          _ActionButton(
                            icon: CupertinoIcons.arrow_2_circlepath,
                            onPressed: widget.onRegenerate!,
                          ),
                        ],

                        // Export as Image - always visible for AI messages
                        if (widget.onExport != null) ...[
                          const SizedBox(width: 8),
                          _ActionButton(
                            icon: CupertinoIcons.photo,
                            onPressed: _isExporting ? null : _exportTextAsImage,
                          ),
                        ],
                      ],
                    ],
                  ),
                );
              },
            ),
          

        ],
      ),
    );
  }

  Color _getBubbleColor(BuildContext context, bool isUser, bool hasError) {
    if (hasError) {
      return Theme.of(context).colorScheme.error.withOpacity(0.1);
    }
    if (isUser) {
      return Theme.of(context).colorScheme.primary;
    }
    return Theme.of(context).colorScheme.surfaceVariant;
  }

  Color _getTextColor(BuildContext context, bool isUser, bool hasError) {
    if (hasError) {
      return Theme.of(context).colorScheme.error;
    }
    if (isUser) {
      return Theme.of(context).colorScheme.onPrimary;
    }
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }

  Widget _buildImageContent(ImageMessage imageMessage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Prompt text
        Text(
          'Image: ${imageMessage.prompt}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Model name
        Text(
          'Model: ${imageMessage.model}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        
        const SizedBox(height: 12),
        
                // Image or loading state
        if (imageMessage.isGenerating)
          _ImageGenerationShimmer()
        else if (imageMessage.imageUrl.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _buildImageWidget(imageMessage.imageUrl),
          ),
      ],
    );
  }

  Widget _buildImageWidget(String imageUrl) {
    // Handle data URLs (base64 encoded images)
    if (imageUrl.startsWith('data:image/')) {
      try {
        final base64Data = imageUrl.split(',')[1];
        final bytes = base64Decode(base64Data);
        return Image.memory(
          bytes,
          width: 280,
          height: 280,
          fit: BoxFit.cover,
          gaplessPlayback: true, // Prevent blinking
          errorBuilder: (context, error, stackTrace) {
            return _buildImageError();
          },
        );
      } catch (e) {
        return _buildImageError();
      }
    }
    
    // Handle regular network URLs with caching
    return Image.network(
      imageUrl,
      width: 200,
      height: 200,
      fit: BoxFit.cover,
      gaplessPlayback: true, // Prevent blinking during rebuild
      cacheWidth: 400, // Cache at reasonable resolution
      cacheHeight: 400,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: 280,
          height: 280,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / 
                    loadingProgress.expectedTotalBytes!
                  : null,
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return _buildImageError();
      },
    );
  }

  Widget _buildImageError() {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            'Failed to load',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisionContent(VisionMessage visionMessage) {
    final isUser = visionMessage.type == MessageType.user;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isUser) ...[
          // Show the uploaded image for user messages
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _buildUploadedImage(visionMessage.imageData),
          ),
          const SizedBox(height: 12),
          // Show the user's question
          Text(
            visionMessage.analysisPrompt,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ] else ...[
          // For AI responses, show the analysis result
          MarkdownMessage(
            content: visionMessage.content,
            isUser: false,
            isStreaming: false,
          ),
        ],
      ],
    );
  }

  Widget _buildDiagramContent(DiagramMessage diagramMessage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show the prompt
        if (diagramMessage.prompt.isNotEmpty) ...[
          Text(
            'Diagram: ${diagramMessage.prompt}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
        ],
        
        // Show the diagram preview
        if (diagramMessage.isStreaming)
          _ContentGenerationShimmer(featureName: 'Diagram')
        else if (diagramMessage.mermaidCode.isNotEmpty)
          DiagramPreview(
            mermaidCode: diagramMessage.mermaidCode,
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Failed to generate diagram. Please try again.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPresentationContent(PresentationMessage presentationMessage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show the prompt
        if (presentationMessage.prompt.isNotEmpty) ...[
          Text(
            'Presentation: ${presentationMessage.prompt}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
        ],
        
        // Show the presentation preview
        if (presentationMessage.isStreaming)
          _ContentGenerationShimmer(featureName: 'Presentation')
        else if (presentationMessage.slides.isNotEmpty)
          PresentationPreview(
            slides: presentationMessage.slides,
            title: presentationMessage.prompt,
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Failed to generate presentation slides',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }

  Widget _buildChartContent(ChartMessage chartMessage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show the prompt
        if (chartMessage.prompt.isNotEmpty) ...[
          Text(
            'Chart: ${chartMessage.prompt}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
        ],
        
        // Show the chart preview
        if (chartMessage.chartConfig.isNotEmpty)
          ChartPreview(
            chartConfig: chartMessage.chartConfig,
            prompt: chartMessage.prompt,
          )
        else if (chartMessage.isStreaming)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Failed to generate chart',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFlashcardContent(FlashcardMessage flashcardMessage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show the prompt
        if (flashcardMessage.prompt.isNotEmpty) ...[
          Text(
            'Flashcards: ${flashcardMessage.prompt}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
        ],
        
        // Show the flashcard preview
        if (flashcardMessage.flashcards.isNotEmpty)
          FlashcardPreview(
            flashcards: flashcardMessage.flashcards,
            title: flashcardMessage.prompt,
          )
        else if (flashcardMessage.isStreaming)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Failed to generate flashcards',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildQuizContent(QuizMessage quizMessage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show the prompt
        if (quizMessage.prompt.isNotEmpty) ...[
          Text(
            'Quiz: ${quizMessage.prompt}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
        ],
        
        // Show the quiz preview
        if (quizMessage.questions.isNotEmpty)
          QuizPreview(
            questions: quizMessage.questions,
            title: quizMessage.prompt,
          )
        else if (quizMessage.isStreaming)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Failed to generate quiz',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildUploadedImage(String imageData) {
    // Use a stateful widget to decode the image only once.
    return _DecodedImage(imageData: imageData);
  }

  Widget _buildVisionAnalysisContent(VisionAnalysisMessage message) {
    if (message.isAnalyzing) {
      return _VisionAnalysisShimmer();
    } else {
      return MarkdownMessage(
        content: message.content,
        isUser: false,
      );
    }
  }
}

// A stateful widget to decode and display a base64 image once.
class _DecodedImage extends StatefulWidget {
  final String imageData;

  const _DecodedImage({required this.imageData});

  @override
  _DecodedImageState createState() => _DecodedImageState();
}

class _DecodedImageState extends State<_DecodedImage> {
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    _decodeImage();
  }

  void _decodeImage() {
    try {
      final base64Data = widget.imageData.split(',')[1];
      _imageBytes = base64Decode(base64Data);
    } catch (e) {
      // If decoding fails, _imageBytes will remain null
      print('Error decoding base64 image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_imageBytes == null) {
      return Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            'Invalid image data',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
      );
    }

    return Image.memory(
      _imageBytes!,
      width: 200,
      height: 200,
      fit: BoxFit.cover,
      gaplessPlayback: true, // Helps prevent blinking
    );
  }
}

class _ContentGenerationShimmer extends StatelessWidget {
  final String featureName;

  const _ContentGenerationShimmer({required this.featureName});

  @override
  Widget build(BuildContext context) {
    return _ImageGenerationShimmer(featureName: featureName);
  }
}

class _ImageGenerationShimmer extends StatefulWidget {
  final String featureName;

  const _ImageGenerationShimmer({this.featureName = 'Image'});

  @override
  _ImageGenerationShimmerState createState() => _ImageGenerationShimmerState();
}

class _ImageGenerationShimmerState extends State<_ImageGenerationShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
    
    _shimmerAnimation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.linear,
    ));
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          width: 280,
          height: 280,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.surfaceVariant.withOpacity(0.3),
                theme.colorScheme.surfaceVariant.withOpacity(0.5),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Shimmer effect overlay
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CustomPaint(
                    painter: _ShimmerPainter(
                      shimmerPosition: _shimmerAnimation.value,
                      baseColor: theme.colorScheme.surfaceVariant,
                      shimmerColor: theme.colorScheme.primary.withOpacity(0.1),
                    ),
                  ),
                ),
              ),
              // Center content
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.primary.withOpacity(0.1),
                      ),
                      child: Icon(
                        Icons.auto_awesome,
                        size: 32,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Creating ${widget.featureName}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Progress dots
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(3, (index) {
                        final delay = index * 0.2;
                        final opacity = (((_shimmerAnimation.value - delay) % 1.0) * 2)
                            .clamp(0.3, 1.0);
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.primary.withOpacity(opacity),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  final double shimmerPosition;
  final Color baseColor;
  final Color shimmerColor;

  _ShimmerPainter({
    required this.shimmerPosition,
    required this.baseColor,
    required this.shimmerColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment(-1.0 + shimmerPosition * 2, -1.0 + shimmerPosition * 2),
        end: Alignment(-0.5 + shimmerPosition * 2, -0.5 + shimmerPosition * 2),
        colors: [
          baseColor,
          shimmerColor,
          shimmerColor,
          baseColor,
        ],
        stops: const [0.0, 0.45, 0.55, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(_ShimmerPainter oldDelegate) {
    return oldDelegate.shimmerPosition != shimmerPosition;
  }
}

class _VisionAnalysisShimmer extends StatefulWidget {
  @override
  _VisionAnalysisShimmerState createState() => _VisionAnalysisShimmerState();
}

class _VisionAnalysisShimmerState extends State<_VisionAnalysisShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
    
    _shimmerAnimation = Tween<double>(
      begin: -2.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.linear,
    ));
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          width: 280,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Simple shimmer bars like image generation
              ...List.generate(3, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    height: 8,
                    width: 150 + (index * 30),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: theme.colorScheme.surfaceVariant,
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ),
    );
  }
}

class _ExportMessageWidget extends StatelessWidget {
  final String userMessage;
  final Message aiMessage;
  final String aiModel;
  final DateTime timestamp;
  
  const _ExportMessageWidget({
    required this.userMessage,
    required this.aiMessage,
    required this.aiModel,
    required this.timestamp,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeFormat = '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    final dateFormat = '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    
    return Container(
      padding: const EdgeInsets.all(20),
      color: theme.scaffoldBackgroundColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with AhamAI branding
          Center(
            child: Column(
              children: [
                // AhamAI logo with proper font
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'अहम्',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onBackground,
                        ),
                      ),
                      TextSpan(
                        text: 'AI',
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateFormat,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onBackground.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // User message
          if (userMessage.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_outline,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'You',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onBackground.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            timeFormat,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: theme.colorScheme.onBackground.withOpacity(0.4),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        userMessage,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onBackground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
          
          // AI response
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    'AI',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Assistant',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onBackground.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeFormat,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            color: theme.colorScheme.onBackground.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    MarkdownMessage(
                      content: aiMessage.content,
                      isUser: false,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
