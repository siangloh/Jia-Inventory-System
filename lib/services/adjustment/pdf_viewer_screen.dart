import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../../../../services/adjustment/snackbar_manager.dart';

class PDFViewerScreen extends StatefulWidget {
  final Uint8List pdfBytes;
  final String title;

  const PDFViewerScreen({
    Key? key,
    required this.pdfBytes,
    required this.title,
  }) : super(key: key);

  @override
  State<PDFViewerScreen> createState() => _PDFViewerScreenState();
}

class _PDFViewerScreenState extends State<PDFViewerScreen> {
  late PdfControllerPinch _pdfController;
  bool _isReady = false;
  bool _isLoading = true;
  bool _isDownloading = false;
  String _errorMessage = '';
  int _currentPage = 1;
  int _totalPages = 0;
  
  bool _showZoomHint = true;

  @override
  void initState() {
    super.initState();
    _initializePDF();
  }

  Future<void> _initializePDF() async {
    try {
      // Initialize PDF controller with the bytes
      final documentFuture = PdfDocument.openData(widget.pdfBytes);
      
      _pdfController = PdfControllerPinch(
        document: documentFuture,
        initialPage: 1,
        viewportFraction: 1.0,
      );

      // Wait for document to load to get page count
      final document = await documentFuture;

      if (mounted) {
        setState(() {
          _isReady = true;
          _isLoading = false;
          _totalPages = document.pagesCount;
          _currentPage = 1;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load PDF: $e';
          _isLoading = false;
        });
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 1,
        actions: [
          // Page indicator
          if (_isReady) 
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '$_currentPage / $_totalPages',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          // Download button
          IconButton(
            icon: _isDownloading 
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.download),
            onPressed: _isDownloading ? null : _downloadPDF,
            tooltip: 'Download PDF',
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _isReady ? _buildBottomNavigation() : null,
      floatingActionButton: _isReady && _showZoomHint ? _buildZoomHint() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Container(
        color: Colors.grey[100],
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Loading PDF...',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Container(
        color: Colors.grey[100],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
              const SizedBox(height: 16),
              Text(
                'Error Loading PDF',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[600],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = '';
                  });
                  _initializePDF();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isReady) {
      return Container(
        color: Colors.grey[100],
        child: const Center(
          child: Text('No PDF to display'),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        if (_showZoomHint) {
          setState(() {
            _showZoomHint = false;
          });
        }
      },
      child: Container(
        color: Colors.grey[200],
        child: PdfViewPinch(
          controller: _pdfController,
          padding: 8,
          onDocumentLoaded: (document) {
            debugPrint('PDF loaded with ${document.pagesCount} pages');
            if (mounted) {
              setState(() {
                _totalPages = document.pagesCount;
              });
            }
          },
          onPageChanged: (page) {
            if (mounted) {
              setState(() {
                _currentPage = page;
              });
            }
          },
          backgroundDecoration: BoxDecoration(
            color: Colors.grey[200],
          ),
        ),
      ),
    );
  }

  Widget _buildZoomHint() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue[600],
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            'Pinch to zoom • Double tap to fit',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          // First page
          IconButton(
            icon: const Icon(Icons.first_page),
            onPressed: _currentPage > 1 ? () => _goToPage(1) : null,
            tooltip: 'First Page',
          ),
          // Previous page
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
            tooltip: 'Previous Page',
          ),
          
          // Page indicator
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Text(
                  'Page $_currentPage of $_totalPages',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          
          // Next page
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage < _totalPages ? () => _goToPage(_currentPage + 1) : null,
            tooltip: 'Next Page',
          ),
          // Last page
          IconButton(
            icon: const Icon(Icons.last_page),
            onPressed: _currentPage < _totalPages ? () => _goToPage(_totalPages) : null,
            tooltip: 'Last Page',
          ),
        ],
      ),
    );
  }

  // Navigate to specific page
  void _goToPage(int page) {
    if (page >= 1 && page <= _totalPages && page != _currentPage) {
      _currentPage = page;
      _pdfController.animateToPage(
        pageNumber: page,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }


  // Download PDF to device storage
  Future<void> _downloadPDF() async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
    });
    
    try {
      // Get the Downloads directory
      Directory? directory;
      
      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();
        if (directory != null) {
          // Navigate to public Downloads folder
          final downloadsPath = '/storage/emulated/0/Download';
          directory = Directory(downloadsPath);
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }
      
      if (directory == null) {
        throw Exception('Cannot access storage directory');
      }
      
      // Ensure Downloads directory exists
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      
      // Create date folder (e.g., 20_9 for September 20th)
      final now = DateTime.now();
      final dateFolder = '${now.day}_${now.month}';
      final dateDir = Directory('${directory.path}/$dateFolder');
      if (!await dateDir.exists()) {
        await dateDir.create(recursive: true);
      }
      
      // Generate filename
      final fileName = 'receiving_receipt_${DateFormat('yyyyMMdd_HHmmss').format(now)}.pdf';
      final filePath = '${dateDir.path}/$fileName';
      
      // Write PDF bytes to file
      final file = File(filePath);
      await file.writeAsBytes(widget.pdfBytes);
      
      if (mounted) {
        SnackbarManager().showSuccessMessage(
          context,
          message: 'PDF saved to Download/$dateFolder/$fileName',
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarManager().showErrorMessage(
          context,
          message: 'Failed to save PDF: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }
}