import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class LogisticsStep {
  static List<Widget> buildSlivers({
    required String returnType,
    required List<Map<String, dynamic>> selectedItems,
    required String returnMethod,
    required String carrierName,
    required String trackingNumber,
    required Map<String, dynamic> pickupDetails,
    required Map<String, dynamic> shipmentDetails,
    required List<File> returnDocuments,
    required Function(String) onReturnMethodChanged,
    required Function(String) onCarrierNameChanged,
    required Function(String) onTrackingNumberChanged,
    required Function(Map<String, dynamic>) onPickupDetailsChanged,
    required Function(Map<String, dynamic>) onShipmentDetailsChanged,
    required Function(List<File>) onDocumentsChanged,
    required BuildContext context,
  }) {
    List<Widget> slivers = [];
    
    // Header
    slivers.add(
      SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
          ),
          child: Row(
            children: [
              Icon(Icons.local_shipping, color: Colors.blue, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Logistics Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Configure return shipping and documentation',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: returnType == 'SUPPLIER_RETURN'
                    ? Colors.red[100]
                    : Colors.blue[100],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  returnType == 'SUPPLIER_RETURN'
                    ? 'Supplier Return'
                    : 'Internal Return',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: returnType == 'SUPPLIER_RETURN'
                      ? Colors.red[700]
                      : Colors.blue[700],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    
    // Return method selection
    slivers.add(
      SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Return Method',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _ReturnMethodSelector(
                selectedMethod: returnMethod,
                returnType: returnType,
                onMethodChanged: onReturnMethodChanged,
              ),
            ],
          ),
        ),
      ),
    );
    
    // Method-specific details
    if (returnMethod.isNotEmpty)
      slivers.add(
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildMethodDetails(
              method: returnMethod,
              carrierName: carrierName,
              trackingNumber: trackingNumber,
              pickupDetails: pickupDetails,
              shipmentDetails: shipmentDetails,
              onCarrierNameChanged: onCarrierNameChanged,
              onTrackingNumberChanged: onTrackingNumberChanged,
              onPickupDetailsChanged: onPickupDetailsChanged,
              onShipmentDetailsChanged: onShipmentDetailsChanged,
              context: context,
            ),
          ),
        ),
      );
    
    // Document upload
    slivers.add(
      SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: _DocumentUploadSection(
            documents: returnDocuments,
            onDocumentsChanged: onDocumentsChanged,
          ),
        ),
      ),
    );
    
    // Supplier contact info (for supplier returns)
    if (returnType == 'SUPPLIER_RETURN' && selectedItems.isNotEmpty)
      slivers.add(
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Supplier Contact Information',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Supplier: ${selectedItems.first['supplierName'] ?? 'Unknown'}',
                  style: TextStyle(fontSize: 13),
                ),
                Text(
                  'Email: ${selectedItems.first['supplierEmail'] ?? 'Not available'}',
                  style: TextStyle(fontSize: 13),
                ),
                Text(
                  'Phone: ${selectedItems.first['supplierPhone'] ?? 'Not available'}',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    
    return slivers;
  }
  
  static Widget _buildMethodDetails({
    required String method,
    required String carrierName,
    required String trackingNumber,
    required Map<String, dynamic> pickupDetails,
    required Map<String, dynamic> shipmentDetails,
    required Function(String) onCarrierNameChanged,
    required Function(String) onTrackingNumberChanged,
    required Function(Map<String, dynamic>) onPickupDetailsChanged,
    required Function(Map<String, dynamic>) onShipmentDetailsChanged,
    required BuildContext context,
  }) {
    switch (method) {
      case 'PICKUP':
        return _PickupDetails(
          details: pickupDetails,
          onDetailsChanged: onPickupDetailsChanged,
          context: context,
        );
      case 'SHIP':
        return _ShipmentDetails(
          carrierName: carrierName,
          trackingNumber: trackingNumber,
          details: shipmentDetails,
          onCarrierNameChanged: onCarrierNameChanged,
          onTrackingNumberChanged: onTrackingNumberChanged,
          onDetailsChanged: onShipmentDetailsChanged,
        );
      case 'DROP_OFF':
        return _DropOffDetails(
          details: shipmentDetails,
          onDetailsChanged: onShipmentDetailsChanged,
        );
      default:
        return Container();
    }
  }
}

class _ReturnMethodSelector extends StatelessWidget {
  final String selectedMethod;
  final String returnType;
  final Function(String) onMethodChanged;
  
  const _ReturnMethodSelector({
    required this.selectedMethod,
    required this.returnType,
    required this.onMethodChanged,
  });
  
  @override
  Widget build(BuildContext context) {
    final methods = returnType == 'SUPPLIER_RETURN'
      ? [
          {'id': 'PICKUP', 'label': 'Supplier Pickup', 'icon': Icons.local_shipping},
          {'id': 'SHIP', 'label': 'Ship to Supplier', 'icon': Icons.send},
          {'id': 'DROP_OFF', 'label': 'Drop Off', 'icon': Icons.location_on},
        ]
      : [
          {'id': 'DROP_OFF', 'label': 'Internal Processing', 'icon': Icons.warehouse},
        ];
    
    return Row(
      children: methods.map((method) {
        final isSelected = selectedMethod == method['id'];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: methods.last != method ? 8 : 0),
            child: InkWell(
              onTap: () => onMethodChanged(method['id'] as String),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue[50] : Colors.grey[50],
                  border: Border.all(
                    color: isSelected ? Colors.blue : Colors.grey[300]!,
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      method['icon'] as IconData,
                      color: isSelected ? Colors.blue : Colors.grey[600],
                      size: 24,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      method['label'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? Colors.blue : Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PickupDetails extends StatefulWidget {
  final Map<String, dynamic> details;
  final Function(Map<String, dynamic>) onDetailsChanged;
  final BuildContext context;
  
  const _PickupDetails({
    required this.details,
    required this.onDetailsChanged,
    required this.context,
  });
  
  @override
  State<_PickupDetails> createState() => _PickupDetailsState();
}

class _PickupDetailsState extends State<_PickupDetails> {
  DateTime? _selectedDate;
  String? _selectedTimeSlot;
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  
  final List<String> _timeSlots = [
    '9:00 AM - 12:00 PM',
    '12:00 PM - 3:00 PM',
    '3:00 PM - 6:00 PM',
  ];
  
  @override
  void initState() {
    super.initState();
    _selectedDate = widget.details['date'];
    _selectedTimeSlot = widget.details['timeSlot'];
    _addressController.text = widget.details['address'] ?? '';
    _contactController.text = widget.details['contactPerson'] ?? '';
    _notesController.text = widget.details['notes'] ?? '';
  }
  
  void _updateDetails() {
    widget.onDetailsChanged({
      'date': _selectedDate,
      'timeSlot': _selectedTimeSlot,
      'address': _addressController.text,
      'contactPerson': _contactController.text,
      'notes': _notesController.text,
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pickup Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Date picker
          InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: widget.context,
                initialDate: _selectedDate ?? DateTime.now().add(Duration(days: 1)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(Duration(days: 30)),
              );
              if (date != null) {
                setState(() => _selectedDate = date);
                _updateDetails();
              }
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: Colors.grey[600], size: 20),
                  const SizedBox(width: 12),
                  Text(
                    _selectedDate != null
                      ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                      : 'Select pickup date *',
                    style: TextStyle(
                      fontSize: 14,
                      color: _selectedDate != null ? Colors.black : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Time slot
          DropdownButtonFormField<String>(
            value: _selectedTimeSlot,
            hint: Text('Select time slot *'),
            items: _timeSlots.map((slot) {
              return DropdownMenuItem(
                value: slot,
                child: Text(slot),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedTimeSlot = value);
              _updateDetails();
            },
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: Icon(Icons.access_time, size: 20),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Pickup address
          TextField(
            controller: _addressController,
            maxLines: 2,
            onChanged: (_) => _updateDetails(),
            decoration: InputDecoration(
              labelText: 'Pickup Address *',
              hintText: 'Enter pickup address',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: Icon(Icons.location_on, size: 20),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Contact person
          TextField(
            controller: _contactController,
            onChanged: (_) => _updateDetails(),
            decoration: InputDecoration(
              labelText: 'Contact Person',
              hintText: 'Enter contact name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: Icon(Icons.person, size: 20),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Special instructions
          TextField(
            controller: _notesController,
            maxLines: 2,
            onChanged: (_) => _updateDetails(),
            decoration: InputDecoration(
              labelText: 'Special Instructions',
              hintText: 'Any special pickup instructions...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShipmentDetails extends StatefulWidget {
  final String carrierName;
  final String trackingNumber;
  final Map<String, dynamic> details;
  final Function(String) onCarrierNameChanged;
  final Function(String) onTrackingNumberChanged;
  final Function(Map<String, dynamic>) onDetailsChanged;
  
  const _ShipmentDetails({
    required this.carrierName,
    required this.trackingNumber,
    required this.details,
    required this.onCarrierNameChanged,
    required this.onTrackingNumberChanged,
    required this.onDetailsChanged,
  });
  
  @override
  State<_ShipmentDetails> createState() => _ShipmentDetailsState();
}

class _ShipmentDetailsState extends State<_ShipmentDetails> {
  late TextEditingController _carrierController;
  late TextEditingController _trackingController;
  late TextEditingController _addressController;
  
  @override
  void initState() {
    super.initState();
    _carrierController = TextEditingController(text: widget.carrierName);
    _trackingController = TextEditingController(text: widget.trackingNumber);
    _addressController = TextEditingController(text: widget.details['address'] ?? '');
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Shipment Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Carrier selection
          DropdownButtonFormField<String>(
            value: _carrierController.text.isEmpty ? null : _carrierController.text,
            hint: Text('Select carrier *'),
            items: ['FedEx', 'UPS', 'DHL', 'USPS', 'Other'].map((carrier) {
              return DropdownMenuItem(
                value: carrier,
                child: Text(carrier),
              );
            }).toList(),
            onChanged: (value) {
              _carrierController.text = value ?? '';
              widget.onCarrierNameChanged(value ?? '');
            },
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Tracking number
          TextField(
            controller: _trackingController,
            onChanged: widget.onTrackingNumberChanged,
            decoration: InputDecoration(
              labelText: 'Tracking Number',
              hintText: 'Enter tracking number',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: Icon(Icons.numbers, size: 20),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Shipping address
          TextField(
            controller: _addressController,
            maxLines: 3,
            onChanged: (value) {
              widget.onDetailsChanged({
                ...widget.details,
                'address': value,
              });
            },
            decoration: InputDecoration(
              labelText: 'Shipping Address *',
              hintText: 'Enter supplier return address',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DropOffDetails extends StatefulWidget {
  final Map<String, dynamic> details;
  final Function(Map<String, dynamic>) onDetailsChanged;
  
  const _DropOffDetails({
    required this.details,
    required this.onDetailsChanged,
  });
  
  @override
  State<_DropOffDetails> createState() => _DropOffDetailsState();
}

class _DropOffDetailsState extends State<_DropOffDetails> {
  String? _selectedLocation;
  final TextEditingController _notesController = TextEditingController();
  
  final List<String> _locations = [
    'Main Warehouse - Zone A',
    'Returns Processing Center',
    'Quality Control Department',
    'Supplier Drop Point',
  ];
  
  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.details['location'];
    _notesController.text = widget.details['notes'] ?? '';
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Drop-off Location',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          DropdownButtonFormField<String>(
            value: _selectedLocation,
            hint: Text('Select drop-off location *'),
            items: _locations.map((location) {
              return DropdownMenuItem(
                value: location,
                child: Text(location),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedLocation = value);
              widget.onDetailsChanged({
                ...widget.details,
                'location': value,
              });
            },
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: Icon(Icons.location_on, size: 20),
            ),
          ),
          
          const SizedBox(height: 12),
          
          TextField(
            controller: _notesController,
            maxLines: 2,
            onChanged: (value) {
              widget.onDetailsChanged({
                ...widget.details,
                'notes': value,
              });
            },
            decoration: InputDecoration(
              labelText: 'Additional Notes',
              hintText: 'Any special instructions...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentUploadSection extends StatefulWidget {
  final List<File> documents;
  final Function(List<File>) onDocumentsChanged;
  
  const _DocumentUploadSection({
    required this.documents,
    required this.onDocumentsChanged,
  });
  
  @override
  State<_DocumentUploadSection> createState() => _DocumentUploadSectionState();
}

class _DocumentUploadSectionState extends State<_DocumentUploadSection> {
  final ImagePicker _picker = ImagePicker();
  
  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) {
      final newDocs = List<File>.from(widget.documents)..add(File(image.path));
      widget.onDocumentsChanged(newDocs);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Return Documents',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${widget.documents.length} uploaded)',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Upload buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: Icon(Icons.camera_alt),
                  label: Text('Camera'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: Icon(Icons.photo_library),
                  label: Text('Gallery'),
                ),
              ),
            ],
          ),
          
          // Document preview
          if (widget.documents.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.documents.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            widget.documents[index],
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: InkWell(
                            onTap: () {
                              final newDocs = List<File>.from(widget.documents)
                                ..removeAt(index);
                              widget.onDocumentsChanged(newDocs);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}