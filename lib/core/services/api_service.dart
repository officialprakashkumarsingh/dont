import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://ahamai-api.officialprakashkrsingh.workers.dev';
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
        'tools': [
          {
            'type': 'function',
            'function': {
              'name': 'generate_image',
              'description': 'Generate, create, draw, or make any type of image, photo, artwork, diagram, or visual content based on a user prompt. Use this whenever users ask for visual content, images, pictures, drawings, artwork, photos, designs, or any visual representation.',
              'parameters': {
                'type': 'object',
                'properties': {
                  'prompt': {
                    'type': 'string',
                    'description': 'A detailed description of the image to generate, including style, colors, composition, and any specific details.',
                  },
                  'model': {
                    'type': 'string',
                    'description': 'The specific model to use for generation, if the user requests one (e.g., "DALL-E", "Stable Diffusion", "Midjourney").',
                  }
                },
                'required': ['prompt'],
              },
            }
          },
          {
            'type': 'function',
            'function': {
              'name': 'website_browser',
              'description': 'Browse, access, and analyze content from any website, URL, or web page. Use this when users mention URLs, ask about websites, need current information from the web, want to check a specific site, or need real-time data from the internet.',
              'parameters': {
                'type': 'object',
                'properties': {
                  'url': {
                    'type': 'string',
                    'description': 'The complete URL of the website to browse and analyze (e.g., "https://example.com").',
                  }
                },
                'required': ['url'],
              },
            }
          }
        ]
      };

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
}