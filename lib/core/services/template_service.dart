import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../models/template_model.dart';
import 'app_service.dart';

class TemplateService extends ChangeNotifier {
  static final TemplateService _instance = TemplateService._internal();
  static TemplateService get instance => _instance;
  
  TemplateService._internal() {
    _loadTemplates();
  }

  static const String _templatesKey = 'message_templates';
  
  List<MessageTemplate> _templates = [];
  List<MessageTemplate> get templates => List.unmodifiable(_templates);
  
  List<MessageTemplate> get builtInTemplates => 
      _templates.where((t) => t.isBuiltIn).toList();
  
  List<MessageTemplate> get customTemplates => 
      _templates.where((t) => !t.isBuiltIn).toList();
  
  Map<String, List<MessageTemplate>> get templatesByCategory {
    final Map<String, List<MessageTemplate>> grouped = {};
    for (final template in _templates) {
      grouped.putIfAbsent(template.category, () => []).add(template);
    }
    return grouped;
  }

  // Built-in templates
  static final List<MessageTemplate> _builtInTemplates = [
    // Coding templates
    MessageTemplate(
      id: 'code_review',
      title: 'Code Review',
      content: 'Please review this code and suggest improvements:\n\n```\n[paste your code here]\n```',
      category: 'Coding',
      shortcut: '/review',
      isBuiltIn: true,
      createdAt: DateTime.now(),
    ),
    MessageTemplate(
      id: 'debug_help',
      title: 'Debug Help',
      content: 'I\'m having trouble with this code. Can you help me debug it?\n\nError: [describe the error]\n\nCode:\n```\n[paste your code here]\n```',
      category: 'Coding',
      shortcut: '/debug',
      isBuiltIn: true,
      createdAt: DateTime.now(),
    ),
    MessageTemplate(
      id: 'explain_code',
      title: 'Explain Code',
      content: 'Can you explain how this code works step by step?\n\n```\n[paste your code here]\n```',
      category: 'Coding',
      shortcut: '/explain',
      isBuiltIn: true,
      createdAt: DateTime.now(),
    ),
    
    // Writing templates
    MessageTemplate(
      id: 'proofread',
      title: 'Proofread Text',
      content: 'Please proofread and improve this text:\n\n[paste your text here]',
      category: 'Writing',
      shortcut: '/proofread',
      isBuiltIn: true,
      createdAt: DateTime.now(),
    ),
    MessageTemplate(
      id: 'summarize',
      title: 'Summarize Content',
      content: 'Please provide a concise summary of this content:\n\n[paste your content here]',
      category: 'Writing',
      shortcut: '/summarize',
      isBuiltIn: true,
      createdAt: DateTime.now(),
    ),
    MessageTemplate(
      id: 'translate',
      title: 'Translate Text',
      content: 'Please translate this text to [target language]:\n\n[paste your text here]',
      category: 'Writing',
      shortcut: '/translate',
      isBuiltIn: true,
      createdAt: DateTime.now(),
    ),
    
    // Analysis templates
    MessageTemplate(
      id: 'analyze_data',
      title: 'Analyze Data',
      content: 'Please analyze this data and provide insights:\n\n[paste your data here]',
      category: 'Analysis',
      shortcut: '/analyze',
      isBuiltIn: true,
      createdAt: DateTime.now(),
    ),
    MessageTemplate(
      id: 'compare_options',
      title: 'Compare Options',
      content: 'Please compare these options and help me decide:\n\nOption 1: [describe option 1]\nOption 2: [describe option 2]\n\nCriteria: [what matters to you]',
      category: 'Analysis',
      shortcut: '/compare',
      isBuiltIn: true,
      createdAt: DateTime.now(),
    ),
    
    // Creative templates
    MessageTemplate(
      id: 'brainstorm',
      title: 'Brainstorm Ideas',
      content: 'Help me brainstorm creative ideas for: [describe your project or challenge]',
      category: 'Creative',
      shortcut: '/brainstorm',
      isBuiltIn: true,
      createdAt: DateTime.now(),
    ),
    MessageTemplate(
      id: 'story_prompt',
      title: 'Story Writing',
      content: 'Help me write a story about: [describe your story idea, characters, or setting]',
      category: 'Creative',
      shortcut: '/story',
      isBuiltIn: true,
      createdAt: DateTime.now(),
    ),
    
    // Quick actions
    MessageTemplate(
      id: 'eli5',
      title: 'Explain Like I\'m 5',
      content: 'Please explain this concept in simple terms: [paste your topic here]',
      category: 'Quick',
      shortcut: '/eli5',
      isBuiltIn: true,
      createdAt: DateTime.now(),
    ),
    MessageTemplate(
      id: 'pros_cons',
      title: 'Pros and Cons',
      content: 'What are the pros and cons of: [describe the topic or decision]',
      category: 'Quick',
      shortcut: '/proscons',
      isBuiltIn: true,
      createdAt: DateTime.now(),
    ),
  ];

  // Load templates from storage
  Future<void> _loadTemplates() async {
    try {
      final templatesJson = AppService.prefs.getString(_templatesKey);
      if (templatesJson != null) {
        final List<dynamic> templatesList = jsonDecode(templatesJson);
        _templates = templatesList
            .map((json) => MessageTemplate.fromJson(json))
            .toList();
      }
      
      // Add built-in templates if not already present
      for (final builtInTemplate in _builtInTemplates) {
        if (!_templates.any((t) => t.id == builtInTemplate.id)) {
          _templates.add(builtInTemplate);
        }
      }
      
      // Sort templates: built-in first, then by category
      _templates.sort((a, b) {
        if (a.isBuiltIn && !b.isBuiltIn) return -1;
        if (!a.isBuiltIn && b.isBuiltIn) return 1;
        return a.category.compareTo(b.category);
      });
      
      await _saveTemplates();
      notifyListeners();
    } catch (e) {
      // If loading fails, use built-in templates
      _templates = List.from(_builtInTemplates);
      notifyListeners();
    }
  }

  // Save templates to storage
  Future<void> _saveTemplates() async {
    try {
      final templatesJson = jsonEncode(
        _templates.map((t) => t.toJson()).toList(),
      );
      await AppService.prefs.setString(_templatesKey, templatesJson);
    } catch (e) {
      // Handle save error
    }
  }

  // Add custom template
  Future<void> addTemplate(MessageTemplate template) async {
    _templates.add(template);
    await _saveTemplates();
    notifyListeners();
  }

  // Update template
  Future<void> updateTemplate(MessageTemplate template) async {
    final index = _templates.indexWhere((t) => t.id == template.id);
    if (index != -1) {
      _templates[index] = template;
      await _saveTemplates();
      notifyListeners();
    }
  }

  // Delete template (only custom templates)
  Future<void> deleteTemplate(String templateId) async {
    _templates.removeWhere((t) => t.id == templateId && !t.isBuiltIn);
    await _saveTemplates();
    notifyListeners();
  }

  // Find template by shortcut
  MessageTemplate? findByShortcut(String shortcut) {
    try {
      return _templates.firstWhere(
        (t) => t.shortcut.toLowerCase() == shortcut.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  // Get templates by category
  List<MessageTemplate> getTemplatesByCategory(String category) {
    return _templates.where((t) => t.category == category).toList();
  }

  // Get all categories
  List<String> get categories {
    return _templates.map((t) => t.category).toSet().toList()..sort();
  }
}