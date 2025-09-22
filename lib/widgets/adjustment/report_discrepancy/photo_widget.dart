import 'package:flutter/material.dart';
import '../adjustment_photo_widget.dart';

class PhotoCaptureWidget extends StatefulWidget {
  final List<String> photoFileNames; // Supabase storage filenames
  final Function(List<String>) onPhotosChanged;
  final int maxPhotos;
  final int maxFileSizeKB;
  final bool isRequired;
  final String workflowType;
  final String workflowId;

  const PhotoCaptureWidget({
    Key? key,
    required this.photoFileNames,
    required this.onPhotosChanged,
    required this.workflowType,
    required this.workflowId,
    this.maxPhotos = 5,
    this.maxFileSizeKB = 2048, // 2MB limit
    this.isRequired = true,
  }) : super(key: key);

  @override
  State<PhotoCaptureWidget> createState() => _PhotoCaptureWidgetState();
}

class _PhotoCaptureWidgetState extends State<PhotoCaptureWidget> {

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with requirements
        Row(
          children: [
            Text(
              'Photo Evidence',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            if (widget.isRequired) ...[
              const SizedBox(width: 4),
              Text(
                '*',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          widget.isRequired 
              ? 'At least 1 photo is required for discrepancy documentation'
              : 'Add photos to support your discrepancy report',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 12),

        // Use the new AdjustmentPhotoWidget
        AdjustmentPhotoWidget(
          workflowType: widget.workflowType,
          workflowId: widget.workflowId,
          photoFileNames: widget.photoFileNames,
          onPhotosChanged: widget.onPhotosChanged,
          maxPhotos: widget.maxPhotos,
          hintText: widget.isRequired 
              ? 'At least 1 photo is required for discrepancy documentation'
              : 'Add photos to support your discrepancy report',
        ),
      ],
    );
  }

}