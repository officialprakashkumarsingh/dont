import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'app_service.dart';

class ImageService extends ChangeNotifier {
  static final ImageService _instance = ImageService._internal();
  static ImageService get instance => _instance;
  
  ImageService._internal() {
    _loadSettings();
  }

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

  // Service state
  static const String _selectedImageModelKey = 'selected_image_model';
  static const String _multipleImageModelsEnabledKey = 'multiple_image_models_enabled';
  static const String _selectedImageModelsKey = 'selected_image_models';
  
  List<ImageModel> _availableModels = [];
  String _selectedModel = '';
  List<String> _selectedModels = [];
  bool _multipleModelsEnabled = false;
  bool _isLoading = false;
  
  // Getters
  List<ImageModel> get availableModels => List.unmodifiable(_availableModels);
  String get selectedModel => _selectedModel;
  List<String> get selectedModels => List.unmodifiable(_selectedModels);
  bool get multipleModelsEnabled => _multipleModelsEnabled;
  bool get isLoading => _isLoading;
  bool get hasModels => _availableModels.isNotEmpty;

  // Load models
  Future<void> loadModels() async {
    if (_isLoading) return;
    
    _setState(() {
      _isLoading = true;
    });

    try {
      final models = await getImageModels();
      _setState(() {
        _availableModels = models;
        
        // Set default model if none selected
        if (_selectedModel.isEmpty && models.isNotEmpty) {
          _selectedModel = models.first.id;
          _saveSelectedModel();
        }
        
        _isLoading = false;
      });
    } catch (e) {
      _setState(() {
        _isLoading = false;
      });
    }
  }

  // Select model
  Future<void> selectModel(String modelId) async {
    if (_availableModels.any((m) => m.id == modelId) && _selectedModel != modelId) {
      _setState(() {
        _selectedModel = modelId;
      });
      await _saveSelectedModel();
    }
  }

  // Multiple models functionality
  Future<void> setMultipleModelsEnabled(bool enabled) async {
    _setState(() {
      _multipleModelsEnabled = enabled;
      if (!enabled) {
        _selectedModels.clear();
      }
    });
    await AppService.prefs.setBool(_multipleImageModelsEnabledKey, enabled);
    await _saveSelectedModels();
  }

  Future<void> toggleModelSelection(String modelId) async {
    if (!_multipleModelsEnabled) return;
    
    _setState(() {
      if (_selectedModels.contains(modelId)) {
        _selectedModels.remove(modelId);
      } else {
        _selectedModels.add(modelId);
      }
    });
    await _saveSelectedModels();
  }

  // Get available image models
  static Future<List<ImageModel>> getImageModels() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/v1/images/models'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null) {
          return List<ImageModel>.from(
            data['data'].map((model) => ImageModel.fromJson(model)),
          );
        }
      }
      
      return [];
    } catch (e) {
      print('Error fetching image models: $e');
      return [];
    }
  }

  // Test all models
  static Future<Map<String, bool>> testAllModels() async {
    final models = await getImageModels();
    final results = <String, bool>{};
    
    for (final model in models) {
      print('Testing model: ${model.id}...');
      try {
        final imageUrl = await generateImage(
          prompt: 'test image',
          model: model.id,
        );
        results[model.id] = imageUrl != null && imageUrl.isNotEmpty;
        print('${model.id}: ${(results[model.id] ?? false) ? "✅ Working" : "❌ Failed"}');
      } catch (e) {
        results[model.id] = false;
        print('${model.id}: ❌ Failed - $e');
      }
      
      // Small delay between requests
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    return results;
  }

  // Generate image - handles both URL and binary responses
  static Future<String?> generateImage({
    required String prompt,
    required String model,
    String size = '1024x1024',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/v1/images/generations'),
        headers: _headers,
        body: jsonEncode({
          'prompt': prompt,
          'model': model,
          'size': size,
        }),
      );

      if (response.statusCode == 200) {
        final contentType = response.headers['content-type'] ?? '';
        print('Response content-type: $contentType');
        print('Response body length: ${response.bodyBytes.length}');
        
        // Check if it's a JSON response first
        try {
          final data = jsonDecode(response.body);
          print('JSON response: $data');
          
          // Handle error responses
          if (data['error'] != null) {
            print('API returned error: ${data['error']}');
            return null;
          }
          
          // Extract URL from JSON response
          final imageUrl = data['data']?[0]?['url'] ?? data['url'];
          if (imageUrl != null && imageUrl.toString().isNotEmpty) {
            print('Found image URL: $imageUrl');
            // For URL-based models, convert to data URL to avoid CORS issues
            return await _convertUrlToDataUrl(imageUrl.toString());
          }
        } catch (e) {
          print('Not a JSON response, checking for binary data...');
        }
        
        // Handle binary image response
        if (contentType.startsWith('image/') || (response.bodyBytes.isNotEmpty && response.bodyBytes.length > 1000)) {
          // Binary image response - convert to data URL
          final bytes = response.bodyBytes;
          final base64Image = base64Encode(bytes);
          // Default to PNG if content type not specified
          final imageType = contentType.isNotEmpty ? contentType : 'image/png';
          print('Converting binary to base64, size: ${bytes.length} bytes');
          return 'data:$imageType;base64,$base64Image';
        }
        
        print('No valid image data found in response');
        return null;
      } else {
        print('Image generation failed: ${response.statusCode}');
        print('Response: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error generating image: $e');
      return null;
    }
  }

  // Convert URL to data URL to avoid CORS issues
  static Future<String?> _convertUrlToDataUrl(String imageUrl) async {
    try {
      print('Fetching image from URL: $imageUrl');
      final response = await http.get(Uri.parse(imageUrl));
      
      if (response.statusCode == 200) {
        final contentType = response.headers['content-type'] ?? 'image/png';
        final bytes = response.bodyBytes;
        final base64Image = base64Encode(bytes);
        print('Successfully converted URL to base64, size: ${bytes.length} bytes');
        return 'data:$contentType;base64,$base64Image';
      } else {
        print('Failed to fetch image from URL: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error converting URL to data URL: $e');
      return null;
    }
  }

  // Load settings
  Future<void> _loadSettings() async {
    try {
      _selectedModel = AppService.prefs.getString(_selectedImageModelKey) ?? '';
      _multipleModelsEnabled = AppService.prefs.getBool(_multipleImageModelsEnabledKey) ?? false;
      
      final selectedModelsJson = AppService.prefs.getStringList(_selectedImageModelsKey);
      if (selectedModelsJson != null) {
        _selectedModels = selectedModelsJson;
      }
    } catch (e) {
      // Handle error
    }
  }

  // Save selected model
  Future<void> _saveSelectedModel() async {
    try {
      await AppService.prefs.setString(_selectedImageModelKey, _selectedModel);
    } catch (e) {
      // Handle error
    }
  }

  // Save selected models
  Future<void> _saveSelectedModels() async {
    try {
      await AppService.prefs.setStringList(_selectedImageModelsKey, _selectedModels);
    } catch (e) {
      // Handle error
    }
  }

  // Helper method to update state
  void _setState(VoidCallback fn) {
    fn();
    notifyListeners();
  }
}

class ImageModel {
  final String id;
  final String name;
  final String provider;
  final int width;
  final int height;

  const ImageModel({
    required this.id,
    required this.name,
    required this.provider,
    required this.width,
    required this.height,
  });

  factory ImageModel.fromJson(Map<String, dynamic> json) {
    return ImageModel(
      id: json['id'] as String,
      name: json['name'] as String,
      provider: json['provider'] as String,
      width: json['width'] as int? ?? 1024,
      height: json['height'] as int? ?? 1024,
    );
  }

  @override
  String toString() {
    return 'ImageModel(id: $id, name: $name, provider: $provider, size: ${width}x$height)';
  }
}