import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/services/chart_service.dart';

class ChartPreview extends StatefulWidget {
  final String chartConfig;
  final String prompt;

  const ChartPreview({
    super.key,
    required this.chartConfig,
    required this.prompt,
  });

  @override
  State<ChartPreview> createState() => _ChartPreviewState();
}

class _ChartPreviewState extends State<ChartPreview> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isExporting = false;
  
  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }
  
  void _initializeWebView() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final htmlContent = ChartService.generateChartHtml(
      widget.chartConfig,
      isDarkMode,
    );
    
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _isLoading = false;
              _hasError = true;
              _errorMessage = error.description ?? 'Unknown error';
            });
          },
        ),
      )
      ..loadHtmlString(htmlContent);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

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
          // Chart display area with floating export button
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  WebViewWidget(controller: _controller),
                  
                  // Loading indicator
                  if (_isLoading)
                    Container(
                      color: theme.colorScheme.surface,
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  
                  // Error display
                  if (_hasError)
                    Container(
                      color: theme.colorScheme.surface,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Failed to load chart',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Text(
                                _errorMessage,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  // Export button overlay (like diagram)
                  if (!_hasError && !_isLoading)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: theme.colorScheme.surface.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        elevation: 2,
                        child: InkWell(
                          onTap: _isExporting ? null : _exportAsImage,
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
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportAsImage() async {
    setState(() {
      _isExporting = true;
    });
    
    try {
      // Show export notification with proper positioning
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Exporting chart as image...'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
          ),
        );
      }
      
      // For webview_flutter, we need to use a different approach
      // We'll generate a data URL from the chart and share that
      final String? dataUrl = await _controller.runJavaScriptReturningResult('''
        (function() {
          var canvas = document.getElementById('myChart');
          if (canvas) {
            return canvas.toDataURL('image/png');
          }
          return null;
        })();
      ''') as String?;
      
      if (dataUrl != null && dataUrl.contains('data:image/png;base64,')) {
        // Extract base64 data
        final base64Data = dataUrl.replaceFirst('data:image/png;base64,', '').replaceAll('"', '');
        final Uint8List bytes = base64Decode(base64Data);
        
        // Save to temporary file
        final tempDir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final file = File('${tempDir.path}/chart_$timestamp.png');
        await file.writeAsBytes(bytes);
        
        // Share the image
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Chart: ${widget.prompt}',
        );
        
        // Clean up temp file after a delay
        Future.delayed(const Duration(seconds: 10), () {
          file.deleteSync();
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Chart exported successfully!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
            ),
          );
        }
      } else {
        throw Exception('Failed to capture chart');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export chart: $e'),
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
}