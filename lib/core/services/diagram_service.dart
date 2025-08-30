import 'dart:convert';
import 'package:flutter/foundation.dart';

class DiagramService extends ChangeNotifier {
  static final DiagramService _instance = DiagramService._internal();
  static DiagramService get instance => _instance;
  
  DiagramService._internal();

  // Supported diagram types
  static const List<DiagramType> supportedTypes = [
    DiagramType(
      id: 'flowchart',
      name: 'Flowchart',
      description: 'Create flowcharts and process diagrams',
      example: '''graph TD
    A[Start] --> B{Is it?}
    B -->|Yes| C[OK]
    B -->|No| D[End]''',
      icon: '📊',
    ),
    DiagramType(
      id: 'sequence',
      name: 'Sequence Diagram',
      description: 'Show interactions between components',
      example: '''sequenceDiagram
    Alice->>John: Hello John
    John-->>Alice: Hi Alice!''',
      icon: '🔄',
    ),
    DiagramType(
      id: 'gantt',
      name: 'Gantt Chart',
      description: 'Project timeline and task scheduling',
      example: '''gantt
    title A Gantt Diagram
    dateFormat YYYY-MM-DD
    section Section
    Task 1: a1, 2024-01-01, 30d
    Task 2: after a1, 20d''',
      icon: '📅',
    ),
    DiagramType(
      id: 'pie',
      name: 'Pie Chart',
      description: 'Show proportions and percentages',
      example: '''pie title Pets
    "Dogs" : 386
    "Cats" : 85
    "Rats" : 15''',
      icon: '🥧',
    ),
    DiagramType(
      id: 'mindmap',
      name: 'Mind Map',
      description: 'Organize ideas and concepts',
      example: '''mindmap
  root((mindmap))
    Origins
      Long history
      Popularisation
    Research
      On effectiveness
      On features''',
      icon: '🧠',
    ),
    DiagramType(
      id: 'er',
      name: 'Entity Relationship',
      description: 'Database schema and relationships',
      example: '''erDiagram
    CUSTOMER ||--o{ ORDER : places
    ORDER ||--|{ LINE-ITEM : contains
    CUSTOMER {
        string name
        string id
    }''',
      icon: '🗄️',
    ),
    DiagramType(
      id: 'class',
      name: 'Class Diagram',
      description: 'Object-oriented design and structure',
      example: '''classDiagram
    Animal <|-- Duck
    Animal <|-- Fish
    Animal : +int age
    Animal : +String gender
    Animal: +isMammal()''',
      icon: '📦',
    ),
    DiagramType(
      id: 'state',
      name: 'State Diagram',
      description: 'State machines and transitions',
      example: '''stateDiagram-v2
    [*] --> Still
    Still --> [*]
    Still --> Moving
    Moving --> Still
    Moving --> Crash
    Crash --> [*]''',
      icon: '🔀',
    ),
    DiagramType(
      id: 'git',
      name: 'Git Graph',
      description: 'Visualize git branches and commits',
      example: '''gitGraph
    commit
    branch develop
    checkout develop
    commit
    checkout main
    merge develop''',
      icon: '🌳',
    ),
    DiagramType(
      id: 'journey',
      name: 'User Journey',
      description: 'Map user experiences and touchpoints',
      example: '''journey
    title My working day
    section Go to work
      Make tea: 5: Me
      Go upstairs: 3: Me
      Do work: 1: Me, Cat
    section Go home
      Go downstairs: 5: Me
      Sit down: 5: Me''',
      icon: '🗺️',
    ),
  ];

  // Generate Mermaid diagram URL with multiple fallback services
  static String generateDiagramUrl(String mermaidCode, {bool useFallback = false, bool highQuality = false}) {
    try {
      // Clean and validate the code
      final cleanCode = _cleanMermaidCode(mermaidCode);
      if (cleanCode.isEmpty) {
        return '';
      }

      // Use base64 encoding for both to avoid URL length issues
      final encodedCode = base64.encode(utf8.encode(cleanCode));
      
      // Define a high-contrast light theme for better export quality
      final themeJson = jsonEncode({
        "theme": "neutral",
        "themeVariables": {
          "background": "#FFFFFF",
          "primaryColor": "#FFFFFF",
          "primaryTextColor": "#000000",
          "lineColor": "#333333",
          "textColor": "#000000",
          "fontSize": "18px"
        }
      });
      final encodedTheme = base64.encode(utf8.encode(themeJson));

      // Always use the same reliable format and append the theme
      return 'https://mermaid.ink/img/$encodedCode?type=png&theme=$encodedTheme';
    } catch (e) {
      print('Error generating diagram URL: $e');
      return '';
    }
  }

  // Alternative: Generate using Mermaid Live Editor
  static String generateLiveEditorUrl(String mermaidCode) {
    try {
      final cleanCode = _cleanMermaidCode(mermaidCode);
      final compressed = _compressCode(cleanCode);
      final encoded = Uri.encodeComponent(compressed);
      return 'https://mermaid.live/edit#pako:$encoded';
    } catch (e) {
      return '';
    }
  }

  // Clean and validate Mermaid code
  static String _cleanMermaidCode(String code) {
    // Remove leading/trailing whitespace
    String cleaned = code.trim();
    
    // Ensure it starts with a valid diagram type
    if (!_isValidMermaidCode(cleaned)) {
      // Try to fix common issues
      cleaned = fixCommonIssues(cleaned);
    }
    
    return cleaned;
  }

  // Validate Mermaid code
  static bool _isValidMermaidCode(String code) {
    final validStarts = [
      'graph', 'flowchart', 'sequenceDiagram', 'gantt', 'pie',
      'mindmap', 'erDiagram', 'classDiagram', 'stateDiagram',
      'gitGraph', 'journey', 'quadrantChart', 'requirement',
      'C4Context', 'timeline'
    ];
    
    return validStarts.any((start) => 
      code.startsWith(start) || code.startsWith('%%'));
  }

  // Fix common Mermaid code issues
  static String fixCommonIssues(String code) {
    String fixed = code.trim();
    
    // Remove any markdown code block markers if present
    fixed = fixed.replaceAll(RegExp(r'```mermaid\s*', caseSensitive: false), '');
    fixed = fixed.replaceAll(RegExp(r'```\s*'), '');
    
    // If no diagram type specified, try to infer or default to flowchart
    if (!_isValidMermaidCode(fixed)) {
      // Check for common patterns and add appropriate header
      if (fixed.contains('-->') || fixed.contains('->')) {
        // Flowchart patterns
        fixed = 'graph TD\n    $fixed';
      } else if (fixed.contains('->>') || fixed.contains('-->>')) {
        // Sequence diagram patterns
        fixed = 'sequenceDiagram\n    $fixed';
      } else if (fixed.contains('pie title') || fixed.contains('"') && fixed.contains(':')) {
        // Pie chart pattern
        if (!fixed.startsWith('pie')) {
          fixed = 'pie title Chart\n    $fixed';
        }
      } else if (fixed.contains('gantt')) {
        // Gantt chart
        if (!fixed.startsWith('gantt')) {
          fixed = 'gantt\n    $fixed';
        }
      } else {
        // Default to flowchart
        fixed = 'graph TD\n    A[Start] --> B[Process]\n    B --> C[End]';
      }
    }
    
    // Fix indentation issues
    final lines = fixed.split('\n');
    final fixedLines = <String>[];
    bool inDiagramDef = false;
    
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      
      // Check if this is a diagram type declaration
      if (_isValidMermaidCode(trimmed)) {
        fixedLines.add(trimmed);
        inDiagramDef = true;
      } else if (inDiagramDef) {
        // Add proper indentation for diagram content
        if (!line.startsWith('    ') && !line.startsWith('\t')) {
          fixedLines.add('    $trimmed');
        } else {
          fixedLines.add(line);
        }
      } else {
        fixedLines.add(trimmed);
      }
    }
    
    return fixedLines.join('\n');
  }

  // Simple compression for URL (using base64)
  static String _compressCode(String code) {
    try {
      final bytes = utf8.encode(code);
      return base64.encode(bytes);
    } catch (e) {
      return code;
    }
  }

  // Generate prompt for AI to create diagram
  static String generateDiagramPrompt(DiagramType type, String description) {
    return '''Create a Mermaid ${type.name} diagram for: $description

Requirements:
1. Use valid Mermaid syntax for ${type.id} diagram type
2. Make it clear and well-structured
3. Include appropriate labels and connections
4. Keep it concise but comprehensive
5. Start with the diagram type declaration

Example format:
${type.example}

Generate only the Mermaid code without any explanations or markdown code blocks.''';
  }

  // Extract Mermaid code from AI response
  static String extractMermaidCode(String response) {
    // Remove markdown code blocks if present
    String code = response;
    
    // Remove ```mermaid and ``` markers
    code = code.replaceAll(RegExp(r'```mermaid\s*'), '');
    code = code.replaceAll(RegExp(r'```\s*'), '');
    
    // Remove any leading/trailing text that's not part of the diagram
    final lines = code.split('\n');
    final diagramLines = <String>[];
    bool inDiagram = false;
    
    for (final line in lines) {
      final trimmed = line.trim();
      if (_isValidMermaidCode(trimmed) || trimmed.startsWith('%%')) {
        inDiagram = true;
      }
      
      if (inDiagram) {
        diagramLines.add(line);
        // Check for natural end of diagram
        if (trimmed.isEmpty && diagramLines.length > 3) {
          // Check if next non-empty line is not part of diagram
          final remaining = lines.sublist(lines.indexOf(line) + 1);
          final nextNonEmpty = remaining.firstWhere(
            (l) => l.trim().isNotEmpty,
            orElse: () => '',
          );
          if (nextNonEmpty.isNotEmpty && 
              !nextNonEmpty.contains('-->') && 
              !nextNonEmpty.contains('->>') &&
              !nextNonEmpty.contains('|||') &&
              !RegExp(r'^[A-Z][A-Za-z0-9]*(\[|\{|\()').hasMatch(nextNonEmpty.trim())) {
            break;
          }
        }
      }
    }
    
    return diagramLines.join('\n').trim();
  }

  // Validate and get preview URL with fallback
  static Future<String> getValidPreviewUrl(String mermaidCode) async {
    try {
      // First try primary service
      String url = generateDiagramUrl(mermaidCode, useFallback: false);
      
      // If primary fails or is empty, try fallback
      if (url.isEmpty) {
        url = generateDiagramUrl(mermaidCode, useFallback: true);
      }
      
      return url;
    } catch (e) {
      print('Error getting preview URL: $e');
      return '';
    }
  }
}

class DiagramType {
  final String id;
  final String name;
  final String description;
  final String example;
  final String icon;

  const DiagramType({
    required this.id,
    required this.name,
    required this.description,
    required this.example,
    required this.icon,
  });
}