import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

import 'package:flutter_dotenv/flutter_dotenv.dart';

class VisionService {
  static const String baseUrl = 'https://ahamai-api.officialprakashkrsingh.workers.dev';
  
  static Map<String, String> get _headers {
    final apiKey = dotenv.env['API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('API_KEY not found in environment variables. Please set it in the .env file.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };
  }

  // Get available vision models
  static Future<List<VisionModel>> getVisionModels() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/v1/vision/models'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null) {
          return List<VisionModel>.from(
            data['data'].map((model) => VisionModel.fromJson(model)),
          );
        }
      }
      
      return [];
    } catch (e) {
      print('Error fetching vision models: $e');
      return [];
    }
  }

  // Analyze image with vision model
  static Future<Stream<String>> analyzeImage({
    required String prompt,
    required String imageData,
    required String model,
  }) async {
    try {
      print('VisionService: Analyzing image with model: $model');
      print('VisionService: Image data length: ${imageData.length} characters');
      print('VisionService: Prompt: $prompt');
      
      final messages = [
        {
          'role': 'user',
          'content': [
            {
              'type': 'text',
              'text': prompt,
            },
            {
              'type': 'image_url',
              // The imageData is already a complete data URI (e.g., "data:image/jpeg;base64,...")
              // passed from the chat input. Using the OpenAI-compatible format.
              'image_url': {
                'url': imageData,
              },
            },
          ],
        },
      ];

      final requestBody = {
        'model': model,
        'messages': messages,
        'stream': true, // Enable streaming for vision API
        'temperature': 0.7,
      };

      final request = http.Request('POST', Uri.parse('$baseUrl/v1/chat/completions'));
      request.headers.addAll(_headers);
      request.body = jsonEncode(requestBody);

      final streamedResponse = await request.send();
      
      if (streamedResponse.statusCode == 200) {
        final controller = StreamController<String>();
        
        // Process the SSE stream
        streamedResponse.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
          (line) {
            if (line.startsWith('data: ')) {
              final data = line.substring(6);
              if (data == '[DONE]') {
                controller.close();
                return;
              }
              
              try {
                final json = jsonDecode(data);
                final delta = json['choices']?[0]?['delta'];
                if (delta != null && delta['content'] != null) {
                  controller.add(delta['content']);
                }
              } catch (e) {
                // Skip invalid JSON lines
              }
            }
          },
          onError: (error) {
            print('Stream error: $error');
            controller.addError(error);
            controller.close();
          },
          onDone: () {
            controller.close();
          },
          cancelOnError: true,
        );
        
        return controller.stream;
      } else {
        final responseBody = await streamedResponse.stream.bytesToString();
        print('Vision API error: ${streamedResponse.statusCode}');
        print('Response: $responseBody');
        // Propagate the actual server error instead of a generic message
        return Stream.value(
            'Error: ${streamedResponse.reasonPhrase} (Code: ${streamedResponse.statusCode})\n\nDetails: $responseBody');
      }
    } catch (e) {
      print('Error in vision analysis: $e');
      // Return error stream with the specific exception
      return Stream.value(
          'An unexpected error occurred. Please check your connection and try again.\n\nDetails: ${e.toString()}');
    }
  }

  // Get the best available vision model
  static Future<String?> getBestVisionModel() async {
    try {
      // First try to get models from the vision endpoint
      final visionModels = await getVisionModels();
      if (visionModels.isNotEmpty) {
        print('Vision models from /v1/vision/models: ${visionModels.map((m) => m.id).toList()}');
        return visionModels.first.id;
      }
      
      // Fallback to known vision models
      print('No vision models from API, using fallback: llama-4-scout-17b-16e-instruct');
      return 'llama-4-scout-17b-16e-instruct';
    } catch (e) {
      print('Error getting vision models: $e');
      // Return a known working vision model as fallback
      return 'llama-4-scout-17b-16e-instruct';
    }
  }

  // Check if a model supports vision
  static bool isVisionModel(String modelId) {
    // For now, we'll check if it's the vision model we know about
    // This could be expanded to check against the vision models list
    return modelId.toLowerCase().contains('gemini') || 
           modelId.toLowerCase().contains('vision') ||
           modelId.toLowerCase().contains('gpt-4') ||
           modelId.toLowerCase().contains('claude-3');
  }
}

class VisionModel {
  final String id;
  final String name;
  final String provider;
  final List<String> capabilities;
  final int maxTokens;
  final List<String> supportedFormats;

  const VisionModel({
    required this.id,
    required this.name,
    required this.provider,
    required this.capabilities,
    required this.maxTokens,
    required this.supportedFormats,
  });

  factory VisionModel.fromJson(Map<String, dynamic> json) {
    return VisionModel(
      id: json['id'] as String,
      name: json['name'] as String,
      provider: json['provider'] as String,
      capabilities: List<String>.from(json['capabilities'] ?? []),
      maxTokens: json['max_tokens'] as int? ?? 4000,
      supportedFormats: List<String>.from(json['supported_formats'] ?? []),
    );
  }

  @override
  String toString() {
    return 'VisionModel(id: $id, name: $name, provider: $provider)';
  }
}