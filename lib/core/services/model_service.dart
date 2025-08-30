import 'package:flutter/foundation.dart';

import 'app_service.dart';
import 'api_service.dart';

class ModelService extends ChangeNotifier {
  static final ModelService _instance = ModelService._internal();
  static ModelService get instance => _instance;
  
  ModelService._internal() {
    _loadSelectedModel();
    _loadMultipleModelsSettings();
  }

  static const String _selectedModelKey = 'selected_ai_model';
  static const String _multipleModelsEnabledKey = 'multiple_models_enabled';
  static const String _selectedModelsKey = 'selected_ai_models';
  
  List<String> _availableModels = [];
  String _selectedModel = '';
  List<String> _selectedModels = [];
  bool _multipleModelsEnabled = false;
  bool _isLoading = false;
  
  List<String> get availableModels => List.unmodifiable(_availableModels);
  String get selectedModel => _selectedModel;
  List<String> get selectedModels => List.unmodifiable(_selectedModels);
  bool get multipleModelsEnabled => _multipleModelsEnabled;
  bool get isLoading => _isLoading;
  bool get hasModels => _availableModels.isNotEmpty;

  // Load models from API
  Future<void> loadModels() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final models = await ApiService.getModels();
      setState(() {
        _availableModels = models;
        
        // Only set default if no model is selected and models are available
        if (_selectedModel.isEmpty && models.isNotEmpty) {
          _selectedModel = models.first;
          _saveSelectedModel();
        }
        // If selected model is not in available models, reset to first
        else if (_selectedModel.isNotEmpty && !models.contains(_selectedModel) && models.isNotEmpty) {
          _selectedModel = models.first;
          _saveSelectedModel();
        }
        
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Select a model
  Future<void> selectModel(String model) async {
    if (_availableModels.contains(model) && _selectedModel != model) {
      setState(() {
        _selectedModel = model;
      });
      await _saveSelectedModel();
    }
  }

  // Load selected model from storage
  Future<void> _loadSelectedModel() async {
    try {
      final savedModel = AppService.prefs.getString(_selectedModelKey);
      if (savedModel != null && savedModel.isNotEmpty) {
        _selectedModel = savedModel;
        notifyListeners();
      }
    } catch (e) {
      // Handle error
    }
  }

  // Save selected model to storage
  Future<void> _saveSelectedModel() async {
    try {
      await AppService.prefs.setString(_selectedModelKey, _selectedModel);
    } catch (e) {
      // Handle error
    }
  }

  // Multiple models functionality
  Future<void> setMultipleModelsEnabled(bool enabled) async {
    setState(() {
      _multipleModelsEnabled = enabled;
      if (!enabled) {
        _selectedModels.clear();
      }
    });
    await AppService.prefs.setBool(_multipleModelsEnabledKey, enabled);
    await _saveSelectedModels();
  }

  Future<void> toggleModelSelection(String model) async {
    if (!_multipleModelsEnabled) return;
    
    setState(() {
      if (_selectedModels.contains(model)) {
        _selectedModels.remove(model);
      } else {
        _selectedModels.add(model);
      }
    });
    await _saveSelectedModels();
  }

  // Load multiple models settings
  Future<void> _loadMultipleModelsSettings() async {
    try {
      _multipleModelsEnabled = AppService.prefs.getBool(_multipleModelsEnabledKey) ?? false;
      
      final selectedModelsJson = AppService.prefs.getStringList(_selectedModelsKey);
      if (selectedModelsJson != null) {
        _selectedModels = selectedModelsJson;
      }
    } catch (e) {
      // Handle error
    }
  }

  // Save selected models
  Future<void> _saveSelectedModels() async {
    try {
      await AppService.prefs.setStringList(_selectedModelsKey, _selectedModels);
    } catch (e) {
      // Handle error
    }
  }

  // Helper method to update state
  void setState(VoidCallback fn) {
    fn();
    notifyListeners();
  }
}