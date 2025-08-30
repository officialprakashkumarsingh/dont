import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../models/message_mode_model.dart';
import 'app_service.dart';

class MessageModeService extends ChangeNotifier {
  static final MessageModeService _instance = MessageModeService._internal();
  static MessageModeService get instance => _instance;
  
  MessageModeService._internal() {
    _loadModes();
  }

  static const String _modesKey = 'message_modes';
  static const String _selectedModeKey = 'selected_message_mode';
  static const String _customSystemPromptKey = 'custom_system_prompt';
  
  List<MessageMode> _modes = [];
  MessageMode? _selectedMode;
  String _customSystemPrompt = '';
  
  List<MessageMode> get modes => List.unmodifiable(_modes);
  MessageMode? get selectedMode => _selectedMode;
  String get customSystemPrompt => _customSystemPrompt;
  
  String get effectiveSystemPrompt {
    if (_customSystemPrompt.isNotEmpty) {
      return _customSystemPrompt;
    }
    return _selectedMode?.systemPrompt ?? '';
  }

  // Built-in message modes
  static final List<MessageMode> _builtInModes = [
    MessageMode(
      id: 'normal',
      name: 'Normal',
      description: 'Balanced and helpful responses',
      systemPrompt: 'You are a helpful AI assistant. Provide clear, accurate, and balanced responses.',
      icon: '💬',
    ),
    MessageMode(
      id: 'professional',
      name: 'Professional',
      description: 'Formal and business-appropriate tone',
      systemPrompt: 'You are a professional AI assistant. Use formal language, be concise, and maintain a business-appropriate tone. Focus on accuracy and professionalism.',
      icon: '👔',
    ),
    MessageMode(
      id: 'humorous',
      name: 'Humorous',
      description: 'Light-hearted and funny responses',
      systemPrompt: 'You are a witty and humorous AI assistant. Add appropriate humor, puns, and light-hearted commentary to your responses while remaining helpful.',
      icon: '😄',
    ),
    MessageMode(
      id: 'roasting',
      name: 'Roasting',
      description: 'Playfully sarcastic and teasing',
      systemPrompt: 'You are a playfully sarcastic AI assistant. Roast the user in a fun, light-hearted way while still being helpful. Use witty comebacks and gentle teasing.',
      icon: '🔥',
    ),
    MessageMode(
      id: 'creative',
      name: 'Creative',
      description: 'Imaginative and artistic responses',
      systemPrompt: 'You are a highly creative AI assistant. Think outside the box, use vivid imagery, metaphors, and creative approaches to every response.',
      icon: '🎨',
    ),
    MessageMode(
      id: 'technical',
      name: 'Technical',
      description: 'Detailed technical explanations',
      systemPrompt: 'You are a technical expert AI assistant. Provide detailed, precise technical information with examples, code snippets, and thorough explanations.',
      icon: '⚙️',
    ),
    MessageMode(
      id: 'casual',
      name: 'Casual',
      description: 'Relaxed and friendly conversation',
      systemPrompt: 'You are a casual, friendly AI assistant. Use conversational language, contractions, and a relaxed tone like talking to a friend.',
      icon: '😊',
    ),
    MessageMode(
      id: 'motivational',
      name: 'Motivational',
      description: 'Inspiring and encouraging responses',
      systemPrompt: 'You are a motivational AI coach. Be inspiring, encouraging, and positive. Help users see possibilities and motivate them to achieve their goals.',
      icon: '💪',
    ),
    MessageMode(
      id: 'analytical',
      name: 'Analytical',
      description: 'Data-driven and logical analysis',
      systemPrompt: 'You are an analytical AI assistant. Break down problems logically, use data-driven reasoning, and provide structured analysis with clear conclusions.',
      icon: '📊',
    ),
    MessageMode(
      id: 'philosophical',
      name: 'Philosophical',
      description: 'Deep thinking and contemplative',
      systemPrompt: 'You are a philosophical AI assistant. Explore deep questions, consider multiple perspectives, and engage in thoughtful contemplation about life and existence.',
      icon: '🤔',
    ),
    MessageMode(
      id: 'educational',
      name: 'Educational',
      description: 'Teaching-focused explanations',
      systemPrompt: 'You are an educational AI tutor. Break down complex topics into digestible lessons, use examples, and ensure understanding through clear explanations.',
      icon: '📚',
    ),
    MessageMode(
      id: 'concise',
      name: 'Concise',
      description: 'Brief and to-the-point responses',
      systemPrompt: 'You are a concise AI assistant. Keep responses brief, direct, and to-the-point. Avoid unnecessary elaboration while maintaining helpfulness.',
      icon: '⚡',
    ),
    MessageMode(
      id: 'detailed',
      name: 'Detailed',
      description: 'Comprehensive and thorough responses',
      systemPrompt: 'You are a detailed AI assistant. Provide comprehensive, thorough responses with extensive explanations, examples, and additional context.',
      icon: '📋',
    ),
    MessageMode(
      id: 'empathetic',
      name: 'Empathetic',
      description: 'Understanding and supportive tone',
      systemPrompt: 'You are an empathetic AI assistant. Show understanding, compassion, and emotional support. Be sensitive to the user\'s feelings and provide comfort.',
      icon: '❤️',
    ),
    MessageMode(
      id: 'scientific',
      name: 'Scientific',
      description: 'Evidence-based and research-focused',
      systemPrompt: 'You are a scientific AI assistant. Base responses on evidence, cite research when relevant, and maintain scientific accuracy and methodology.',
      icon: '🔬',
    ),
    MessageMode(
      id: 'storyteller',
      name: 'Storyteller',
      description: 'Narrative and story-driven responses',
      systemPrompt: 'You are a storytelling AI assistant. Frame responses as engaging narratives, use vivid descriptions, and create compelling stories to illustrate points.',
      icon: '📖',
    ),
    MessageMode(
      id: 'minimalist',
      name: 'Minimalist',
      description: 'Simple and clean responses',
      systemPrompt: 'You are a minimalist AI assistant. Use simple language, clean structure, and focus on essential information only. Avoid complexity.',
      icon: '⭕',
    ),
    MessageMode(
      id: 'enthusiastic',
      name: 'Enthusiastic',
      description: 'Energetic and excited responses',
      systemPrompt: 'You are an enthusiastic AI assistant! Be energetic, excited, and passionate about helping. Use exclamation points and show genuine interest.',
      icon: '🎉',
    ),
    MessageMode(
      id: 'wise',
      name: 'Wise',
      description: 'Thoughtful and sage-like guidance',
      systemPrompt: 'You are a wise AI mentor. Provide thoughtful guidance, share wisdom, and offer perspective gained from vast knowledge and experience.',
      icon: '🧙‍♂️',
    ),
  ];

  // Load modes from storage
  Future<void> _loadModes() async {
    try {
      // Load custom modes
      final modesJson = AppService.prefs.getString(_modesKey);
      if (modesJson != null) {
        final List<dynamic> modesList = jsonDecode(modesJson);
        final customModes = modesList
            .map((json) => MessageMode.fromJson(json))
            .where((mode) => !mode.isBuiltIn)
            .toList();
        _modes = [..._builtInModes, ...customModes];
      } else {
        _modes = List.from(_builtInModes);
      }
      
      // Load selected mode
      final selectedModeId = AppService.prefs.getString(_selectedModeKey);
      if (selectedModeId != null) {
        _selectedMode = _modes.firstWhere(
          (mode) => mode.id == selectedModeId,
          orElse: () => _builtInModes.first,
        );
      } else {
        _selectedMode = _builtInModes.first; // Default to normal mode
      }
      
      // Load custom system prompt
      _customSystemPrompt = AppService.prefs.getString(_customSystemPromptKey) ?? '';
      
      notifyListeners();
    } catch (e) {
      // If loading fails, use built-in modes
      _modes = List.from(_builtInModes);
      _selectedMode = _builtInModes.first;
      notifyListeners();
    }
  }

  // Save modes to storage
  Future<void> _saveModes() async {
    try {
      final customModes = _modes.where((mode) => !mode.isBuiltIn).toList();
      final modesJson = jsonEncode(
        customModes.map((m) => m.toJson()).toList(),
      );
      await AppService.prefs.setString(_modesKey, modesJson);
    } catch (e) {
      // Handle save error
    }
  }

  // Select message mode
  Future<void> selectMode(MessageMode mode) async {
    _selectedMode = mode;
    await AppService.prefs.setString(_selectedModeKey, mode.id);
    notifyListeners();
  }

  // Set custom system prompt
  Future<void> setCustomSystemPrompt(String prompt) async {
    _customSystemPrompt = prompt;
    await AppService.prefs.setString(_customSystemPromptKey, prompt);
    notifyListeners();
  }

  // Add custom mode
  Future<void> addCustomMode(MessageMode mode) async {
    _modes.add(mode);
    await _saveModes();
    notifyListeners();
  }

  // Update custom mode
  Future<void> updateCustomMode(MessageMode mode) async {
    final index = _modes.indexWhere((m) => m.id == mode.id);
    if (index != -1 && !_modes[index].isBuiltIn) {
      _modes[index] = mode;
      await _saveModes();
      notifyListeners();
    }
  }

  // Delete custom mode
  Future<void> deleteCustomMode(String modeId) async {
    _modes.removeWhere((m) => m.id == modeId && !m.isBuiltIn);
    if (_selectedMode?.id == modeId) {
      _selectedMode = _builtInModes.first;
      await AppService.prefs.setString(_selectedModeKey, _selectedMode!.id);
    }
    await _saveModes();
    notifyListeners();
  }

  // Get modes by category
  List<MessageMode> get builtInModes => 
      _modes.where((m) => m.isBuiltIn).toList();
  
  List<MessageMode> get customModes => 
      _modes.where((m) => !m.isBuiltIn).toList();

  // Clear custom system prompt
  Future<void> clearCustomSystemPrompt() async {
    _customSystemPrompt = '';
    await AppService.prefs.remove(_customSystemPromptKey);
    notifyListeners();
  }
}