import 'package:flutter/material.dart';

import '../../../core/services/model_service.dart';

class ModelSelectorBottomSheet extends StatefulWidget {
  final bool isMultipleSelection;
  
  const ModelSelectorBottomSheet({
    super.key,
    this.isMultipleSelection = false,
  });

  @override
  State<ModelSelectorBottomSheet> createState() => _ModelSelectorBottomSheetState();
}

class _ModelSelectorBottomSheetState extends State<ModelSelectorBottomSheet> {
  @override
  void initState() {
    super.initState();
    // Models are managed by ModelService
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  widget.isMultipleSelection ? 'Select Multiple Models' : 'Select AI Model',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          
          // Models list
          Expanded(
            child: ListenableBuilder(
              listenable: ModelService.instance,
              builder: (context, _) {
                final modelService = ModelService.instance;
                
                if (modelService.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: modelService.availableModels.length,
                  itemBuilder: (context, index) {
                    final model = modelService.availableModels[index];
                    final isSelected = widget.isMultipleSelection
                        ? modelService.selectedModels.contains(model)
                        : model == modelService.selectedModel;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: isSelected 
                            ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                            : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: () {
                            if (widget.isMultipleSelection) {
                              ModelService.instance.toggleModelSelection(model);
                            } else {
                              ModelService.instance.selectModel(model);
                              Navigator.pop(context);
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                // Checkbox for multiple selection
                                if (widget.isMultipleSelection) ...[
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Theme.of(context).colorScheme.primary
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: isSelected
                                        ? Icon(
                                            Icons.check,
                                            color: Theme.of(context).colorScheme.onPrimary,
                                            size: 16,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 16),
                                ],
                                
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _formatModelName(model),
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: isSelected
                                              ? Theme.of(context).colorScheme.primary
                                              : Theme.of(context).colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _getModelDescription(model),
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Single selection check icon
                                if (!widget.isMultipleSelection && isSelected)
                                  Icon(
                                    Icons.check_circle,
                                    color: Theme.of(context).colorScheme.primary,
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatModelName(String model) {
    return model
        .replaceAll('-', ' ')
        .split(' ')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _getModelDescription(String model) {
    switch (model) {
      case 'claude-3-5-sonnet':
        return 'Most capable model for complex tasks';
      case 'claude-3-7-sonnet':
        return 'Advanced reasoning and analysis';
      case 'claude-sonnet-4':
        return 'Latest generation model';
      case 'claude-3-5-sonnet-ashlynn':
        return 'Specialized creative model';
      default:
        return 'AI language model';
    }
  }
}