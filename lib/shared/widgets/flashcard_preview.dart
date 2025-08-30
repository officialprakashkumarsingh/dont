import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/models/flashcard_message_model.dart';

class FlashcardPreview extends StatefulWidget {
  final List<FlashcardItem> flashcards;
  final String title;

  const FlashcardPreview({
    super.key,
    required this.flashcards,
    required this.title,
  });

  @override
  State<FlashcardPreview> createState() => _FlashcardPreviewState();
}

class _FlashcardPreviewState extends State<FlashcardPreview>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _showAnswer = false;
  bool _isExporting = false;
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _flipAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _flipCard() {
    if (_showAnswer) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() {
      _showAnswer = !_showAnswer;
    });
  }

  void _nextCard() {
    if (_currentIndex < widget.flashcards.length - 1) {
      setState(() {
        _currentIndex++;
        _showAnswer = false;
        _flipController.reset();
      });
    }
  }

  void _previousCard() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _showAnswer = false;
        _flipController.reset();
      });
    }
  }

  Future<void> _exportFlashcards() async {
    setState(() {
      _isExporting = true;
    });

    try {
      // Show export notification with proper positioning
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Exporting flashcards as PDF...'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
          ),
        );
      }

      // Get theme colors
      final theme = Theme.of(context);
      final isDarkMode = theme.brightness == Brightness.dark;
      final primaryColor = theme.colorScheme.primary;
      final surfaceColor = theme.colorScheme.surface;
      final onSurfaceColor = theme.colorScheme.onSurface;
      
      // Convert Flutter colors to PDF colors
      final pdfPrimaryColor = PdfColor(
        primaryColor.red / 255,
        primaryColor.green / 255,
        primaryColor.blue / 255,
      );
      final pdfSurfaceColor = PdfColor(
        surfaceColor.red / 255,
        surfaceColor.green / 255,
        surfaceColor.blue / 255,
      );
      final pdfTextColor = PdfColor(
        onSurfaceColor.red / 255,
        onSurfaceColor.green / 255,
        onSurfaceColor.blue / 255,
      );
      final pdfBackgroundColor = isDarkMode 
          ? PdfColor(0.1, 0.1, 0.1)
          : PdfColor(1, 1, 1);

      // Create PDF document
      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(
          base: await PdfGoogleFonts.notoSansRegular(),
          bold: await PdfGoogleFonts.notoSansBold(),
          italic: await PdfGoogleFonts.notoSansItalic(),
          boldItalic: await PdfGoogleFonts.notoSansBoldItalic(),
          fontFallback: [await PdfGoogleFonts.notoColorEmoji()],
        ),
      );

      // Add pages
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (context) => [
            pw.Container(
              color: pdfBackgroundColor,
              padding: const pw.EdgeInsets.all(40),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Title
                  pw.Container(
                    padding: const pw.EdgeInsets.all(20),
                    decoration: pw.BoxDecoration(
                      color: pdfPrimaryColor.shade(isDarkMode ? 800 : 100),
                      borderRadius: pw.BorderRadius.circular(12),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        'Flashcards: ${widget.title}',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: pdfTextColor,
                        ),
                                            ),
                    ),
                  ),
                  pw.SizedBox(height: 30),
                  
                  // Cards
                  ...widget.flashcards.asMap().entries.map((entry) {
                    final index = entry.key;
                    final card = entry.value;
                    return pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 20),
                      padding: const pw.EdgeInsets.all(20),
                      decoration: pw.BoxDecoration(
                        color: isDarkMode 
                            ? pdfSurfaceColor.shade(700)
                            : pdfSurfaceColor,
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(
                          color: pdfPrimaryColor.shade(isDarkMode ? 600 : 300),
                          width: 1,
                        ),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Card ${index + 1}',
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: pdfPrimaryColor,
                            ),
                          ),
                          pw.SizedBox(height: 10),
                          pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'Q: ',
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  color: pdfTextColor,
                                ),
                              ),
                              pw.Expanded(
                                child: pw.Text(
                                  card.question,
                                  style: pw.TextStyle(color: pdfTextColor),
                                ),
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 8),
                          pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'A: ',
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  color: pdfTextColor,
                                ),
                              ),
                              pw.Expanded(
                                child: pw.Text(
                                  card.answer,
                                  style: pw.TextStyle(color: pdfTextColor),
                                ),
                              ),
                            ],
                          ),
                          if (card.explanation != null) ...[
                            pw.SizedBox(height: 8),
                            pw.Container(
                              padding: const pw.EdgeInsets.all(10),
                              decoration: pw.BoxDecoration(
                                color: pdfPrimaryColor.shade(isDarkMode ? 900 : 50),
                                borderRadius: pw.BorderRadius.circular(4),
                              ),
                              child: pw.Row(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    'ℹ️ ',
                                    style: pw.TextStyle(
                                      fontSize: 12,
                                      color: pdfTextColor,
                                    ),
                                  ),
                                  pw.Expanded(
                                    child: pw.Text(
                                      card.explanation!,
                                      style: pw.TextStyle(
                                        fontSize: 11,
                                        fontStyle: pw.FontStyle.italic,
                                        color: pdfTextColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ],
        ),
      );

      // Save and share PDF
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${tempDir.path}/flashcards_$timestamp.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Flashcards: ${widget.title}',
      );

      // Clean up after delay
      Future.delayed(const Duration(seconds: 10), () {
        file.deleteSync();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Flashcards exported as PDF!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentCard = widget.flashcards[_currentIndex];

    return Container(
      constraints: const BoxConstraints(
        maxHeight: 400,
        minHeight: 300,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          // Header with counter and export button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Card ${_currentIndex + 1} of ${widget.flashcards.length}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Material(
                  color: theme.colorScheme.surface.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: _isExporting ? null : _exportFlashcards,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: _isExporting
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.primary,
                              ),
                            )
                          : Icon(
                              Icons.download_outlined,
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Flashcard content
          Expanded(
            child: GestureDetector(
              onTap: _flipCard,
              onHorizontalDragEnd: (details) {
                // Swipe left to go to next card
                if (details.primaryVelocity! < -100) {
                  if (_currentIndex < widget.flashcards.length - 1) {
                    _nextCard();
                  }
                }
                // Swipe right to go to previous card
                else if (details.primaryVelocity! > 100) {
                  if (_currentIndex > 0) {
                    _previousCard();
                  }
                }
              },
              child: AnimatedBuilder(
                animation: _flipAnimation,
                builder: (context, child) {
                  final isShowingFront = _flipAnimation.value < 0.5;
                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(_flipAnimation.value * 3.14159),
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isShowingFront
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..rotateY(isShowingFront ? 0 : 3.14159),
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (isShowingFront) ...[
                                  Icon(
                                    Icons.help_outline,
                                    size: 32,
                                    color: theme.colorScheme.onPrimaryContainer
                                        .withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    currentCard.question,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      color: theme.colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'Tap to reveal answer',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onPrimaryContainer
                                          .withOpacity(0.6),
                                    ),
                                  ),
                                ] else ...[
                                  Icon(
                                    Icons.lightbulb_outline,
                                    size: 32,
                                    color: theme.colorScheme.onSecondaryContainer
                                        .withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    currentCard.answer,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      color: theme.colorScheme.onSecondaryContainer,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  if (currentCard.explanation != null) ...[
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surface
                                            .withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        currentCard.explanation!,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: theme.colorScheme.onSecondaryContainer
                                              .withOpacity(0.8),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Navigation controls
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              border: Border(
                top: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  onPressed: _currentIndex > 0 ? _previousCard : null,
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Previous card',
                ),
                Text(
                  _showAnswer ? 'Answer' : 'Question',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  onPressed: _currentIndex < widget.flashcards.length - 1
                      ? _nextCard
                      : null,
                  icon: const Icon(Icons.arrow_forward),
                  tooltip: 'Next card',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}