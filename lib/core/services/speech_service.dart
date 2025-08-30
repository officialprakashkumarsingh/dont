import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

class SpeechService extends ChangeNotifier {
  static final SpeechService _instance = SpeechService._internal();
  static SpeechService get instance => _instance;
  SpeechService._internal();

  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  String _lastWords = '';

  bool get isListening => _isListening;
  String get lastWords => _lastWords;

  Future<void> initialize() async {
    _speechEnabled = await _speechToText.initialize();
    notifyListeners();
  }

  void startListening({required ValueChanged<String> onResult}) {
    if (!_speechEnabled || _isListening) return;
    _isListening = true;
    _speechToText.listen(
      onResult: (SpeechRecognitionResult result) {
        _lastWords = result.recognizedWords;
        onResult(_lastWords);
        if (result.finalResult) {
          _isListening = false;
        }
        notifyListeners();
      },
    );
    notifyListeners();
  }

  void stopListening() {
    if (!_isListening) return;
    _isListening = false;
    _speechToText.stop();
    notifyListeners();
  }
}
