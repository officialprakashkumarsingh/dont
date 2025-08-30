import '../models/flashcard_message_model.dart';

class FlashcardService {
  static List<FlashcardItem> extractFlashcards(String aiResponse) {
    final flashcards = <FlashcardItem>[];
    
    // Try to parse JSON format first
    final jsonPattern = RegExp(r'\[[\s\S]*\]', multiLine: true);
    final jsonMatch = jsonPattern.firstMatch(aiResponse);
    
    if (jsonMatch != null) {
      try {
        final jsonStr = jsonMatch.group(0)!;
        final List<dynamic> jsonList = _parseJson(jsonStr);
        
        for (final item in jsonList) {
          if (item is Map<String, dynamic>) {
            flashcards.add(FlashcardItem(
              question: item['question']?.toString() ?? item['q']?.toString() ?? '',
              answer: item['answer']?.toString() ?? item['a']?.toString() ?? '',
              explanation: item['explanation']?.toString() ?? item['e']?.toString(),
            ));
          }
        }
        
        if (flashcards.isNotEmpty) return flashcards;
      } catch (e) {
        // Fall back to text parsing
      }
    }
    
    // Parse text format (Q: ... A: ... or numbered format)
    final qaPattern = RegExp(
      r'(?:Q\d*:|Question \d*:|\d+\.\s*Question:|\d+\.)?\s*(.+?)(?:\n|$).*?(?:A\d*:|Answer \d*:|\d+\.\s*Answer:)?\s*(.+?)(?:\n|$)(?:.*?(?:E:|Explanation:)\s*(.+?)(?:\n|$))?',
      multiLine: true,
      caseSensitive: false,
    );
    
    final matches = qaPattern.allMatches(aiResponse);
    
    for (final match in matches) {
      final question = match.group(1)?.trim();
      final answer = match.group(2)?.trim();
      final explanation = match.group(3)?.trim();
      
      if (question != null && answer != null && question.isNotEmpty && answer.isNotEmpty) {
        flashcards.add(FlashcardItem(
          question: question,
          answer: answer,
          explanation: explanation,
        ));
      }
    }
    
    // If no flashcards found, generate sample ones
    if (flashcards.isEmpty) {
      return generateSampleFlashcards(aiResponse);
    }
    
    return flashcards;
  }
  
  static List<dynamic> _parseJson(String jsonStr) {
    // Clean up common JSON issues
    String cleaned = jsonStr
        .replaceAll(RegExp(r',\s*}'), '}')
        .replaceAll(RegExp(r',\s*\]'), ']')
        .replaceAll(RegExp(r'//.*$', multiLine: true), '')
        .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
    
    // Try to parse
    try {
      final parsed = _evalJson(cleaned);
      if (parsed is List) return parsed;
    } catch (e) {
      // Try fixing quotes
      cleaned = cleaned.replaceAllMapped(
        RegExp(r"'([^']*)'"),
        (match) => '"${match.group(1)}"',
      );
      
      try {
        final parsed = _evalJson(cleaned);
        if (parsed is List) return parsed;
      } catch (e) {
        // Give up
      }
    }
    
    return [];
  }
  
  static dynamic _evalJson(String str) {
    // Simple JSON parser
    if (str.trim().startsWith('[')) {
      // Parse array
      final items = <Map<String, dynamic>>[];
      final itemPattern = RegExp(r'\{[^}]+\}');
      final matches = itemPattern.allMatches(str);
      
      for (final match in matches) {
        final itemStr = match.group(0)!;
        final item = <String, dynamic>{};
        
        // Parse object properties
        final propPattern = RegExp(r'"?(\w+)"?\s*:\s*"([^"]*)"');
        final propMatches = propPattern.allMatches(itemStr);
        
        for (final propMatch in propMatches) {
          final key = propMatch.group(1)!;
          final value = propMatch.group(2)!;
          item[key] = value;
        }
        
        if (item.isNotEmpty) {
          items.add(item);
        }
      }
      
      return items;
    }
    
    return null;
  }
  
  static List<FlashcardItem> generateSampleFlashcards(String topic) {
    // Generate sample flashcards based on the topic
    final topicLower = topic.toLowerCase();
    
    if (topicLower.contains('flutter') || topicLower.contains('dart')) {
      return [
        FlashcardItem(
          question: 'What is Flutter?',
          answer: 'An open-source UI software development kit created by Google',
          explanation: 'Flutter is used to develop applications for Android, iOS, Linux, Mac, Windows, and the web from a single codebase.',
        ),
        FlashcardItem(
          question: 'What language does Flutter use?',
          answer: 'Dart',
          explanation: 'Dart is a client-optimized programming language for fast apps on multiple platforms.',
        ),
        FlashcardItem(
          question: 'What is a Widget in Flutter?',
          answer: 'The basic building block of a Flutter UI',
          explanation: 'Everything in Flutter is a widget, from a simple text to complex layouts.',
        ),
      ];
    } else if (topicLower.contains('math') || topicLower.contains('algebra')) {
      return [
        FlashcardItem(
          question: 'What is the quadratic formula?',
          answer: 'x = (-b ± √(b² - 4ac)) / 2a',
          explanation: 'Used to solve quadratic equations of the form ax² + bx + c = 0',
        ),
        FlashcardItem(
          question: 'What is the Pythagorean theorem?',
          answer: 'a² + b² = c²',
          explanation: 'In a right triangle, the square of the hypotenuse equals the sum of squares of the other two sides.',
        ),
      ];
    } else {
      // Generic flashcards
      return [
        FlashcardItem(
          question: 'Sample Question 1',
          answer: 'Sample Answer 1',
          explanation: 'This is a sample explanation for the first flashcard.',
        ),
        FlashcardItem(
          question: 'Sample Question 2',
          answer: 'Sample Answer 2',
          explanation: 'This is a sample explanation for the second flashcard.',
        ),
        FlashcardItem(
          question: 'Sample Question 3',
          answer: 'Sample Answer 3',
        ),
      ];
    }
  }
}