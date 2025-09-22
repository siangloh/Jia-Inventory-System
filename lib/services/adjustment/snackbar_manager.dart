import 'package:flutter/material.dart';

class SnackbarManager {
  static final SnackbarManager _instance = SnackbarManager._internal();
  factory SnackbarManager() => _instance;
  SnackbarManager._internal();

  bool _isSnackbarVisible = false;
  String? _currentMessage;
  OverlayEntry? _currentOverlay;

  /// Show a snackbar with validation message, preventing duplicates
  void showValidationMessage(
    BuildContext context, {
    required String message,
    Color backgroundColor = Colors.red,
    Duration duration = const Duration(seconds: 3),
  }) {
    // If the same message is already showing, don't show another one
    if (_isSnackbarVisible && _currentMessage == message) {
      return;
    }

    // Hide any existing snackbar first
    if (_isSnackbarVisible) {
      _hideCurrentSnackbar();
    }

    _currentMessage = message;
    _isSnackbarVisible = true;

    try {
      // Use ScaffoldMessenger for better integration
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                _getIconForColor(backgroundColor),
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: backgroundColor,
          duration: duration,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.all(16),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              _resetState();
            },
          ),
        ),
      );

      // Auto-reset state after duration
      Future.delayed(duration + const Duration(milliseconds: 500), () {
        _resetState();
      });

    } catch (e) {
      // Fallback to overlay if ScaffoldMessenger fails
      _showOverlaySnackbar(context, message, backgroundColor, duration);
    }
  }

  /// Fallback overlay implementation
  void _showOverlaySnackbar(
    BuildContext context,
    String message,
    Color backgroundColor,
    Duration duration,
  ) {
    try {
      final overlay = Overlay.of(context);
      _currentOverlay = OverlayEntry(
        builder: (context) => Positioned(
          top: MediaQuery.of(context).padding.top + 20,
          left: 16,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    _getIconForColor(backgroundColor),
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      _hideCurrentSnackbar();
                    },
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      overlay.insert(_currentOverlay!);

      // Auto-remove after duration
      Future.delayed(duration, () {
        _hideCurrentSnackbar();
      });
    } catch (e) {
      debugPrint('Failed to show overlay snackbar: $e');
      _resetState();
    }
  }

  /// Get appropriate icon for the background color
  IconData _getIconForColor(Color backgroundColor) {
    if (backgroundColor == Colors.green) {
      return Icons.check_circle;
    } else if (backgroundColor == Colors.orange) {
      return Icons.warning;
    } else if (backgroundColor == Colors.red) {
      return Icons.error;
    } else if (backgroundColor == Colors.blue) {
      return Icons.info;
    } else {
      return Icons.notifications;
    }
  }

  /// Hide current overlay snackbar
  void _hideCurrentSnackbar() {
    try {
      if (_currentOverlay != null && _currentOverlay!.mounted) {
        _currentOverlay!.remove();
      }
    } catch (e) {
      debugPrint('Error removing overlay: $e');
    } finally {
      _resetState();
    }
  }

  /// Reset internal state
  void _resetState() {
    _isSnackbarVisible = false;
    _currentMessage = null;
    _currentOverlay = null;
  }

  /// Show success message
  void showSuccessMessage(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    showValidationMessage(
      context,
      message: message,
      backgroundColor: Colors.green,
      duration: duration,
    );
  }

  /// Show warning message
  void showWarningMessage(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    showValidationMessage(
      context,
      message: message,
      backgroundColor: Colors.orange,
      duration: duration,
    );
  }

  /// Show error message
  void showErrorMessage(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 4),
  }) {
    showValidationMessage(
      context,
      message: message,
      backgroundColor: Colors.red,
      duration: duration,
    );
  }

  /// Show info message
  void showInfoMessage(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    showValidationMessage(
      context,
      message: message,
      backgroundColor: Colors.blue,
      duration: duration,
    );
  }

  /// Hide current snackbar if visible
  void hideCurrentSnackbar(BuildContext context) {
    if (_isSnackbarVisible) {
      try {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      } catch (e) {
        // If ScaffoldMessenger fails, try overlay method
        _hideCurrentSnackbar();
      }
      _resetState();
    }
  }

  /// Check if snackbar is currently visible
  bool get isVisible => _isSnackbarVisible;

  /// Get current message
  String? get currentMessage => _currentMessage;
}