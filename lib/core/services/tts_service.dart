import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum TtsState { playing, stopped, paused }

class TtsService extends ChangeNotifier {
  static final TtsService _instance = TtsService._internal();
  static TtsService get instance => _instance;
  TtsService._internal() {
    _initTts();
  }

  final FlutterTts _flutterTts = FlutterTts();
  TtsState _ttsState = TtsState.stopped;
  String _currentMessageId = '';

  TtsState get ttsState => _ttsState;
  String get currentMessageId => _currentMessageId;

  void _initTts() {
    _flutterTts.setStartHandler(() {
      _ttsState = TtsState.playing;
      notifyListeners();
    });

    _flutterTts.setCompletionHandler(() {
      _ttsState = TtsState.stopped;
      _currentMessageId = '';
      notifyListeners();
    });

    _flutterTts.setErrorHandler((msg) {
      _ttsState = TtsState.stopped;
      _currentMessageId = '';
      notifyListeners();
    });
  }

  Future<void> speak(String text, String messageId) async {
    if (_ttsState == TtsState.playing) {
      await stop();
      if (messageId == _currentMessageId) {
        // If the same message is tapped again, stop it.
        _currentMessageId = '';
        return;
      }
    }

    _currentMessageId = messageId;
    await _flutterTts.speak(text);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    _ttsState = TtsState.stopped;
    _currentMessageId = '';
    notifyListeners();
  }
}
