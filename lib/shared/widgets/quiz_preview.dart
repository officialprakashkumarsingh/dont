import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/models/quiz_message_model.dart';

class QuizPreview extends StatefulWidget {
  final List<QuizQuestion> questions;
  final String title;

  const QuizPreview({
    super.key,
    required this.questions,
    required this.title,
  });

  @override
  State<QuizPreview> createState() => _QuizPreviewState();
}

class _QuizPreviewState extends State<QuizPreview> {
  int _currentQuestionIndex = 0;
  int? _selectedAnswer;
  bool _showResult = false;
  int _correctAnswers = 0;
  final Map<int, int?> _userAnswers = {};
  bool _isExporting = false;
  bool _quizCompleted = false;

  void _selectAnswer(int index) {
    if (!_showResult) {
      setState(() {
        _selectedAnswer = index;
      });
    }
  }

  void _submitAnswer() {
    if (_selectedAnswer != null && !_showResult) {
      setState(() {
        _showResult = true;
        _userAnswers[_currentQuestionIndex] = _selectedAnswer;
        if (_selectedAnswer == widget.questions[_currentQuestionIndex].correctAnswer) {
          _correctAnswers++;
        }
      });
    }
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < widget.questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswer = _userAnswers[_currentQuestionIndex];
        _showResult = _userAnswers.containsKey(_currentQuestionIndex);
      });
    } else if (!_quizCompleted) {
      setState(() {
        _quizCompleted = true;
      });
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
        _selectedAnswer = _userAnswers[_currentQuestionIndex];
        _showResult = _userAnswers.containsKey(_currentQuestionIndex);
      });
    }
  }

  void _resetQuiz() {
    setState(() {
      _currentQuestionIndex = 0;
      _selectedAnswer = null;
      _showResult = false;
      _correctAnswers = 0;
      _userAnswers.clear();
      _quizCompleted = false;
    });
  }

  Future<void> _exportQuiz() async {
    setState(() {
      _isExporting = true;
    });

    try {
      // Show export notification with proper positioning
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Exporting quiz as PDF...'),
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
      final successColor = Colors.green;
      final errorColor = theme.colorScheme.error;
      
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
      final pdfSuccessColor = PdfColor(
        successColor.red / 255,
        successColor.green / 255,
        successColor.blue / 255,
      );
      final pdfErrorColor = PdfColor(
        errorColor.red / 255,
        errorColor.green / 255,
        errorColor.blue / 255,
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
                        'Quiz: ${widget.title}',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: pdfTextColor,
                        ),
                                            ),
                    ),
                  ),
                  
                  // Results if quiz is completed
                  if (_userAnswers.isNotEmpty) ...[
                    pw.SizedBox(height: 20),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(16),
                      decoration: pw.BoxDecoration(
                        color: pdfPrimaryColor.shade(isDarkMode ? 900 : 50),
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Text(
                            'Your Score: $_correctAnswers/${widget.questions.length}',
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: pdfTextColor,
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Text(
                            'Percentage: ${(_correctAnswers / widget.questions.length * 100).toStringAsFixed(1)}%',
                            style: pw.TextStyle(
                              fontSize: 16,
                              color: pdfTextColor,
                            ),
                          ),
                        ],
                                            ),
                    ),
                  ],
                  
                  pw.SizedBox(height: 30),
                  
                  // Questions
                  ...widget.questions.asMap().entries.map((entry) {
                    final index = entry.key;
                    final question = entry.value;
                    final userAnswer = index < _userAnswers.length ? _userAnswers[index] : null;
                    
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
                            'Question ${index + 1}',
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: pdfPrimaryColor,
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Text(
                            question.question,
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: pdfTextColor,
                            ),
                          ),
                          pw.SizedBox(height: 12),
                          
                          // Options
                          ...question.options.asMap().entries.map((optEntry) {
                            final optIndex = optEntry.key;
                            final option = optEntry.value;
                            final isCorrect = optIndex == question.correctAnswer;
                            final isUserAnswer = userAnswer == optIndex;
                            
                            return pw.Container(
                              margin: const pw.EdgeInsets.only(bottom: 8),
                              padding: const pw.EdgeInsets.all(10),
                              decoration: pw.BoxDecoration(
                                color: userAnswer != null
                                    ? (isCorrect
                                        ? pdfSuccessColor.shade(isDarkMode ? 900 : 50)
                                        : (isUserAnswer
                                            ? pdfErrorColor.shade(isDarkMode ? 900 : 50)
                                            : null))
                                    : null,
                                borderRadius: pw.BorderRadius.circular(4),
                                border: pw.Border.all(
                                  color: userAnswer != null
                                      ? (isCorrect
                                          ? pdfSuccessColor
                                          : (isUserAnswer ? pdfErrorColor : pdfTextColor.shade(300)))
                                      : pdfTextColor.shade(300),
                                  width: 1,
                                ),
                              ),
                              child: pw.Row(
                                children: [
                                  pw.Text(
                                    '${String.fromCharCode(65 + optIndex)}. ',
                                    style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      color: pdfTextColor,
                                    ),
                                  ),
                                  pw.Expanded(
                                    child: pw.Text(
                                      option,
                                      style: pw.TextStyle(color: pdfTextColor),
                                    ),
                                  ),
                                  if (isCorrect)
                                    pw.Text(
                                      ' ✓',
                                      style: pw.TextStyle(
                                        color: pdfSuccessColor,
                                        fontWeight: pw.FontWeight.bold,
                                      ),
                                    ),
                                  if (isUserAnswer && !isCorrect)
                                    pw.Text(
                                      ' ✗',
                                      style: pw.TextStyle(
                                        color: pdfErrorColor,
                                        fontWeight: pw.FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                          
                          if (question.explanation != null) ...[
                            pw.SizedBox(height: 12),
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
                                      question.explanation!,
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
      final file = File('${tempDir.path}/quiz_$timestamp.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Quiz: ${widget.title}',
      );

      // Clean up after delay
      Future.delayed(const Duration(seconds: 10), () {
        file.deleteSync();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Quiz exported as PDF!'),
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
    
    if (_quizCompleted) {
      return _buildResultsView(theme);
    }

    final currentQuestion = widget.questions[_currentQuestionIndex];

    return Container(
      constraints: const BoxConstraints(
        maxHeight: 500,
        minHeight: 400,
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
          // Header with progress and export button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Question ${_currentQuestionIndex + 1} of ${widget.questions.length}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: (_currentQuestionIndex + 1) / widget.questions.length,
                        backgroundColor: theme.colorScheme.surfaceVariant,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Material(
                  color: theme.colorScheme.surface.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: _isExporting ? null : _exportQuiz,
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

          // Question
          Expanded(
            child: GestureDetector(
              onHorizontalDragEnd: (details) {
                // Swipe left to go to next question
                if (details.primaryVelocity! < -100) {
                  if (_currentQuestionIndex < widget.questions.length - 1) {
                    _nextQuestion();
                  }
                }
                // Swipe right to go to previous question
                else if (details.primaryVelocity! > 100) {
                  if (_currentQuestionIndex > 0) {
                    _previousQuestion();
                  }
                }
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.help_outline,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            currentQuestion.question,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Options
                  ...List.generate(currentQuestion.options.length, (index) {
                    final isSelected = _selectedAnswer == index;
                    final isCorrect = index == currentQuestion.correctAnswer;
                    final showCorrect = _showResult && isCorrect;
                    final showWrong = _showResult && isSelected && !isCorrect;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: showCorrect
                            ? Colors.green.withOpacity(0.2)
                            : showWrong
                                ? Colors.red.withOpacity(0.2)
                                : isSelected
                                    ? theme.colorScheme.primaryContainer
                                    : theme.colorScheme.surfaceVariant.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: !_showResult ? () => _selectAnswer(index) : null,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: showCorrect
                                        ? Colors.green
                                        : showWrong
                                            ? Colors.red
                                            : isSelected
                                                ? theme.colorScheme.primary
                                                : theme.colorScheme.outline.withOpacity(0.3),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      String.fromCharCode(65 + index),
                                      style: TextStyle(
                                        color: (showCorrect || showWrong || isSelected)
                                            ? Colors.white
                                            : theme.colorScheme.onSurface,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    currentQuestion.options[index],
                                    style: theme.textTheme.bodyLarge,
                                  ),
                                ),
                                if (showCorrect)
                                  const Icon(Icons.check_circle, color: Colors.green),
                                if (showWrong)
                                  const Icon(Icons.cancel, color: Colors.red),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),

                  // Explanation (if showing result)
                  if (_showResult && currentQuestion.explanation != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.lightbulb_outline,
                                color: theme.colorScheme.secondary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Explanation',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.secondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            currentQuestion.explanation!,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

          // Action buttons
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
              children: [
                IconButton(
                  onPressed: _currentQuestionIndex > 0 ? _previousQuestion : null,
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Previous question',
                ),
                const Spacer(),
                if (!_showResult)
                  ElevatedButton(
                    onPressed: _selectedAnswer != null ? _submitAnswer : null,
                    child: const Text('Submit Answer'),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _nextQuestion,
                    icon: Icon(_currentQuestionIndex < widget.questions.length - 1
                        ? Icons.arrow_forward
                        : Icons.assessment),
                    label: Text(_currentQuestionIndex < widget.questions.length - 1
                        ? 'Next Question'
                        : 'View Results'),
                  ),
                const Spacer(),
                Text(
                  'Score: $_correctAnswers/${_userAnswers.length}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsView(ThemeData theme) {
    final percentage = (_correctAnswers / widget.questions.length * 100);
    final isPassed = percentage >= 70;

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
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isPassed ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Quiz Results',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Material(
                  color: theme.colorScheme.surface.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: _isExporting ? null : _exportQuiz,
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

          // Results content
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isPassed ? Icons.emoji_events : Icons.timer,
                    size: 64,
                    color: isPassed ? Colors.amber : theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$_correctAnswers / ${widget.questions.length}',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isPassed ? Colors.green : Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isPassed ? 'Great job! 🎉' : 'Keep practicing! 💪',
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),

          // Action buttons
          Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _quizCompleted = false;
                      _currentQuestionIndex = 0;
                      _selectedAnswer = _userAnswers[0];
                      _showResult = true;
                    });
                  },
                  icon: const Icon(Icons.visibility),
                  label: const Text('Review Answers'),
                ),
                ElevatedButton.icon(
                  onPressed: _resetQuiz,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retake Quiz'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}