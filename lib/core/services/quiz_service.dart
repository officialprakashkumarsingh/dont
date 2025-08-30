import '../models/quiz_message_model.dart';

class QuizService {
  static List<QuizQuestion> extractQuizQuestions(String aiResponse) {
    final questions = <QuizQuestion>[];
    
    // Try to parse JSON format first
    final jsonPattern = RegExp(r'\[[\s\S]*\]', multiLine: true);
    final jsonMatch = jsonPattern.firstMatch(aiResponse);
    
    if (jsonMatch != null) {
      try {
        final jsonStr = jsonMatch.group(0)!;
        final List<dynamic> jsonList = _parseJson(jsonStr);
        
        for (final item in jsonList) {
          if (item is Map<String, dynamic>) {
            final optionsList = item['options'] as List<dynamic>? ?? [];
            final options = optionsList.map((o) => o.toString()).toList();
            
            if (options.isNotEmpty) {
              questions.add(QuizQuestion(
                question: item['question']?.toString() ?? '',
                options: options,
                correctAnswer: item['correctAnswer'] as int? ?? 
                               item['correct'] as int? ?? 0,
                explanation: item['explanation']?.toString(),
              ));
            }
          }
        }
        
        if (questions.isNotEmpty) return questions;
      } catch (e) {
        // Fall back to text parsing
      }
    }
    
    // Parse text format
    final questionPattern = RegExp(
      r'(?:Q\d*:|Question \d*:|\d+\.)?\s*(.+?)(?:\n|$)((?:[A-D]\)|[1-4]\.|[a-d]\)).+(?:\n|$))+.*?(?:Answer:|Correct:)\s*([A-D1-4a-d]).*?(?:Explanation:)?\s*(.+)?',
      multiLine: true,
      caseSensitive: false,
    );
    
    final matches = questionPattern.allMatches(aiResponse);
    
    for (final match in matches) {
      final question = match.group(1)?.trim() ?? '';
      final optionsText = match.group(2) ?? '';
      final correctLetter = match.group(3)?.trim().toUpperCase() ?? 'A';
      final explanation = match.group(4)?.trim();
      
      // Parse options
      final optionPattern = RegExp(r'[A-Da-d1-4][\)\.]\s*(.+)');
      final optionMatches = optionPattern.allMatches(optionsText);
      final options = optionMatches.map((m) => m.group(1)?.trim() ?? '').toList();
      
      if (question.isNotEmpty && options.length >= 2) {
        // Convert correct answer letter to index
        int correctIndex = 0;
        if (correctLetter.contains(RegExp(r'[A-D]'))) {
          correctIndex = correctLetter.codeUnitAt(0) - 'A'.codeUnitAt(0);
        } else if (correctLetter.contains(RegExp(r'[1-4]'))) {
          correctIndex = int.parse(correctLetter) - 1;
        }
        
        questions.add(QuizQuestion(
          question: question,
          options: options,
          correctAnswer: correctIndex.clamp(0, options.length - 1),
          explanation: explanation,
        ));
      }
    }
    
    // If no questions found, generate sample ones
    if (questions.isEmpty) {
      return generateSampleQuiz(aiResponse);
    }
    
    return questions;
  }
  
  static List<dynamic> _parseJson(String jsonStr) {
    // Clean up common JSON issues
    String cleaned = jsonStr
        .replaceAll(RegExp(r',\s*}'), '}')
        .replaceAll(RegExp(r',\s*\]'), ']')
        .replaceAll(RegExp(r'//.*$', multiLine: true), '')
        .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
    
    // Simple JSON parser for quiz format
    final items = <Map<String, dynamic>>[];
    
    // Match question objects
    final objPattern = RegExp(r'\{[^{}]*\}');
    final matches = objPattern.allMatches(cleaned);
    
    for (final match in matches) {
      final objStr = match.group(0)!;
      final obj = <String, dynamic>{};
      
      // Extract question
      final qPattern = RegExp(r'"question"\s*:\s*"([^"]*)"');
      final qMatch = qPattern.firstMatch(objStr);
      if (qMatch != null) {
        obj['question'] = qMatch.group(1);
      }
      
      // Extract options array
      final optPattern = RegExp(r'"options"\s*:\s*\[([^\]]*)\]');
      final optMatch = optPattern.firstMatch(objStr);
      if (optMatch != null) {
        final optStr = optMatch.group(1)!;
        final opts = <String>[];
        final optItemPattern = RegExp(r'"([^"]*)"');
        final optMatches = optItemPattern.allMatches(optStr);
        for (final om in optMatches) {
          opts.add(om.group(1)!);
        }
        obj['options'] = opts;
      }
      
      // Extract correct answer
      final correctPattern = RegExp(r'"(?:correctAnswer|correct)"\s*:\s*(\d+)');
      final correctMatch = correctPattern.firstMatch(objStr);
      if (correctMatch != null) {
        obj['correctAnswer'] = int.parse(correctMatch.group(1)!);
      }
      
      // Extract explanation
      final expPattern = RegExp(r'"explanation"\s*:\s*"([^"]*)"');
      final expMatch = expPattern.firstMatch(objStr);
      if (expMatch != null) {
        obj['explanation'] = expMatch.group(1);
      }
      
      if (obj.containsKey('question') && obj.containsKey('options')) {
        items.add(obj);
      }
    }
    
    return items;
  }
  
  static List<QuizQuestion> generateSampleQuiz(String topic) {
    final topicLower = topic.toLowerCase();
    
    if (topicLower.contains('flutter') || topicLower.contains('dart')) {
      return [
        QuizQuestion(
          question: 'Which company created Flutter?',
          options: ['Facebook', 'Google', 'Microsoft', 'Apple'],
          correctAnswer: 1,
          explanation: 'Google created and maintains Flutter as an open-source project.',
        ),
        QuizQuestion(
          question: 'What is the primary programming language for Flutter?',
          options: ['JavaScript', 'Python', 'Dart', 'Java'],
          correctAnswer: 2,
          explanation: 'Flutter uses Dart as its primary programming language.',
        ),
        QuizQuestion(
          question: 'Flutter can build apps for which platforms?',
          options: [
            'Only mobile (iOS/Android)',
            'Only web',
            'Mobile, web, and desktop',
            'Only desktop',
          ],
          correctAnswer: 2,
          explanation: 'Flutter supports mobile (iOS/Android), web, and desktop (Windows/Mac/Linux) from a single codebase.',
        ),
      ];
    } else if (topicLower.contains('math') || topicLower.contains('science')) {
      return [
        QuizQuestion(
          question: 'What is 2 + 2 × 2?',
          options: ['8', '6', '4', '10'],
          correctAnswer: 1,
          explanation: 'Following order of operations (PEMDAS), multiplication comes before addition: 2 + (2 × 2) = 2 + 4 = 6',
        ),
        QuizQuestion(
          question: 'What is the chemical symbol for water?',
          options: ['O2', 'H2O', 'CO2', 'NaCl'],
          correctAnswer: 1,
          explanation: 'Water is composed of two hydrogen atoms and one oxygen atom: H2O',
        ),
      ];
    } else {
      // Generic quiz
      return [
        QuizQuestion(
          question: 'Sample Question 1: Which option is correct?',
          options: ['Option A', 'Option B (Correct)', 'Option C', 'Option D'],
          correctAnswer: 1,
          explanation: 'Option B is the correct answer for this sample question.',
        ),
        QuizQuestion(
          question: 'Sample Question 2: Select the best answer',
          options: ['Choice 1', 'Choice 2', 'Choice 3 (Correct)', 'Choice 4'],
          correctAnswer: 2,
          explanation: 'Choice 3 is the best answer for this question.',
        ),
        QuizQuestion(
          question: 'Sample Question 3: True or False - This is a sample quiz',
          options: ['True', 'False'],
          correctAnswer: 0,
          explanation: 'True - This is indeed a sample quiz.',
        ),
      ];
    }
  }
}