import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/message_model.dart';
import '../models/image_message_model.dart';
import '../models/vision_message_model.dart';
import '../models/diagram_message_model.dart';
import '../models/presentation_message_model.dart';
import '../models/chart_message_model.dart';
import '../models/flashcard_message_model.dart';
import '../models/quiz_message_model.dart';
import '../models/vision_analysis_message_model.dart';
import '../models/file_upload_message_model.dart';
import 'app_service.dart';

class ChatSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final int messageCount;
  final String? lastUserMessage;
  final bool? isPinned;
  List<Message>? messages; // Cache for messages

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.isActive,
    required this.messageCount,
    this.lastUserMessage,
    this.isPinned,
    this.messages,
  });

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'],
      title: json['title'] ?? 'New Chat',
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      isActive: json['is_active'] ?? true,
      messageCount: json['message_count'] ?? 0,
      lastUserMessage: json['last_user_message'],
      isPinned: json['is_pinned'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_active': isActive,
      'message_count': messageCount,
    };
  }
}

class ChatHistoryService extends ChangeNotifier {
  static final ChatHistoryService _instance = ChatHistoryService._internal();
  static ChatHistoryService get instance => _instance;
  
  ChatHistoryService._internal();

  final _supabase = AppService.supabase;
  
  String? _currentSessionId;
  List<ChatSession> _sessions = [];
  bool _isLoading = false;
  
  String? get currentSessionId => _currentSessionId;
  List<ChatSession> get sessions => _sessions;
  bool get isLoading => _isLoading;

  // Initialize and load sessions
  Future<void> initialize() async {
    await loadSessions();
    await getOrCreateActiveSession();
  }

  // Load all chat sessions for current user
  Future<void> loadSessions() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      
      final response = await _supabase
          .from('chat_session_summaries')
          .select()
          .eq('user_id', userId)
          .order('is_pinned', ascending: false)
          .order('updated_at', ascending: false);
      
      _sessions = (response as List)
          .map((json) => ChatSession.fromJson(json))
          .toList();
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('Error loading sessions: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get or create active session
  Future<String?> getOrCreateActiveSession() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;
      
      // Check for existing active session
      final existingSession = _sessions.firstWhere(
        (s) => s.isActive,
        orElse: () => ChatSession(
          id: '',
          title: 'New Chat',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isActive: false,
          messageCount: 0,
        ),
      );
      
      if (existingSession.id.isNotEmpty) {
        _currentSessionId = existingSession.id;
        return _currentSessionId;
      }
      
      // Create new session
      final response = await _supabase
          .from('chat_sessions')
          .insert({
            'user_id': userId,
            'title': 'New Chat',
            'is_active': true,
          })
          .select()
          .single();
      
      _currentSessionId = response['id'];
      await loadSessions();
      return _currentSessionId;
    } catch (e) {
      print('Error getting/creating session: $e');
      return null;
    }
  }

  // Create new chat session
  Future<String?> createNewSession() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;
      
      // Deactivate current session
      if (_currentSessionId != null) {
        await _supabase
            .from('chat_sessions')
            .update({'is_active': false})
            .eq('id', _currentSessionId!);
      }
      
      // Create new session
      final response = await _supabase
          .from('chat_sessions')
          .insert({
            'user_id': userId,
            'title': 'New Chat',
            'is_active': true,
          })
          .select()
          .single();
      
      _currentSessionId = response['id'];
      await loadSessions();
      notifyListeners(); // This will trigger the ChatPage to clear messages
      return _currentSessionId;
    } catch (e) {
      print('Error creating new session: $e');
      return null;
    }
  }

  // Switch to a different session
  Future<List<Message>> switchToSession(String sessionId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];
      
      // Deactivate current session
      if (_currentSessionId != null && _currentSessionId != sessionId) {
        await _supabase
            .from('chat_sessions')
            .update({'is_active': false})
            .eq('id', _currentSessionId!);
      }
      
      // Activate new session
      await _supabase
          .from('chat_sessions')
          .update({'is_active': true})
          .eq('id', sessionId);
      
      _currentSessionId = sessionId;
      
      // Load messages for this session
      final messages = await loadSessionMessages(sessionId);
      
      await loadSessions();
      notifyListeners();
      
      return messages;
    } catch (e) {
      print('Error switching session: $e');
      return [];
    }
  }

  // Load messages for a specific session
  Future<List<Message>> loadSessionMessages(String sessionId) async {
    try {
      final response = await _supabase
          .from('chat_messages')
          .select() // Select all columns, metadata will be a JSON object
          .eq('session_id', sessionId)
          .order('created_at', ascending: true);
      
      final messages = (response as List).map<Message>((json) {
        final metadata = json['metadata'] as Map<String, dynamic>?;
        final messageType = metadata?['type'] as String?;

        switch (messageType) {
          case 'image':
            return ImageMessage.fromJson(json, metadata!);
          case 'vision':
            return VisionMessage.fromJson(json, metadata!);
          case 'diagram':
            return DiagramMessage.fromJson(json, metadata!);
          case 'presentation':
            return PresentationMessage.fromJson(json, metadata!);
          case 'chart':
            return ChartMessage.fromJson(json, metadata!);
          case 'flashcard':
            return FlashcardMessage.fromJson(json, metadata!);
          case 'quiz':
            return QuizMessage.fromJson(json, metadata!);
          default:
            return Message(
              id: json['id'],
              content: json['content'],
              type: json['role'] == 'user' ? MessageType.user : MessageType.assistant,
              timestamp: DateTime.parse(json['created_at']),
              hasError: json['hasError'] ?? false,
            );
        }
      }).toList();
      
      // Cache messages in the session
      final sessionIndex = _sessions.indexWhere((s) => s.id == sessionId);
      if (sessionIndex != -1) {
        _sessions[sessionIndex].messages = messages;
      }
      
      return messages;
    } catch (e) {
      print('Error loading messages: $e');
      return [];
    }
  }
  
  // Load messages for all sessions (for searching)
  Future<void> loadAllSessionMessages() async {
    try {
      for (var session in _sessions) {
        if (session.messages == null) {
          session.messages = await loadSessionMessages(session.id);
        }
      }
      notifyListeners();
    } catch (e) {
      print('Error loading all messages: $e');
    }
  }

  // Save message to current session
  Future<void> saveMessage(Message message, {String? modelName}) async {
    try {
      if (_currentSessionId == null) {
        print('Warning: No active session for saving message');
        return;
      }
      
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      
      final Map<String, dynamic> data = {
        'session_id': _currentSessionId,
        'user_id': userId,
        'content': message.content,
        'role': message.type == MessageType.user ? 'user' : 'assistant',
        'model_name': modelName,
        'metadata': {},
      };

      // Add specific metadata based on message type
      if (message is ImageMessage) {
        data['metadata'] = {
          'type': 'image',
          'prompt': message.prompt,
          'model': message.model,
          'imageUrl': message.imageUrl,
        };
      } else if (message is VisionMessage) {
        data['metadata'] = {
          'type': 'vision',
          'prompt': message.analysisPrompt,
          'imageData': message.imageData,
        };
      } else if (message is DiagramMessage) {
        data['metadata'] = {
          'type': 'diagram',
          'prompt': message.prompt,
          'mermaidCode': message.mermaidCode,
        };
      } else if (message is PresentationMessage) {
        data['metadata'] = {
          'type': 'presentation',
          'prompt': message.prompt,
          'slides': message.slides.map((s) => s.toJson()).toList(),
        };
      } else if (message is ChartMessage) {
        data['metadata'] = {
          'type': 'chart',
          'prompt': message.prompt,
          'chartConfig': message.chartConfig,
        };
      } else if (message is FlashcardMessage) {
        data['metadata'] = {
          'type': 'flashcard',
          'prompt': message.prompt,
          'flashcards': message.flashcards.map((f) => f.toJson()).toList(),
        };
      } else if (message is QuizMessage) {
        data['metadata'] = {
          'type': 'quiz',
          'prompt': message.prompt,
          'questions': message.questions.map((q) => q.toJson()).toList(),
        };
      }

      await _supabase.from('chat_messages').insert(data);
      
    } catch (e) {
      print('Error saving message: $e');
    }
  }

  // Delete a session
  Future<void> deleteSession(String sessionId) async {
    try {
      await _supabase
          .from('chat_sessions')
          .delete()
          .eq('id', sessionId);
      
      if (_currentSessionId == sessionId) {
        _currentSessionId = null;
        await getOrCreateActiveSession();
      }
      
      await loadSessions();
      notifyListeners();
    } catch (e) {
      print('Error deleting session: $e');
    }
  }

  // Clear all sessions for current user
  Future<void> clearAllSessions() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      
      await _supabase
          .from('chat_sessions')
          .delete()
          .eq('user_id', userId);
      
      _sessions.clear();
      _currentSessionId = null;
      await getOrCreateActiveSession();
      notifyListeners();
    } catch (e) {
      print('Error clearing sessions: $e');
    }
  }
  
  // Rename a session
  Future<void> renameSession(String sessionId, String newTitle) async {
    try {
      await _supabase
          .from('chat_sessions')
          .update({'title': newTitle})
          .eq('id', sessionId);
      
      await loadSessions();
      notifyListeners();
    } catch (e) {
      print('Error renaming session: $e');
    }
  }
  
  // Toggle pin status of a session
  Future<void> togglePinSession(String sessionId) async {
    try {
      final session = _sessions.firstWhere((s) => s.id == sessionId);
      final newPinStatus = !(session.isPinned ?? false);
      
      await _supabase
          .from('chat_sessions')
          .update({'is_pinned': newPinStatus})
          .eq('id', sessionId);
      
      await loadSessions();
      notifyListeners();
    } catch (e) {
      print('Error toggling pin status: $e');
    }
  }
}