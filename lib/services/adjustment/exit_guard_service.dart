import 'package:flutter/material.dart';

class ExitGuardService {
  static final ExitGuardService _instance = ExitGuardService._internal();
  factory ExitGuardService() => _instance;
  ExitGuardService._internal();

  /// Shows exit confirmation dialog for workflow steps
  /// Returns true if user confirms exit, false if they want to stay
  Future<bool> showExitConfirmation({
    required BuildContext context,
    required String workflowName,
    required int currentStep,
    required int totalSteps,
    String? stepName,
    List<String>? dataLossWarnings,
  }) async {
    final stepTitle = stepName ?? 'Step ${currentStep + 1} of $totalSteps';
    final warnings = dataLossWarnings ?? _getDefaultWarnings(workflowName, currentStep);
    
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange[700],
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Exit $workflowName?',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are currently in $stepTitle. If you exit now, the following data will be lost:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            ...warnings.map((warning) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.circle,
                    size: 6,
                    color: Colors.red[400],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      warning,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Are you sure you want to exit?',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Stay',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Exit',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ) ?? false;
  }

  /// Determines if a step should show exit confirmation
  bool shouldShowExitConfirmation({
    required String workflowName,
    required int currentStep,
    required int totalSteps,
  }) {
    switch (workflowName.toLowerCase()) {
      case 'receive stock':
        // Steps 0, 1 need confirmation (data entry)
        // Steps 2, 3 don't need confirmation (review, complete)
        return currentStep < 2;
      
      case 'report discrepancy':
        // Steps 0, 1, 2 need confirmation (data entry)
        // Step 3 doesn't need confirmation (review & submit)
        return currentStep < 3;
      
      case 'return stock':
        // Steps 0, 1, 2 need confirmation (data entry)
        // Step 3 doesn't need confirmation (review & complete)
        return currentStep < 3;
      
      default:
        return true; // Default to showing confirmation
    }
  }

  /// Gets default data loss warnings based on workflow and step
  List<String> _getDefaultWarnings(String workflowName, int currentStep) {
    switch (workflowName.toLowerCase()) {
      case 'receive stock':
        switch (currentStep) {
          case 0:
            return [
              'Selected purchase orders',
              'Applied filters and search criteria',
            ];
          case 1:
            return [
              'Quantity adjustments (received/damaged)',
              'Uploaded photos for damaged items',
              'Local discrepancy reports',
            ];
          default:
            return ['Current progress'];
        }
      
      case 'report discrepancy':
        switch (currentStep) {
          case 0:
            return [
              'Selected purchase order',
              'Applied filters and search criteria',
            ];
          case 1:
            return [
              'Selected line item',
            ];
          case 2:
            return [
              'Discrepancy details and description',
              'Uploaded photos',
              'Root cause and prevention measures',
            ];
          default:
            return ['Current progress'];
        }
      
      case 'return stock':
        switch (currentStep) {
          case 0:
            return [
              'Selected return type',
            ];
          case 1:
            return [
              'Selected items to return',
              'Applied filters and search criteria',
            ];
          case 2:
            return [
              'Return quantities and reasons',
              'Item conditions and notes',
            ];
          default:
            return ['Current progress'];
        }
      
      default:
        return ['Current progress'];
    }
  }

  /// Handles back button press with exit confirmation
  Future<bool> handleBackButton({
    required BuildContext context,
    required String workflowName,
    required int currentStep,
    required int totalSteps,
    String? stepName,
    List<String>? dataLossWarnings,
  }) async {
    // Check if we should show confirmation for this step
    if (!shouldShowExitConfirmation(
      workflowName: workflowName,
      currentStep: currentStep,
      totalSteps: totalSteps,
    )) {
      return true; // Allow exit without confirmation
    }

    // Show confirmation dialog
    return await showExitConfirmation(
      context: context,
      workflowName: workflowName,
      currentStep: currentStep,
      totalSteps: totalSteps,
      stepName: stepName,
      dataLossWarnings: dataLossWarnings,
    );
  }

  /// Handles navigation away from workflow (e.g., back to hub)
  Future<bool> handleWorkflowExit({
    required BuildContext context,
    required String workflowName,
    required int currentStep,
    required int totalSteps,
    String? stepName,
    List<String>? dataLossWarnings,
  }) async {
    return await handleBackButton(
      context: context,
      workflowName: workflowName,
      currentStep: currentStep,
      totalSteps: totalSteps,
      stepName: stepName,
      dataLossWarnings: dataLossWarnings,
    );
  }
}
