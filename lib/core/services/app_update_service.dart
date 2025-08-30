import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';

class AppUpdateService {
  static const String updateJsonUrl = 
      'https://raw.githubusercontent.com/officialprakashkumarsingh/ahamai-landingpage/main/app-update.json';
  
  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      
      // Fetch update info from JSON
      final response = await http.get(Uri.parse(updateJsonUrl));
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final updateInfo = UpdateInfo.fromJson(json);
        
        // Compare versions
        if (_isNewerVersion(currentVersion, updateInfo.latestVersion)) {
          return updateInfo;
        }
      }
      
      return null;
    } catch (e) {
      print('Error checking for updates: $e');
      return null;
    }
  }
  
  static bool _isNewerVersion(String current, String latest) {
    try {
      final currentParts = current.split('.').map(int.parse).toList();
      final latestParts = latest.split('.').map(int.parse).toList();
      
      for (int i = 0; i < latestParts.length; i++) {
        if (i >= currentParts.length) return true;
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }
  
  static Future<void> downloadAndInstallUpdate(
    BuildContext context,
    String downloadUrl,
    Function(double) onProgress,
  ) async {
    try {
      // Request install packages permission for Android
      if (Platform.isAndroid) {
        // Check if we can request install permission
        final status = await Permission.requestInstallPackages.status;
        if (!status.isGranted) {
          // Request permission
          final result = await Permission.requestInstallPackages.request();
          if (!result.isGranted) {
            throw Exception('Install permission denied. Please enable "Install unknown apps" in settings.');
          }
        }
      }
      
      final dio = Dio();
      
      // Get the downloads directory
      final dir = await getExternalStorageDirectory();
      final fileName = 'ahamai_update_${DateTime.now().millisecondsSinceEpoch}.apk';
      final savePath = '${dir!.path}/$fileName';
      
      // Delete the file if it already exists
      final file = File(savePath);
      if (await file.exists()) {
        await file.delete();
      }
      
      print('Downloading APK from: $downloadUrl');
      print('Saving to: $savePath');
      
      // Start with 0 progress
      onProgress(0.0);
      
      // Download the APK with better error handling
      final response = await dio.download(
        downloadUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1 && total > 0) {
            final progress = received / total;
            print('Download progress: ${(progress * 100).toInt()}%');
            onProgress(progress);
          } else {
            // If total is unknown, show indeterminate progress
            onProgress(received > 0 ? 0.5 : 0.0);
          }
        },
        options: Options(
          receiveTimeout: const Duration(minutes: 10),
          sendTimeout: const Duration(seconds: 30),
        ),
      );
      
      // Ensure download completed
      if (response.statusCode != 200) {
        throw Exception('Download failed with status: ${response.statusCode}');
      }
      
      // Verify file exists and has content
      if (!await file.exists() || await file.length() == 0) {
        throw Exception('Downloaded file is invalid or empty');
      }
      
      print('Download completed. File size: ${await file.length()} bytes');
      
      // Small delay to ensure file is fully written
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Open the APK for installation
      final result = await OpenFile.open(savePath);
      
      if (result.type != ResultType.done) {
        throw Exception('Failed to open APK: ${result.message}');
      }
    } catch (e) {
      print('Error downloading update: $e');
      throw e;
    }
  }
  
  static void showUpdateDialog(BuildContext context, UpdateInfo updateInfo) {
    showDialog(
      context: context,
      barrierDismissible: !updateInfo.isForceUpdate,
      builder: (context) => WillPopScope(
        onWillPop: () async => !updateInfo.isForceUpdate,
        child: UpdateDialog(updateInfo: updateInfo),
      ),
    );
  }
}

class UpdateInfo {
  final String latestVersion;
  final String downloadUrl;
  final bool isForceUpdate;
  final String releaseDate;
  final List<String> improvements;
  final int fileSizeMB;
  
  UpdateInfo({
    required this.latestVersion,
    required this.downloadUrl,
    required this.isForceUpdate,
    required this.releaseDate,
    required this.improvements,
    required this.fileSizeMB,
  });
  
  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      latestVersion: json['latest_version'] ?? '',
      downloadUrl: json['download_url'] ?? '',
      isForceUpdate: json['force_update'] ?? false,
      releaseDate: json['release_date'] ?? '',
      improvements: List<String>.from(json['improvements'] ?? []),
      fileSizeMB: json['file_size_mb'] ?? 0,
    );
  }
}

class UpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;
  
  const UpdateDialog({
    super.key,
    required this.updateInfo,
  });
  
  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.system_update,
                size: 48,
                color: theme.colorScheme.primary,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Title
            Text(
              'Update Available',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Version info
            Text(
              'Version ${widget.updateInfo.latestVersion}',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            
            const SizedBox(height: 4),
            
            // File size and date
            Text(
              '${widget.updateInfo.fileSizeMB} MB • ${widget.updateInfo.releaseDate}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Improvements
            if (widget.updateInfo.improvements.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "What's New",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...widget.updateInfo.improvements.map((improvement) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '• ',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              improvement,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            
            // Download progress
            if (_isDownloading) ...[
              Column(
                children: [
                  LinearProgressIndicator(
                    value: _downloadProgress,
                    backgroundColor: theme.colorScheme.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Downloading... ${(_downloadProgress * 100).toInt()}%',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            
            // Buttons
            Row(
              children: [
                if (!widget.updateInfo.isForceUpdate && !_isDownloading)
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Later'),
                    ),
                  ),
                if (!widget.updateInfo.isForceUpdate && !_isDownloading)
                  const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isDownloading ? null : _handleUpdate,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(_isDownloading ? 'Downloading...' : 'Update Now'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _handleUpdate() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });
    
    try {
      await AppUpdateService.downloadAndInstallUpdate(
        context,
        widget.updateInfo.downloadUrl,
        (progress) {
          setState(() {
            _downloadProgress = progress;
          });
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download update: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }
}