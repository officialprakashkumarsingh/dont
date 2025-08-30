import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path/path.dart' as path;
import 'package:archive/archive.dart';

class FileExtractorService {
  // Supported text file extensions
  static const List<String> supportedTextExtensions = [
    'txt', 'md', 'html', 'css', 'js', 'jsx', 'ts', 'tsx',
    'json', 'xml', 'yaml', 'yml', 'csv', 'log', 'ini',
    'py', 'java', 'cpp', 'c', 'h', 'hpp', 'cs', 'php',
    'rb', 'go', 'rs', 'swift', 'kt', 'dart', 'sql', 'sh'
  ];
  
  static Future<Map<String, String>> extractContentFromFiles(List<File> files) async {
    Map<String, String> fileContents = {};
    
    for (var file in files) {
      final fileName = path.basename(file.path);
      final extension = path.extension(file.path).toLowerCase().replaceFirst('.', '');
      
      String content = '';
      
      if (extension == 'pdf') {
        content = await _extractTextFromPdf(file);
      } else if (extension == 'zip') {
        content = await _extractFromZipFile(file);
      } else if (supportedTextExtensions.contains(extension)) {
        content = await _extractTextFromTextFile(file);
      } else {
        content = 'Unsupported file type: .$extension';
      }
      
      fileContents[fileName] = content;
    }
    
    return fileContents;
  }
  
  static Future<String> _extractTextFromPdf(File pdfFile) async {
    try {
      // Load the PDF document
      final PdfDocument document = PdfDocument(inputBytes: await pdfFile.readAsBytes());
      
      // Extract text from all pages
      String extractedText = '';
      
      for (int i = 0; i < document.pages.count; i++) {
        // Extract text from the page
        final PdfTextExtractor extractor = PdfTextExtractor(document);
        final String pageText = extractor.extractText(startPageIndex: i, endPageIndex: i);
        
        if (pageText.isNotEmpty) {
          extractedText += 'Page ${i + 1}:\n$pageText\n\n';
        }
      }
      
      // Dispose the document
      document.dispose();
      
      if (extractedText.isEmpty) {
        return 'Could not extract text from the PDF. The file might be image-based or empty.';
      }
      
      // No truncation - handle full content
      
      return extractedText.trim();
    } catch (e) {
      print('Error extracting text from PDF: $e');
      return 'Error reading PDF file: ${e.toString()}';
    }
  }
  
  static Future<String> _extractTextFromTextFile(File textFile) async {
    try {
      String content = await textFile.readAsString();
      
      // No truncation - handle full content
      
      return content;
    } catch (e) {
      print('Error reading text file: $e');
      return 'Error reading file: ${e.toString()}';
    }
  }
  
  static Future<String> _extractFromZipFile(File zipFile) async {
    try {
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      
      final buffer = StringBuffer();
      buffer.writeln('ZIP Archive Contents:');
      buffer.writeln('Total files: ${archive.length}');
      buffer.writeln();
      
      int fileCount = 0;
      for (final file in archive) {
        if (file.isFile) {
          fileCount++;
          final fileName = file.name;
          final extension = path.extension(fileName).toLowerCase().replaceFirst('.', '');
          
          buffer.writeln('File: $fileName');
          
          // Extract content based on file type
          if (supportedTextExtensions.contains(extension)) {
            final content = String.fromCharCodes(file.content);
            // No truncation - include full content
            buffer.writeln(content);
          } else {
            buffer.writeln('[Binary file - content not extracted]');
          }
          
          buffer.writeln();
          buffer.writeln('---');
          buffer.writeln();
          
          // No file limit - process all files in ZIP
        }
      }
      
      return buffer.toString();
    } catch (e) {
      print('Error extracting ZIP file: $e');
      return 'Error reading ZIP file: ${e.toString()}';
    }
  }
  
  static String formatFileContents(Map<String, String> fileContents) {
    final buffer = StringBuffer();
    
    buffer.writeln('Files uploaded: ${fileContents.keys.join(', ')}');
    buffer.writeln();
    
    for (var entry in fileContents.entries) {
      buffer.writeln('File: ${entry.key}');
      buffer.writeln('Content:');
      buffer.writeln(entry.value);
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln();
    }
    
    buffer.writeln('Please analyze and respond based on the above file contents.');
    
    return buffer.toString();
  }
}