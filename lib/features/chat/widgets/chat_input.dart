import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/services/speech_service.dart';

import '../../../core/services/prompt_enhancer_service.dart';
import '../../../core/services/ad_service.dart';
import '../../../core/services/pdf_service.dart';
import '../../../shared/widgets/prompt_enhancer.dart';

class ChatInput extends StatefulWidget {
  final TextEditingController? controller;
  final Function(String) onSendMessage;
  final Function(List<String>, String)? onFileUpload; // New callback for file uploads
  final Function(String)? onGenerateImage;
  final Function(String)? onGenerateDiagram;
  final Function(String)? onGeneratePresentation;
  final Function(String)? onGenerateChart;
  final Function(String)? onGenerateFlashcards;
  final Function(String)? onGenerateQuiz;
  final Function(String, String)? onVisionAnalysis;
  final VoidCallback? onStopStreaming;
  final VoidCallback? onTemplateRequest;
  final String selectedModel;
  final bool isLoading;
  final bool enabled;

  const ChatInput({
    super.key,
    this.controller,
    required this.onSendMessage,
    this.onFileUpload,
    this.onGenerateImage,
    this.onGenerateDiagram,
    this.onGeneratePresentation,
    this.onGenerateChart,
    this.onGenerateFlashcards,
    this.onGenerateQuiz,
    this.onVisionAnalysis,
    this.onStopStreaming,
    this.onTemplateRequest,
    this.selectedModel = '',
    this.isLoading = false,
    this.enabled = true,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> with TickerProviderStateMixin {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  bool _canSend = false;
  bool _shouldDisposeController = false;
  bool _showEnhancerSuggestion = false;
  bool _imageGenerationMode = false;
  bool _diagramGenerationMode = false;
  bool _presentationGenerationMode = false;
  bool _chartGenerationMode = false;
  bool _flashcardGenerationMode = false;
  bool _quizGenerationMode = false;
  String? _pendingImageData;
  Timer? _typingTimer;
  
  // Animation scales for buttons
  double _extensionsButtonScale = 1.0;
  double _micButtonScale = 1.0;
  double _sendButtonScale = 1.0;

  // Hidden file content storage
  String _hiddenFileContent = '';
  List<String> _uploadedFileNames = [];

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = TextEditingController();
      _shouldDisposeController = true;
    }
    _controller.addListener(_updateSendButton);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    if (_shouldDisposeController) {
      _controller.dispose();
    }
    _focusNode.dispose();
    super.dispose();
  }

  void _updateSendButton() {
    final canSend = _controller.text.trim().isNotEmpty && 
                   widget.enabled && 
                   !widget.isLoading;
    if (canSend != _canSend) {
      setState(() {
        _canSend = canSend;
      });
    }
  }

  void _startEnhancerTimer() {
    _typingTimer?.cancel();
    
    if (widget.selectedModel.isNotEmpty) {
      _typingTimer = Timer(const Duration(seconds: 10), () {
        if (mounted && _focusNode.hasFocus) {
          final text = _controller.text.trim();
          if (text.isNotEmpty && PromptEnhancerService.shouldSuggestEnhancement(text)) {
            setState(() {
              _showEnhancerSuggestion = true;
            });
          }
        }
      });
    }
  }

  void _onInputTapped() {
    setState(() {
      _showEnhancerSuggestion = false;
    });
    _startEnhancerTimer();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      _startEnhancerTimer();
    } else {
      _typingTimer?.cancel();
      setState(() {
        _showEnhancerSuggestion = false;
      });
    }
  }

  void _handleSend() {
    if (!_canSend) return;
    
    String message = _controller.text.trim();
    if (message.isEmpty) return;

    _controller.clear();
    _updateSendButton();
    
    // If there's hidden file content, use the file upload callback
    if (_hiddenFileContent.isNotEmpty && widget.onFileUpload != null) {
      // Use the file upload callback to send both file names and content
      widget.onFileUpload!(_uploadedFileNames, _hiddenFileContent);
      
      // Clear hidden content after sending
      _hiddenFileContent = '';
      _uploadedFileNames = [];
    } else if (_pendingImageData != null && widget.onVisionAnalysis != null) {
      // Check if there's pending image data for vision analysis
      widget.onVisionAnalysis!(message, _pendingImageData!);
      _pendingImageData = null; // Clear after use
    } else {
      widget.onSendMessage(message);
    }
    
    HapticFeedback.lightImpact();
  }

  void _handleStop() {
    if (widget.onStopStreaming != null) {
      widget.onStopStreaming!();
      HapticFeedback.mediumImpact();
    }
  }

  void _showPromptEnhancer() {
    final originalPrompt = _controller.text.trim();
    if (originalPrompt.isEmpty) return;

    setState(() {
      _showEnhancerSuggestion = false;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: PromptEnhancer(
          originalPrompt: originalPrompt,
          selectedModel: widget.selectedModel,
          onEnhanced: (enhancedPrompt) {
            _controller.text = enhancedPrompt;
            Navigator.pop(context);
            HapticFeedback.lightImpact();
          },
          onCancel: () {
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Input area - completely transparent
        Container(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: SafeArea(
            child: Row(
              children: [
                // Extensions button with animation
                GestureDetector(
                  onTapDown: (_) => setState(() => _extensionsButtonScale = 0.85),
                  onTapUp: (_) {
                    setState(() => _extensionsButtonScale = 1.0);
                    _showExtensionsSheet();
                  },
                  onTapCancel: () => setState(() => _extensionsButtonScale = 1.0),
                  child: AnimatedScale(
                    scale: _extensionsButtonScale,
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOutCubic,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          child: Icon(
                            Icons.extension_outlined,
                            color: _isAnyExtensionActive()
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            size: 24,
                          ),
                        ),
                        if (_isAnyExtensionActive())
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: _clearAllExtensions,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.error,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close,
                                  size: 10,
                                  color: Theme.of(context).colorScheme.onError,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                
                // Text input - no background
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    enabled: widget.enabled,
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.newline,
                    onTap: _onInputTapped,
                    decoration: InputDecoration(
                      hintText: widget.enabled
                          ? (_pendingImageData != null
                              ? '📸 Ask something about the uploaded image...'
                              : _imageGenerationMode
                                  ? 'Describe the image you want to generate...'
                                  : _diagramGenerationMode
                                      ? 'Describe the diagram you want to create...'
                                      : _presentationGenerationMode
                                          ? 'Describe the presentation topic...'
                                          : _chartGenerationMode
                                              ? 'Describe the chart or graph you want...'
                                              : _flashcardGenerationMode
                                                  ? 'What topic for flashcards?'
                                                  : _quizGenerationMode
                                                      ? 'What topic for the quiz?'
                      : 'Type your message...')
                          : 'Select a model to start chatting',
                      hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    style: Theme.of(context).textTheme.bodyMedium,
                    onSubmitted: (_) => _handleSend(),
                  ),
                ),

                // Mic button with animation
                Consumer<SpeechService>(
                  builder: (context, speechService, child) {
                    return GestureDetector(
                      onTapDown: (_) => setState(() => _micButtonScale = 0.85),
                      onTapUp: (_) {
                        setState(() => _micButtonScale = 1.0);
                        _handleSpeechToText(speechService);
                      },
                      onTapCancel: () => setState(() => _micButtonScale = 1.0),
                      child: AnimatedScale(
                        scale: _micButtonScale,
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeOutCubic,
                        child: Container(
                          width: 48,
                          height: 48,
                          child: Icon(
                            speechService.isListening ? CupertinoIcons.mic_fill : CupertinoIcons.mic,
                            color: speechService.isListening
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(width: 12),
                
                // Send/Stop button with animation
                GestureDetector(
                  onTapDown: (_) {
                    if (widget.isLoading || _canSend) {
                      setState(() => _sendButtonScale = 0.85);
                    }
                  },
                  onTapUp: (_) {
                    setState(() => _sendButtonScale = 1.0);
                    final action = widget.isLoading
                        ? _handleStop
                        : (_canSend 
                            ? (_imageGenerationMode
                                ? _handleImageGenerationDirect
                                : (_diagramGenerationMode
                                    ? _handleDiagramGenerationDirect
                                    : (_presentationGenerationMode
                                        ? _handlePresentationGenerationDirect
                                        : (_chartGenerationMode
                                            ? _handleChartGenerationDirect
                                            : (_flashcardGenerationMode
                                                ? _handleFlashcardGenerationDirect
                                                : (_quizGenerationMode
                                                    ? _handleQuizGenerationDirect
                                                    : _handleSend))))))
                            : null);
                    if (action != null) {
                      action();
                    }
                  },
                  onTapCancel: () => setState(() => _sendButtonScale = 1.0),
                  child: AnimatedScale(
                    scale: _sendButtonScale,
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOutCubic,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOutCubic,
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: widget.isLoading
                            ? Colors.red
                            : (_canSend
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outline.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Center(
                        child: Icon(
                          _getButtonIcon(),
                          color: _getButtonIconColor(context),
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _handleImageGeneration() {
    // This method is no longer used as popup is removed
  }

  void _handleImageGenerationDirect() {
    final prompt = _controller.text.trim();
    if (prompt.isNotEmpty && widget.onGenerateImage != null) {
      widget.onGenerateImage!(prompt);
      _controller.clear();
      // Keep mode active - user must manually turn it off
      _updateSendButton();
      HapticFeedback.lightImpact();
    }
  }

  void _handleDiagramGenerationDirect() {
    final prompt = _controller.text.trim();
    if (prompt.isNotEmpty && widget.onGenerateDiagram != null) {
      widget.onGenerateDiagram!(prompt);
      _controller.clear();
      // Keep mode active - user must manually turn it off
      _updateSendButton();
      HapticFeedback.lightImpact();
    }
  }

  void _handlePresentationGenerationDirect() {
    final prompt = _controller.text.trim();
    if (prompt.isNotEmpty && widget.onGeneratePresentation != null) {
      widget.onGeneratePresentation!(prompt);
      _controller.clear();
      // Keep mode active - user must manually turn it off
      _updateSendButton();
      HapticFeedback.lightImpact();
    }
  }

  void _handleChartGenerationDirect() {
    final prompt = _controller.text.trim();
    if (prompt.isNotEmpty && widget.onGenerateChart != null) {
      widget.onGenerateChart!(prompt);
      _controller.clear();
      // Keep mode active - user must manually turn it off
      _updateSendButton();
      HapticFeedback.lightImpact();
    }
  }

  void _handleFlashcardGenerationDirect() {
    final prompt = _controller.text.trim();
    if (prompt.isNotEmpty && widget.onGenerateFlashcards != null) {
      widget.onGenerateFlashcards!(prompt);
      _controller.clear();
      // Keep mode active - user must manually turn it off
      _updateSendButton();
      HapticFeedback.lightImpact();
    }
  }

  void _handleQuizGenerationDirect() {
    final prompt = _controller.text.trim();
    if (prompt.isNotEmpty && widget.onGenerateQuiz != null) {
      widget.onGenerateQuiz!(prompt);
      _controller.clear();
      // Keep mode active - user must manually turn it off
      _updateSendButton();
      HapticFeedback.lightImpact();
    }
  }

  void _showExtensionsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ExtensionsBottomSheet(

        imageGenerationMode: _imageGenerationMode,
        diagramGenerationMode: _diagramGenerationMode,
        presentationGenerationMode: _presentationGenerationMode,
        chartGenerationMode: _chartGenerationMode,
        flashcardGenerationMode: _flashcardGenerationMode,
        quizGenerationMode: _quizGenerationMode,
        onImageUpload: () async {
          Navigator.pop(context);
          await AdService.instance.onExtensionFeatureUsed();
          await _handleImageUpload();
        },
        onPdfUpload: () async {
          Navigator.pop(context);
          await AdService.instance.onExtensionFeatureUsed();
          await _handlePdfUpload();
        },

        onImageModeToggle: (enabled) {
          setState(() {
            _imageGenerationMode = enabled;
            if (enabled) {
              _diagramGenerationMode = false;
              _presentationGenerationMode = false;
              _chartGenerationMode = false;
              _flashcardGenerationMode = false;
              _quizGenerationMode = false;
            }
          });
          Navigator.pop(context);
        },
        onEnhancePrompt: () async {
          Navigator.pop(context);
          await AdService.instance.onExtensionFeatureUsed();
          _showPromptEnhancer();
        },
        onDiagramToggle: (enabled) {
          setState(() {
            _diagramGenerationMode = enabled;
            if (enabled) {
              _imageGenerationMode = false;
              _presentationGenerationMode = false;
              _chartGenerationMode = false;
              _flashcardGenerationMode = false;
              _quizGenerationMode = false;
            }
          });
          Navigator.pop(context);
        },
        onPresentationToggle: (enabled) {
          setState(() {
            _presentationGenerationMode = enabled;
            if (enabled) {
              _imageGenerationMode = false;
              _diagramGenerationMode = false;
              _chartGenerationMode = false;
              _flashcardGenerationMode = false;
              _quizGenerationMode = false;
            }
          });
          Navigator.pop(context);
        },
        onChartToggle: (enabled) {
          setState(() {
            _chartGenerationMode = enabled;
            if (enabled) {
              _imageGenerationMode = false;
              _diagramGenerationMode = false;
              _presentationGenerationMode = false;
              _flashcardGenerationMode = false;
              _quizGenerationMode = false;
            }
          });
          Navigator.pop(context);
        },
        onFlashcardToggle: (enabled) {
          setState(() {
            _flashcardGenerationMode = enabled;
            if (enabled) {
              _imageGenerationMode = false;
              _diagramGenerationMode = false;
              _presentationGenerationMode = false;
              _chartGenerationMode = false;
              _quizGenerationMode = false;
            }
          });
          Navigator.pop(context);
        },
        onQuizToggle: (enabled) {
          setState(() {
            _quizGenerationMode = enabled;
            if (enabled) {
              _imageGenerationMode = false;
              _diagramGenerationMode = false;
              _presentationGenerationMode = false;
              _chartGenerationMode = false;
              _flashcardGenerationMode = false;
            }
          });
          Navigator.pop(context);
        },
      ),
    );
  }



  Future<void> _handleImageUpload() async {
    try {
      // Show image source selection
      final ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => _ImageSourceSelector(),
      );

      if (source != null) {
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: source,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
        );

        if (image != null) {
          // Convert image to base64
          final bytes = await image.readAsBytes();
          final base64Image = base64Encode(bytes);
          final dataUrl = 'data:image/jpeg;base64,$base64Image';

          // Show success message and prompt user to type in input
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('📸 Image uploaded! Type your question in the input area and send.'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
            ),
          );

          // Store the image data temporarily for the next message
          _pendingImageData = dataUrl;
          _focusNode.requestFocus();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to process image: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _handlePdfUpload() async {
    try {
      // Pick files with multiple selection
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf', 'txt', 'md', 'html', 'css', 'js', 'jsx', 'ts', 'tsx',
          'json', 'xml', 'yaml', 'yml', 'csv', 'log', 'ini',
          'py', 'java', 'cpp', 'c', 'h', 'hpp', 'cs', 'php',
          'rb', 'go', 'rs', 'swift', 'kt', 'dart', 'sql', 'sh',
          'zip'
        ],
        allowMultiple: true,
      );
      
      if (result == null || result.files.isEmpty) {
        return;
      }
      
      final files = result.files
          .where((f) => f.path != null)
          .map((f) => File(f.path!))
          .toList();
      
      final fileNames = result.files.map((f) => f.name).toList();
      
      // Show loading indicator with custom styling
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('Processing ${files.length} file${files.length > 1 ? 's' : ''}...'),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 30),
        ),
      );
      
      // Extract content from files
      final fileContents = await FileExtractorService.extractContentFromFiles(files);
      
      // Clear loading indicator
      ScaffoldMessenger.of(context).clearSnackBars();
      
      if (fileContents.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not extract content from files'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        return;
      }
      
      // Store the extracted content hidden from user
      _hiddenFileContent = FileExtractorService.formatFileContents(fileContents);
      _uploadedFileNames = fileNames;
      
      // Keep input field clean - don't show file names
      // The content is stored in _hiddenFileContent
      _updateSendButton();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${files.length} file${files.length > 1 ? 's' : ''} uploaded successfully',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to process files: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  bool _isAnyExtensionActive() {
    return _imageGenerationMode || 
           _diagramGenerationMode || 
           _presentationGenerationMode || 
           _chartGenerationMode || 
           _flashcardGenerationMode || 
           _quizGenerationMode;
  }
  
  void _clearAllExtensions() {
    setState(() {
      _imageGenerationMode = false;
      _diagramGenerationMode = false;
      _presentationGenerationMode = false;
      _chartGenerationMode = false;
      _flashcardGenerationMode = false;
      _quizGenerationMode = false;
    });
    _updateSendButton();
  }

  IconData _getButtonIcon() {
    if (widget.isLoading) {
      return Icons.stop_rounded;
    }
    if (_imageGenerationMode) {
      return Icons.auto_awesome_outlined;
    }
    if (_diagramGenerationMode) {
      return Icons.account_tree_outlined;
    }
    if (_presentationGenerationMode) {
      return Icons.slideshow_outlined;
    }
    if (_chartGenerationMode) {
      return Icons.bar_chart_outlined;
    }
    if (_flashcardGenerationMode) {
      return Icons.style_outlined;
    }
    if (_quizGenerationMode) {
      return Icons.quiz_outlined;
    }
    return Icons.arrow_upward_rounded;
  }

  Color _getButtonIconColor(BuildContext context) {
    if (widget.isLoading) {
      return Colors.white;
    }
    if (_canSend) {
      return Theme.of(context).colorScheme.onPrimary;
    }
    return Theme.of(context).colorScheme.onSurface.withOpacity(0.5);
  }

  void _handleSpeechToText(SpeechService speechService) {
    if (speechService.isListening) {
      speechService.stopListening();
    } else {
      speechService.startListening(onResult: (text) {
        _controller.text = text;
        _updateSendButton();
      });
    }
  }
}

class _ExtensionsBottomSheet extends StatelessWidget {
  final bool imageGenerationMode;
  final bool diagramGenerationMode;
  final bool presentationGenerationMode;
  final bool chartGenerationMode;
  final bool flashcardGenerationMode;
  final bool quizGenerationMode;
  final VoidCallback onImageUpload;
  final VoidCallback onPdfUpload;
  final Function(bool) onImageModeToggle;
  final Function(bool) onDiagramToggle;
  final Function(bool) onPresentationToggle;
  final Function(bool) onChartToggle;
  final Function(bool) onFlashcardToggle;
  final Function(bool) onQuizToggle;
  final VoidCallback onEnhancePrompt;

  const _ExtensionsBottomSheet({
    required this.imageGenerationMode,
    this.diagramGenerationMode = false,
    this.presentationGenerationMode = false,
    this.chartGenerationMode = false,
    this.flashcardGenerationMode = false,
    this.quizGenerationMode = false,
    required this.onImageUpload,
    required this.onPdfUpload,
    required this.onImageModeToggle,
    required this.onDiagramToggle,
    required this.onPresentationToggle,
    required this.onChartToggle,
    required this.onFlashcardToggle,
    required this.onQuizToggle,
    required this.onEnhancePrompt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          // Options in grid layout
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // First row - File operations only
                Row(
                  children: [
                    Expanded(
                      child: _CompactExtensionTile(
                        icon: CupertinoIcons.photo,
                        title: 'Analyze Image',
                        onTap: onImageUpload,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _CompactExtensionTile(
                        icon: CupertinoIcons.folder,
                        title: 'Upload File',
                        onTap: onPdfUpload,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Second row - Enhance Prompt, Image generation, and Diagram
                Row(
                  children: [
                    Expanded(
                      child: _CompactExtensionTile(
                        icon: CupertinoIcons.wand_stars_inverse,
                        title: 'Enhance Prompt',
                        onTap: onEnhancePrompt,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ExtensionTile(
                        icon: CupertinoIcons.wand_stars,
                        title: 'Generate Image',
                        subtitle: '',
                        isToggled: imageGenerationMode,
                        onTap: () => onImageModeToggle(!imageGenerationMode),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ExtensionTile(
                        icon: CupertinoIcons.graph_square,
                        title: 'Diagram',
                        subtitle: '',
                        isToggled: diagramGenerationMode,
                        onTap: () => onDiagramToggle(!diagramGenerationMode),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 10),
                
                // Third row - Chart, Presentation, Flashcards
                Row(
                  children: [
                    Expanded(
                      child: _ExtensionTile(
                        icon: CupertinoIcons.chart_bar_alt_fill,
                        title: 'Chart',
                        subtitle: '',
                        isToggled: chartGenerationMode,
                        onTap: () => onChartToggle(!chartGenerationMode),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ExtensionTile(
                        icon: CupertinoIcons.rectangle_on_rectangle_angled,
                        title: 'Slides',
                        subtitle: '',
                        isToggled: presentationGenerationMode,
                        onTap: () => onPresentationToggle(!presentationGenerationMode),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ExtensionTile(
                        icon: CupertinoIcons.square_on_square,
                        title: 'Flashcards',
                        subtitle: '',
                        isToggled: flashcardGenerationMode,
                        onTap: () => onFlashcardToggle(!flashcardGenerationMode),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 10),
                
                // Fourth row - Quiz only
                Row(
                  children: [
                    Expanded(
                      child: _ExtensionTile(
                        icon: CupertinoIcons.question_circle,
                        title: 'Quiz',
                        subtitle: '',
                        isToggled: quizGenerationMode,
                        onTap: () => onQuizToggle(!quizGenerationMode),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Container()), // Empty space for alignment
                    const SizedBox(width: 10),
                    Expanded(child: Container()), // Empty space for alignment
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExtensionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isToggled;
  final double iconSize;
  final bool compact;
  final VoidCallback onTap;

  const _ExtensionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isToggled = false,
    this.iconSize = 20,
    this.compact = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isToggled 
          ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
          : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {
          onTap();
          HapticFeedback.selectionClick();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isToggled
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                size: 24,
              ),
              if (title.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isToggled ? FontWeight.w600 : FontWeight.w500,
                    color: isToggled
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactExtensionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _CompactExtensionTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          onTap();
          HapticFeedback.selectionClick();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 24,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageSourceSelector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Camera option
                _ExtensionTile(
                  icon: CupertinoIcons.camera,
                  title: 'Take Photo',
                  subtitle: 'Capture image with camera',
                  iconSize: 20,
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                
                const SizedBox(height: 12),
                
                // Gallery option
                _ExtensionTile(
                  icon: CupertinoIcons.photo_on_rectangle,
                  title: 'Choose from Gallery',
                  subtitle: 'Select image from your photos',
                  iconSize: 20,
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

