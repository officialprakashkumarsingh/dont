import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/services/diagram_service.dart';

class DiagramPreview extends StatefulWidget {
  final String mermaidCode;
  final VoidCallback? onExport;

  const DiagramPreview({
    super.key,
    required this.mermaidCode,
    this.onExport,
  });

  @override
  State<DiagramPreview> createState() => _DiagramPreviewState();
}

class _DiagramPreviewState extends State<DiagramPreview> {
  bool _isLoading = true;
  bool _hasError = false;
  bool _useFallback = false;
  String _errorMessage = '';
  late String _diagramUrl;

  @override
  void initState() {
    super.initState();
    _loadDiagram();
  }

  @override
  void didUpdateWidget(DiagramPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mermaidCode != widget.mermaidCode) {
      _loadDiagram();
    }
  }

  Future<void> _loadDiagram() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      // Get validated preview URL
      _diagramUrl = await DiagramService.getValidPreviewUrl(widget.mermaidCode);
      
      if (_diagramUrl.isEmpty) {
        throw Exception('Could not generate diagram preview');
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Failed to load diagram preview';
      });
    }
  }

  void _retryWithFallback() {
    setState(() {
      _useFallback = !_useFallback;
    });
    _loadDiagram();
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: widget.mermaidCode));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Diagram code copied to clipboard'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Future<void> _exportAsImage() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Exporting diagram...'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
      
      // Use the current diagram URL that's already loaded
      final exportUrl = _diagramUrl;
      
      if (exportUrl.isEmpty) {
        throw Exception('No diagram to export');
      }
      
      // Download the image with proper headers
      final response = await http.get(
        Uri.parse(exportUrl),
        headers: {
          'Accept': 'image/png,image/svg+xml,image/*',
          'User-Agent': 'AhamAI/1.0',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Download timeout - please try again');
        },
      );
      
      if (response.statusCode == 200) {
        // Save to temporary file
        final tempDir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final file = File('${tempDir.path}/diagram_$timestamp.png');
        await file.writeAsBytes(response.bodyBytes);
        
        // Share the image file
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Diagram exported from AhamAI',
        );
        
        // Clean up
        await file.delete();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Diagram exported successfully!'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to download diagram');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString()}'),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Diagram content
            Container(
              constraints: const BoxConstraints(
                minHeight: 200,
                maxHeight: 400,
              ),
              child: _buildContent(),
            ),
            // Export button overlay
            if (!_hasError && !_isLoading)
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  elevation: 2,
                  child: InkWell(
                    onTap: _exportAsImage,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.download_outlined,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Generating diagram...',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    if (_hasError) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: _retryWithFallback,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Try Alternative'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _copyCode,
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  label: const Text('Copy Code'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Show the diagram image with error handling
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      child: Stack(
        children: [
          // Background pattern
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              backgroundBlendMode: BlendMode.multiply,
            ),
            child: CustomPaint(
              painter: GridPainter(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.05),
              ),
              child: Container(),
            ),
          ),
          
          // Diagram image
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Image.network(
                _diagramUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
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
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  // If primary service fails, try fallback
                  if (!_useFallback) {
                    Future.microtask(() => _retryWithFallback());
                  }
                  
                  return Container(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image_outlined,
                          size: 48,
                          color: Theme.of(context).colorScheme.error.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to render diagram',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _copyCode,
                          icon: const Icon(Icons.copy_outlined, size: 18),
                          label: const Text('Copy Mermaid Code'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Grid background painter
class GridPainter extends CustomPainter {
  final Color color;
  final double spacing;

  GridPainter({
    required this.color,
    this.spacing = 20,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Draw vertical lines
    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // Draw horizontal lines
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(GridPainter oldDelegate) {
    return color != oldDelegate.color || spacing != oldDelegate.spacing;
  }
}