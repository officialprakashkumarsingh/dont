import 'dart:convert';

class ChartService {
  static String generateChartHtml(String chartConfig, bool isDarkMode) {
    final backgroundColor = isDarkMode ? '#1a1a1a' : '#ffffff';
    final textColor = isDarkMode ? '#e0e0e0' : '#333333';
    final gridColor = isDarkMode ? 'rgba(255, 255, 255, 0.1)' : 'rgba(0, 0, 0, 0.1)';
    
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
    <style>
        body {
            margin: 0;
            padding: 20px;
            background-color: $backgroundColor;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        }
        #chartContainer {
            position: relative;
            width: 90vw;
            max-width: 800px;
            height: 500px;
        }
        canvas {
            max-width: 100%;
            height: auto !important;
        }
    </style>
</head>
<body>
    <div id="chartContainer">
        <canvas id="myChart"></canvas>
    </div>
    <script>
        try {
            const ctx = document.getElementById('myChart').getContext('2d');
            
            // Parse the config
            let config = $chartConfig;
            
            // Apply theme colors
            if (!config.options) config.options = {};
            if (!config.options.plugins) config.options.plugins = {};
            if (!config.options.scales) config.options.scales = {};
            
            // Set responsive options
            config.options.responsive = true;
            config.options.maintainAspectRatio = true;
            
            // Theme colors for plugins
            if (!config.options.plugins.legend) config.options.plugins.legend = {};
            config.options.plugins.legend.labels = {
                color: '$textColor',
                font: { size: 14 }
            };
            
            if (!config.options.plugins.title) config.options.plugins.title = {};
            if (config.options.plugins.title.display) {
                config.options.plugins.title.color = '$textColor';
                config.options.plugins.title.font = { size: 18, weight: 'bold' };
            }
            
            // Theme colors for scales
            const scaleConfig = {
                ticks: { color: '$textColor', font: { size: 12 } },
                grid: { color: '$gridColor' },
                title: { color: '$textColor', font: { size: 14 } }
            };
            
            if (config.type === 'bar' || config.type === 'line' || config.type === 'scatter') {
                if (!config.options.scales.x) config.options.scales.x = {};
                if (!config.options.scales.y) config.options.scales.y = {};
                Object.assign(config.options.scales.x, scaleConfig);
                Object.assign(config.options.scales.y, scaleConfig);
            } else if (config.type === 'radar') {
                if (!config.options.scales.r) config.options.scales.r = {};
                Object.assign(config.options.scales.r, {
                    ...scaleConfig,
                    pointLabels: { color: '$textColor', font: { size: 12 } }
                });
            }
            
            // Create the chart
            new Chart(ctx, config);
            
            // Send ready message
            if (window.flutter_inappwebview) {
                window.flutter_inappwebview.callHandler('chartReady', true);
            }
        } catch (error) {
            console.error('Chart error:', error);
            document.body.innerHTML = '<div style="color: $textColor; padding: 20px; text-align: center;">Error loading chart: ' + error.message + '</div>';
            if (window.flutter_inappwebview) {
                window.flutter_inappwebview.callHandler('chartError', error.message);
            }
        }
    </script>
</body>
</html>
''';
  }

  static String extractChartConfig(String aiResponse) {
    // Try to extract JSON config from the response
    final jsonPattern = RegExp(r'```(?:json)?\s*([\s\S]*?)```', multiLine: true);
    final matches = jsonPattern.allMatches(aiResponse);
    
    if (matches.isNotEmpty) {
      final jsonStr = matches.first.group(1)?.trim() ?? '';
      if (jsonStr.isNotEmpty) {
        try {
          // Validate it's valid JSON
          json.decode(jsonStr);
          return jsonStr;
        } catch (e) {
          // Try to fix common issues
          return fixCommonChartIssues(jsonStr);
        }
      }
    }
    
    // Try to find raw JSON in the response
    final jsonObjectPattern = RegExp(r'\{[\s\S]*\}', multiLine: true);
    final jsonMatches = jsonObjectPattern.allMatches(aiResponse);
    
    if (jsonMatches.isNotEmpty) {
      for (final match in jsonMatches) {
        final jsonStr = match.group(0) ?? '';
        try {
          json.decode(jsonStr);
          return jsonStr;
        } catch (e) {
          // Try next match
        }
      }
    }
    
    return '';
  }

  static String fixCommonChartIssues(String chartConfig) {
    String fixed = chartConfig;
    
    // Remove trailing commas
    fixed = fixed.replaceAll(RegExp(r',\s*}'), '}');
    fixed = fixed.replaceAll(RegExp(r',\s*\]'), ']');
    
    // Fix single quotes to double quotes
    fixed = fixed.replaceAllMapped(
      RegExp(r"'([^']*)'"),
      (match) => '"${match.group(1)}"',
    );
    
    // Remove comments
    fixed = fixed.replaceAll(RegExp(r'//.*$', multiLine: true), '');
    fixed = fixed.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
    
    try {
      json.decode(fixed);
      return fixed;
    } catch (e) {
      // If still invalid, return original
      return chartConfig;
    }
  }

  static String generateSampleChart(String prompt) {
    // Generate a sample chart based on the prompt
    final lowerPrompt = prompt.toLowerCase();
    
    if (lowerPrompt.contains('pie')) {
      return _generatePieChart();
    } else if (lowerPrompt.contains('line')) {
      return _generateLineChart();
    } else if (lowerPrompt.contains('scatter')) {
      return _generateScatterChart();
    } else if (lowerPrompt.contains('radar') || lowerPrompt.contains('spider')) {
      return _generateRadarChart();
    } else if (lowerPrompt.contains('doughnut') || lowerPrompt.contains('donut')) {
      return _generateDoughnutChart();
    } else {
      return _generateBarChart();
    }
  }

  static String _generateBarChart() {
    return '''
{
  "type": "bar",
  "data": {
    "labels": ["January", "February", "March", "April", "May", "June"],
    "datasets": [{
      "label": "Sales",
      "data": [65, 59, 80, 81, 56, 55],
      "backgroundColor": [
        "rgba(255, 99, 132, 0.6)",
        "rgba(54, 162, 235, 0.6)",
        "rgba(255, 206, 86, 0.6)",
        "rgba(75, 192, 192, 0.6)",
        "rgba(153, 102, 255, 0.6)",
        "rgba(255, 159, 64, 0.6)"
      ],
      "borderColor": [
        "rgba(255, 99, 132, 1)",
        "rgba(54, 162, 235, 1)",
        "rgba(255, 206, 86, 1)",
        "rgba(75, 192, 192, 1)",
        "rgba(153, 102, 255, 1)",
        "rgba(255, 159, 64, 1)"
      ],
      "borderWidth": 1
    }]
  },
  "options": {
    "plugins": {
      "title": {
        "display": true,
        "text": "Monthly Sales Data"
      }
    },
    "scales": {
      "y": {
        "beginAtZero": true
      }
    }
  }
}
''';
  }

  static String _generateLineChart() {
    return '''
{
  "type": "line",
  "data": {
    "labels": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul"],
    "datasets": [{
      "label": "Growth",
      "data": [10, 25, 30, 45, 60, 75, 90],
      "fill": false,
      "borderColor": "rgb(75, 192, 192)",
      "backgroundColor": "rgba(75, 192, 192, 0.2)",
      "tension": 0.4
    }]
  },
  "options": {
    "plugins": {
      "title": {
        "display": true,
        "text": "Growth Trend"
      }
    }
  }
}
''';
  }

  static String _generatePieChart() {
    return '''
{
  "type": "pie",
  "data": {
    "labels": ["Red", "Blue", "Yellow", "Green", "Purple"],
    "datasets": [{
      "data": [12, 19, 3, 5, 2],
      "backgroundColor": [
        "rgba(255, 99, 132, 0.8)",
        "rgba(54, 162, 235, 0.8)",
        "rgba(255, 206, 86, 0.8)",
        "rgba(75, 192, 192, 0.8)",
        "rgba(153, 102, 255, 0.8)"
      ]
    }]
  },
  "options": {
    "plugins": {
      "title": {
        "display": true,
        "text": "Distribution"
      }
    }
  }
}
''';
  }

  static String _generateScatterChart() {
    return '''
{
  "type": "scatter",
  "data": {
    "datasets": [{
      "label": "Scatter Dataset",
      "data": [
        {"x": -10, "y": 0},
        {"x": 0, "y": 10},
        {"x": 10, "y": 5},
        {"x": 20, "y": 15},
        {"x": 30, "y": 25}
      ],
      "backgroundColor": "rgba(255, 99, 132, 0.6)"
    }]
  },
  "options": {
    "plugins": {
      "title": {
        "display": true,
        "text": "Scatter Plot"
      }
    },
    "scales": {
      "x": {
        "type": "linear",
        "position": "bottom"
      }
    }
  }
}
''';
  }

  static String _generateRadarChart() {
    return '''
{
  "type": "radar",
  "data": {
    "labels": ["Speed", "Reliability", "Comfort", "Safety", "Efficiency"],
    "datasets": [{
      "label": "Model A",
      "data": [85, 90, 75, 88, 92],
      "backgroundColor": "rgba(255, 99, 132, 0.2)",
      "borderColor": "rgba(255, 99, 132, 1)",
      "pointBackgroundColor": "rgba(255, 99, 132, 1)"
    }]
  },
  "options": {
    "plugins": {
      "title": {
        "display": true,
        "text": "Performance Metrics"
      }
    }
  }
}
''';
  }

  static String _generateDoughnutChart() {
    return '''
{
  "type": "doughnut",
  "data": {
    "labels": ["Desktop", "Mobile", "Tablet", "Other"],
    "datasets": [{
      "data": [45, 35, 15, 5],
      "backgroundColor": [
        "rgba(54, 162, 235, 0.8)",
        "rgba(255, 99, 132, 0.8)",
        "rgba(255, 206, 86, 0.8)",
        "rgba(75, 192, 192, 0.8)"
      ]
    }]
  },
  "options": {
    "plugins": {
      "title": {
        "display": true,
        "text": "Device Usage"
      }
    }
  }
}
''';
  }
}