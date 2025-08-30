import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://ahamai-api.officialprakashkrsingh.workers.dev';
  static int _currentBraveApiKeyIndex = 0;
  static DateTime _lastKeyRotation = DateTime.now();
  
  static Map<String, String> get headers {
    final apiKey = dotenv.env['API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('API_KEY not found in environment variables. Please set it in the .env file.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };
  }

  /// Get Brave Search API keys from environment and rotate them
  static List<String> get _braveApiKeys {
    final keysString = dotenv.env['BRAVE_API_KEYS'] ?? '';
    if (keysString.isEmpty) {
      throw Exception('BRAVE_API_KEYS not found in environment variables.');
    }
    return keysString.split(',').where((key) => key.trim().isNotEmpty).toList();
  }

  /// Get current Brave API key with rotation logic
  static String _getCurrentBraveApiKey() {
    final keys = _braveApiKeys;
    if (keys.isEmpty) {
      throw Exception('No Brave API keys available.');
    }
    
    // Rotate key every 5 minutes or on error
    final now = DateTime.now();
    if (now.difference(_lastKeyRotation).inMinutes >= 5) {
      _rotateBraveApiKey();
    }
    
    return keys[_currentBraveApiKeyIndex % keys.length];
  }

  /// Rotate to next Brave API key
  static void _rotateBraveApiKey() {
    final keys = _braveApiKeys;
    if (keys.isNotEmpty) {
      _currentBraveApiKeyIndex = (_currentBraveApiKeyIndex + 1) % keys.length;
      _lastKeyRotation = DateTime.now();
      print('Rotated to Brave API key index: $_currentBraveApiKeyIndex');
    }
  }

  // Get available models
  static Future<List<String>> getModels() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/v1/models'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null) {
          return List<String>.from(
            data['data'].map((model) => model['id'] ?? model['name'] ?? ''),
          ).where((model) => model.isNotEmpty).toList();
        }
      }
      
      // Fallback models if API fails
      return [
        'claude-3-5-sonnet',
        'claude-3-7-sonnet',
        'claude-sonnet-4',
        'claude-3-5-sonnet-ashlynn',
      ];
    } catch (e) {
      // Return fallback models on error
      return [
        'claude-3-5-sonnet',
        'claude-3-7-sonnet',
        'claude-sonnet-4',
        'claude-3-5-sonnet-ashlynn',
      ];
    }
  }

  // Send chat message
  static Future<Stream<String>> sendMessage({
    required String message,
    required String model,
    List<Map<String, dynamic>>? conversationHistory,
    String? systemPrompt,
  }) async {
    try {
      final messages = <Map<String, dynamic>>[];
      
      // Add system prompt if provided
      if (systemPrompt != null && systemPrompt.isNotEmpty) {
        messages.add({
          'role': 'system',
          'content': systemPrompt,
        });
      }
      
      // Add conversation history
      if (conversationHistory != null) {
        messages.addAll(conversationHistory);
      }
      
      // Add current message
      messages.add({
        'role': 'user',
        'content': message,
      });

      final requestBody = {
        'model': model,
        'messages': messages,
        'stream': true,
        'temperature': 0.7,
      };

      print('🔧 API: Sending request without tools.');
      
      final request = http.Request(
        'POST',
        Uri.parse('$baseUrl/v1/chat/completions'),
      );
      
      request.headers.addAll(headers);
      request.body = jsonEncode(requestBody);

      final streamedResponse = await request.send();
      
      if (streamedResponse.statusCode == 200) {
        final controller = StreamController<String>();
        
        streamedResponse.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .where((line) => line.isNotEmpty && line.startsWith('data: '))
            .listen(
          (line) {
            try {
              final data = line.substring(6); // Remove 'data: ' prefix
              if (data.trim() == '[DONE]') {
                controller.close();
                return;
              }
              
              final json = jsonDecode(data);
              final delta = json['choices']?[0]?['delta'];
              
              // Handle regular text content
              if (delta?['content'] != null) {
                final content = delta['content'] as String;
                if (content.isNotEmpty) {
                  controller.add(content);
                }
              }

              // Handle tool calls
              if (delta?['tool_calls'] != null) {
                // The API is asking to use a tool.
                // We'll encode this as a special string and handle it on the client.
                final toolCalls = jsonEncode(delta['tool_calls']);
                print('🔧 API: Tool call detected in response: $toolCalls');
                controller.add('__TOOL_CALL__$toolCalls');
              }
            } catch (e) {
              // Skip malformed chunks
            }
          },
          onError: (error) => controller.addError(error),
          onDone: () => controller.close(),
        );
        
        return controller.stream;
      } else {
        throw HttpException('Failed to send message: ${streamedResponse.statusCode}');
      }
    } catch (e) {
      throw Exception('Error sending message: $e');
    }
  }

  // Generate image (if supported by your API)
  static Future<String?> generateImage({
    required String prompt,
    required String model,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/v1/images/generations'),
        headers: headers,
        body: jsonEncode({
          'prompt': prompt,
          'model': model,
          'size': '1024x1024',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data']?[0]?['url'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Web browser function
  static Future<String?> browseWebsite({
    required String url,
  }) async {
    try {
      final scraperUrl = 'https://scrap.ytansh038.workers.dev/?url=$url';
      final response = await http.get(
        Uri.parse(scraperUrl),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return response.body;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Web search function with Brave Search API
  static Future<Map<String, dynamic>?> searchWeb({
    required String query,
  }) async {
    int attempts = 0;
    const maxAttempts = 3;
    
    while (attempts < maxAttempts) {
      try {
        final apiKey = _getCurrentBraveApiKey();
        final url = 'https://api.search.brave.com/res/v1/web/search?q=${Uri.encodeComponent(query)}&count=25';
        
        final response = await http.get(
          Uri.parse(url),
          headers: {
            'Accept': 'application/json',
            'Accept-Encoding': 'gzip',
            'X-Subscription-Token': apiKey,
          },
        ).timeout(const Duration(seconds: 30));

        print('Brave Search API response status: ${response.statusCode}');
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data;
        } else if (response.statusCode == 401 || response.statusCode == 403) {
          // API key error - rotate and try again
          print('API key error (${response.statusCode}), rotating key...');
          _rotateBraveApiKey();
          attempts++;
          continue;
        } else if (response.statusCode == 429) {
          // Rate limit - rotate key and try again
          print('Rate limit hit (${response.statusCode}), rotating key...');
          _rotateBraveApiKey();
          attempts++;
          await Future.delayed(Duration(seconds: 1 * attempts)); // Progressive delay
          continue;
        } else {
          print('Brave Search API error: ${response.statusCode} - ${response.body}');
          return null;
        }
      } catch (e) {
        print('Brave Search API exception: $e');
        attempts++;
        if (attempts < maxAttempts) {
          _rotateBraveApiKey();
          await Future.delayed(Duration(seconds: 1 * attempts));
        }
      }
    }
    
    return null;
  }
}