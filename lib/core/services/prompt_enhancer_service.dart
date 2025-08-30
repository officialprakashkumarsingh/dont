import 'dart:async';
import 'api_service.dart';

class PromptEnhancerService {
  // Cache for enhanced prompts to avoid repeated API calls
  static final Map<String, String> _enhancementCache = {};
  
  static Future<String> enhancePrompt(
    String originalPrompt, 
    String selectedModel,
  ) async {
    // Check cache first
    if (_enhancementCache.containsKey(originalPrompt)) {
      return _enhancementCache[originalPrompt]!;
    }
    
    try {
      final enhancementPrompt = '''
Enhance this user prompt to be more effective for AI interaction. Make it:
1. Clear and specific
2. Well-structured
3. Include relevant context
4. Maintain the original intent

Original prompt: "$originalPrompt"

Return only the enhanced version, no explanations:''';

      final stream = await ApiService.sendMessage(
        message: enhancementPrompt,
        model: selectedModel,
      );
      
      String enhancedPrompt = '';
      await for (final chunk in stream) {
        enhancedPrompt += chunk;
      }
      
      // Clean up the response
      enhancedPrompt = enhancedPrompt.trim();
      if (enhancedPrompt.startsWith('"') && enhancedPrompt.endsWith('"')) {
        enhancedPrompt = enhancedPrompt.substring(1, enhancedPrompt.length - 1);
      }
      
      // Cache the result
      _enhancementCache[originalPrompt] = enhancedPrompt;
      
      return enhancedPrompt.isNotEmpty ? enhancedPrompt : originalPrompt;
    } catch (e) {
      // Return original prompt if enhancement fails
      return originalPrompt;
    }
  }
  
  static void clearCache() {
    _enhancementCache.clear();
  }
  
  // Check if prompt might benefit from enhancement
  static bool shouldSuggestEnhancement(String prompt) {
    final trimmed = prompt.trim();
    
    // Don't suggest for very short or very long prompts
    if (trimmed.length < 10 || trimmed.length > 500) return false;
    
    // Don't suggest for prompts that already seem well-structured
    if (trimmed.contains('\n') || 
        trimmed.contains(':') || 
        trimmed.split(' ').length > 20) return false;
    
    // Don't suggest for template shortcuts
    if (trimmed.startsWith('/')) return false;
    
    return true;
  }
}