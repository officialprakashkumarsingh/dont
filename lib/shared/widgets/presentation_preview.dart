import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../../core/models/presentation_message_model.dart';

class PresentationPreview extends StatefulWidget {
  final List<PresentationSlide> slides;
  final String title;
  
  const PresentationPreview({
    super.key,
    required this.slides,
    required this.title,
  });
  
  @override
  State<PresentationPreview> createState() => _PresentationPreviewState();
}

class _PresentationPreviewState extends State<PresentationPreview> {
  int _currentSlide = 0;
  final PageController _pageController = PageController();
  
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
  
  Future<void> _exportAsPdf() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Generating presentation PDF...'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
      
      // Get theme colors
      final isDarkMode = Theme.of(context).brightness == Brightness.dark;
      final primaryColor = Theme.of(context).colorScheme.primary;
      final surfaceColor = Theme.of(context).colorScheme.surface;
      final onSurfaceColor = Theme.of(context).colorScheme.onSurface;
      
      // Convert Flutter colors to PDF colors
      final pdfPrimaryColor = PdfColor(
        primaryColor.red / 255,
        primaryColor.green / 255,
        primaryColor.blue / 255,
      );
      
      final pdfBackgroundColor = isDarkMode 
          ? PdfColors.grey900 
          : PdfColors.white;
      
      final pdfTextColor = isDarkMode 
          ? PdfColors.grey100 
          : PdfColors.grey900;
      
      final pdfSecondaryTextColor = isDarkMode 
          ? PdfColors.grey300 
          : PdfColors.grey700;
      
      final pdfAccentColor = isDarkMode
          ? PdfColors.grey800
          : PdfColors.grey100;
      
      // Load fonts with better emoji support
      final baseFont = await PdfGoogleFonts.notoSansRegular();
      final boldFont = await PdfGoogleFonts.notoSansBold();
      final emojiFont = await PdfGoogleFonts.notoColorEmoji();
      
      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(
          base: baseFont,
          bold: boldFont,
          icons: emojiFont,
          fontFallback: [emojiFont], // Add emoji as fallback font
        ),
      );
      
      // Add slides to PDF
      for (int index = 0; index < widget.slides.length; index++) {
        final slide = widget.slides[index];
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: pw.EdgeInsets.zero, // Remove white margins
            build: (context) {
              return pw.Container(
                color: pdfBackgroundColor,
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(40),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Title with theme color
                      pw.Text(
                        _cleanTextForPdf(slide.title),
                        style: pw.TextStyle(
                          fontSize: 32,
                          fontWeight: pw.FontWeight.bold,
                          color: pdfPrimaryColor,
                        ),
                      ),
                    pw.SizedBox(height: 20),
                    
                    // Content
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          if (slide.content.isNotEmpty)
                            _buildPdfMarkdownContent(
                              slide.content,
                              textColor: pdfTextColor,
                              primaryColor: pdfPrimaryColor,
                              secondaryColor: pdfSecondaryTextColor,
                              isDarkMode: isDarkMode,
                            ),
                          
                          if (slide.bulletPoints != null) ...[
                            pw.SizedBox(height: 20),
                            ...slide.bulletPoints!.map((point) => pw.Padding(
                              padding: const pw.EdgeInsets.only(bottom: 10),
                              child: pw.Row(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text('• ', 
                                    style: pw.TextStyle(
                                      fontSize: 18,
                                      fontWeight: pw.FontWeight.bold,
                                      color: pdfPrimaryColor,
                                    ),
                                  ),
                                  pw.Expanded(
                                    child: pw.Text(
                                      _cleanTextForPdf(point),
                                      style: pw.TextStyle(
                                        fontSize: 16,
                                        color: pdfTextColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                          ],
                          
                          // Speaker notes
                          if (slide.notes != null && slide.notes!.isNotEmpty) ...[
                            pw.SizedBox(height: 20),
                            pw.Container(
                              padding: const pw.EdgeInsets.all(10),
                              decoration: pw.BoxDecoration(
                                color: pdfAccentColor,
                                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                              ),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    'Speaker Notes:',
                                    style: pw.TextStyle(
                                      fontSize: 12,
                                      fontWeight: pw.FontWeight.bold,
                                      color: pdfSecondaryTextColor,
                                    ),
                                  ),
                                  pw.SizedBox(height: 5),
                                  pw.Text(
                                    _cleanTextForPdf(slide.notes!),
                                    style: pw.TextStyle(
                                      fontSize: 11,
                                      color: pdfTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    // Footer with slide number
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          widget.title,
                          style: pw.TextStyle(fontSize: 12, color: pdfSecondaryTextColor),
                        ),
                        pw.Text(
                          'Slide ${index + 1} of ${widget.slides.length}',
                          style: pw.TextStyle(fontSize: 12, color: pdfSecondaryTextColor),
                        ),
                      ],
                    ),
                  ],
                ),
                ),
              );
            },
          ),
        );
      }
      
      // Save PDF
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${tempDir.path}/presentation_$timestamp.pdf');
      await file.writeAsBytes(await pdf.save());
      
      // Share PDF
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Presentation: ${widget.title}',
      );
      
      // Clean up
      await file.delete();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Presentation exported successfully!'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString()}'),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
  
  String _cleanTextForPdf(String text) {
    // The Noto font with emoji support will handle special characters
    return text;
  }
  
  pw.Widget _buildPdfMarkdownContent(
    String content, {
    PdfColor? textColor,
    PdfColor? primaryColor,
    PdfColor? secondaryColor,
    bool isDarkMode = false,
    double fontSize = 16,
    bool isInline = false,
  }) {
    // Use provided colors or defaults
    textColor ??= PdfColors.grey900;
    primaryColor ??= PdfColors.blue;
    secondaryColor ??= PdfColors.grey700;
    if (isInline) {
      // For inline content like bullet points, just return simple text
      return pw.Text(
        content,
        style: pw.TextStyle(
          fontSize: fontSize,
          color: textColor,
        ),
      );
    }
    
    final lines = content.split('\n');
    final widgets = <pw.Widget>[];
    
    for (final line in lines) {
      if (line.trim().isEmpty) {
        widgets.add(pw.SizedBox(height: 8));
      } else if (line.startsWith('# ')) {
        // H1 Header
        widgets.add(pw.Text(
          line.substring(2),
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
            color: primaryColor,
          ),
        ));
      } else if (line.startsWith('## ')) {
        // H2 Header
        widgets.add(pw.Text(
          line.substring(3),
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
            color: primaryColor,
          ),
        ));
      } else if (line.startsWith('### ')) {
        // H3 Header
        widgets.add(pw.Text(
          line.substring(4),
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: primaryColor,
          ),
        ));
      } else if (line.startsWith('> ')) {
        // Blockquote
        widgets.add(pw.Container(
          padding: const pw.EdgeInsets.only(left: 10),
          decoration: pw.BoxDecoration(
            border: pw.Border(
              left: pw.BorderSide(
                color: primaryColor,
                width: 3,
              ),
            ),
          ),
          child: pw.Text(
            line.substring(2),
            style: pw.TextStyle(
              fontSize: fontSize - 1,
              color: secondaryColor,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
        ));
      } else if (line.startsWith('```')) {
        // Code block start - collect until end
        final codeLines = <String>[];
        int i = lines.indexOf(line) + 1;
        while (i < lines.length && !lines[i].startsWith('```')) {
          codeLines.add(lines[i]);
          i++;
        }
        if (codeLines.isNotEmpty) {
          widgets.add(pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: isDarkMode ? PdfColors.grey800 : PdfColors.grey200,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              border: pw.Border.all(
                color: isDarkMode ? PdfColors.grey700 : PdfColors.grey400,
                width: 1,
              ),
            ),
            child: pw.Text(
              codeLines.join('\n'),
              style: pw.TextStyle(
                fontSize: fontSize - 2,
                fontWeight: pw.FontWeight.normal,
                color: textColor,
              ),
            ),
          ));
          // Skip processed lines
          final skipCount = codeLines.length + 1; // +1 for closing ```
          for (int j = 0; j < skipCount && lines.indexOf(line) + 1 < lines.length; j++) {
            lines.removeAt(lines.indexOf(line) + 1);
          }
        }
        continue;
      } else if (line.contains('**') && line.indexOf('**') != line.lastIndexOf('**')) {
        // Bold text - simple approach
        final processedLine = line.replaceAll('**', '');
        widgets.add(pw.Text(
          processedLine,
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: pw.FontWeight.bold,
            color: textColor,
          ),
        ));
      } else if (line.contains('*') && line.indexOf('*') != line.lastIndexOf('*') && !line.contains('**')) {
        // Italic text - simple approach
        final processedLine = line.replaceAll('*', '');
        widgets.add(pw.Text(
          processedLine,
          style: pw.TextStyle(
            fontSize: fontSize,
            fontStyle: pw.FontStyle.italic,
            color: textColor,
          ),
        ));
      } else if (line.contains('`') && line.indexOf('`') != line.lastIndexOf('`')) {
        // Inline code - simple approach
        final processedLine = line.replaceAll('`', '');
        widgets.add(pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey200,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
          ),
          child: pw.Text(
            processedLine,
            style: pw.TextStyle(
              fontSize: fontSize - 2,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ));
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        // List item
        widgets.add(pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('• ', 
              style: pw.TextStyle(
                fontSize: fontSize,
                fontWeight: pw.FontWeight.bold,
                color: primaryColor,
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                line.substring(2),
                style: pw.TextStyle(
                  fontSize: fontSize,
                  color: textColor,
                ),
              ),
            ),
          ],
        ));
      } else {
        // Regular text
        widgets.add(pw.Text(
          line,
          style: pw.TextStyle(
            fontSize: fontSize,
            color: textColor,
          ),
        ));
      }
      
      widgets.add(pw.SizedBox(height: 4));
    }
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: widgets,
    );
  }
  
  @override
  Widget build(BuildContext context) {
    if (widget.slides.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'No slides generated',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }
    
    return Container(
      height: 400,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          // Header with controls
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.slideshow,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${_currentSlide + 1} / ${widget.slides.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf, size: 20),
                  onPressed: _exportAsPdf,
                  tooltip: 'Export as PDF',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),
          
          // Slide content
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentSlide = index;
                });
              },
              itemCount: widget.slides.length,
              itemBuilder: (context, index) {
                final slide = widget.slides[index];
                return Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Slide title
                      Text(
                        slide.title,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Slide content
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (slide.content.isNotEmpty)
                                MarkdownBody(
                                  data: slide.content,
                                  selectable: true,
                                ),
                              
                              if (slide.bulletPoints != null && slide.bulletPoints!.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                ...slide.bulletPoints!.map((point) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '• ',
                                        style: Theme.of(context).textTheme.bodyLarge,
                                      ),
                                      Expanded(
                                        child: Text(
                                          point,
                                          style: Theme.of(context).textTheme.bodyLarge,
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          
          // Navigation controls
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _currentSlide > 0
                      ? () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      : null,
                  icon: const Icon(Icons.arrow_back_ios, size: 18),
                ),
                const SizedBox(width: 16),
                // Slide indicators
                Row(
                  children: List.generate(
                    widget.slides.length,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index == _currentSlide
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: _currentSlide < widget.slides.length - 1
                      ? () {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      : null,
                  icon: const Icon(Icons.arrow_forward_ios, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}