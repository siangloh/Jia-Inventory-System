// models/po_supplier_info_model.dart

/// Helper class to hold Purchase Order and Supplier information
/// Used when aggregating PO data from multiple sources (ProductItems, metadata, etc.)
class POAndSupplierInfo {
  final Set<String> poNumbers;
  final Set<String> supplierNames;

  POAndSupplierInfo({
    required this.poNumbers,
    required this.supplierNames,
  });

  /// Factory constructor for empty info
  factory POAndSupplierInfo.empty() {
    return POAndSupplierInfo(
      poNumbers: <String>{},
      supplierNames: <String>{},
    );
  }

  /// Factory constructor from single PO
  factory POAndSupplierInfo.fromSingle({
    String? poNumber,
    String? supplierName,
  }) {
    return POAndSupplierInfo(
      poNumbers: poNumber != null ? {poNumber} : <String>{},
      supplierNames: supplierName != null ? {supplierName} : <String>{},
    );
  }

  /// Check if this info is empty
  bool get isEmpty => poNumbers.isEmpty && supplierNames.isEmpty;

  /// Check if this info has data
  bool get isNotEmpty => !isEmpty;

  /// Get count of unique POs
  int get poCount => poNumbers.length;

  /// Get count of unique suppliers
  int get supplierCount => supplierNames.length;

  /// Combine with another POAndSupplierInfo instance
  POAndSupplierInfo combine(POAndSupplierInfo other) {
    return POAndSupplierInfo(
      poNumbers: {...poNumbers, ...other.poNumbers},
      supplierNames: {...supplierNames, ...other.supplierNames},
    );
  }

  /// Add a single PO and supplier
  POAndSupplierInfo addPO({
    String? poNumber,
    String? supplierName,
  }) {
    final newPoNumbers = Set<String>.from(poNumbers);
    final newSupplierNames = Set<String>.from(supplierNames);

    if (poNumber != null && poNumber.isNotEmpty) {
      newPoNumbers.add(poNumber);
    }
    if (supplierName != null && supplierName.isNotEmpty) {
      newSupplierNames.add(supplierName);
    }

    return POAndSupplierInfo(
      poNumbers: newPoNumbers,
      supplierNames: newSupplierNames,
    );
  }

  /// Get formatted PO numbers string
  String get poNumbersString {
    if (poNumbers.isEmpty) return 'No PO';
    if (poNumbers.length == 1) return poNumbers.first;
    return '${poNumbers.length} POs';
  }

  /// Get formatted supplier names string
  String get supplierNamesString {
    if (supplierNames.isEmpty) return 'No supplier';
    if (supplierNames.length == 1) return supplierNames.first;
    return '${supplierNames.length} suppliers';
  }

  /// Copy with method
  POAndSupplierInfo copyWith({
    Set<String>? poNumbers,
    Set<String>? supplierNames,
  }) {
    return POAndSupplierInfo(
      poNumbers: poNumbers ?? this.poNumbers,
      supplierNames: supplierNames ?? this.supplierNames,
    );
  }

  @override
  String toString() {
    return 'POAndSupplierInfo{POs: ${poNumbers.length}, Suppliers: ${supplierNames.length}}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is POAndSupplierInfo &&
              runtimeType == other.runtimeType &&
              poNumbers == other.poNumbers &&
              supplierNames == other.supplierNames;

  @override
  int get hashCode => poNumbers.hashCode ^ supplierNames.hashCode;
}