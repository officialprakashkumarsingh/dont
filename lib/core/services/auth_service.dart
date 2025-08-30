import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart' as app_models;
import 'app_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  static AuthService get instance => _instance;
  
  AuthService._internal();

  final _supabase = AppService.supabase;
  
  final StreamController<app_models.User?> _userController = StreamController<app_models.User?>.broadcast();
  Stream<app_models.User?> get userStream => _userController.stream;
  
  app_models.User? _currentUser;
  app_models.User? get currentUser => _currentUser;
  
  bool get isAuthenticated => _supabase.auth.currentUser != null;

  Future<void> initialize() async {
    // Listen to auth state changes
    _supabase.auth.onAuthStateChange.listen((data) {
      final user = data.session?.user;
      if (user != null) {
        _currentUser = app_models.User(
          id: user.id,
          email: user.email ?? '',
          name: user.userMetadata?['name'] ?? user.email?.split('@').first ?? 'User',
          createdAt: DateTime.parse(user.createdAt),
        );
        _userController.add(_currentUser);
      } else {
        _currentUser = null;
        _userController.add(null);
      }
    });
    
    // Check if user is already logged in
    final user = _supabase.auth.currentUser;
    if (user != null) {
      _currentUser = app_models.User(
        id: user.id,
        email: user.email ?? '',
        name: user.userMetadata?['name'] ?? user.email?.split('@').first ?? 'User',
        createdAt: DateTime.parse(user.createdAt),
      );
      _userController.add(_currentUser);
    }
  }

  Future<app_models.User?> signIn(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      if (response.user != null) {
        final user = app_models.User(
          id: response.user!.id,
          email: response.user!.email ?? '',
          name: response.user!.userMetadata?['name'] ?? email.split('@').first,
          createdAt: DateTime.parse(response.user!.createdAt),
        );
        
        _currentUser = user;
        _userController.add(user);
        
        return user;
      }
      return null;
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Sign in failed: $e');
    }
  }

  Future<app_models.User?> signUp(String name, String email, String password) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'name': name}, // Store name in user metadata
      );
      
      if (response.user != null) {
        final user = app_models.User(
          id: response.user!.id,
          email: response.user!.email ?? '',
          name: name,
          createdAt: DateTime.parse(response.user!.createdAt),
        );
        
        _currentUser = user;
        _userController.add(user);
        
        return user;
      }
      return null;
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Sign up failed: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      _currentUser = null;
      _userController.add(null);
    } catch (e) {
      throw Exception('Sign out failed: $e');
    }
  }

  void dispose() {
    _userController.close();
  }
}