import 'core/services/image_service.dart';

void main() async {
  print('Testing AhamAI Image Generation API...\n');
  
  // Test 1: Get available models
  print('1. Fetching available image models...');
  final models = await ImageService.getImageModels();
  
  if (models.isNotEmpty) {
    print('✅ Found ${models.length} image models:');
    for (final model in models) {
      print('   - ${model.id}: ${model.name} (${model.provider})');
    }
  } else {
    print('❌ No image models found');
    return;
  }
  
  print('\n2. Testing image generation with each model...');
  
  // Test 2: Test each model
  final testResults = await ImageService.testAllModels();
  
  print('\n📊 Test Results:');
  testResults.forEach((modelId, success) {
    final status = success ? '✅ Working' : '❌ Failed';
    print('   $modelId: $status');
  });
  
  // Test 3: Generate a test image with working model
  final workingModels = testResults.entries
      .where((entry) => entry.value)
      .map((entry) => entry.key)
      .toList();
  
  if (workingModels.isNotEmpty) {
    print('\n3. Generating test image with ${workingModels.first}...');
    final imageUrl = await ImageService.generateImage(
      prompt: 'a beautiful landscape with mountains and lake',
      model: workingModels.first,
    );
    
    if (imageUrl != null) {
      print('✅ Image generated successfully!');
      print('🖼️ Image URL: $imageUrl');
    } else {
      print('❌ Image generation failed');
    }
  }
  
  print('\n🎯 Summary:');
  print('Available models: ${models.length}');
  print('Working models: ${testResults.values.where((v) => v).length}');
  print('API endpoint: https://ahamai-api.officialprakashkrsingh.workers.dev/v1/images/');
}