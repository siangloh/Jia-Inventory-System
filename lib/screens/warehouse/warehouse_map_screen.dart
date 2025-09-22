import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../../models/warehouse_location.dart';

class WarehouseMapScreen extends StatefulWidget {
  final List<WarehouseLocation> productLocations;
  final String productName;

  const WarehouseMapScreen({
    Key? key,
    required this.productLocations,
    required this.productName,
  }) : super(key: key);

  @override
  State<WarehouseMapScreen> createState() => _WarehouseMapScreenState();
}

class _WarehouseMapScreenState extends State<WarehouseMapScreen> {
  String? selectedLocation;
  String? navigationTarget;
  bool isNavigating = false;

  // Search controller
  final TextEditingController searchController = TextEditingController();

  // Zoom functionality
  final TransformationController _transformationController = TransformationController();
  double _currentZoom = 1.0;
  static const double _minZoom = 0.5;
  static const double _maxZoom = 3.0;
  static const double _zoomStep = 0.2;

  // Zone definitions with colors and properties
  final Map<String, ZoneInfo> zones = {
    'Z1': ZoneInfo(
      name: 'Fast-Moving Zone',
      color: Colors.green.shade300,
      description: 'Brake pads, spark plugs, fuses, filters',
      racks: 5,
      rows: 2,
      levels: 5,
    ),
    'Z2': ZoneInfo(
      name: 'Medium-Moving Zone',
      color: Colors.blue.shade300,
      description: 'Alternators, brake discs, small ECUs',
      racks: 10,
      rows: 2,
      levels: 4,
    ),
    'Z3': ZoneInfo(
      name: 'Slow-Moving Zone',
      color: Colors.yellow.shade300,
      description: 'Engines, body panels, rare parts',
      racks: 8,
      rows: 2,
      levels: 3,
    ),
    'Z4': ZoneInfo(
      name: 'Bulk Storage Area',
      color: Colors.orange.shade300,
      description: 'Oils, coolants, nuts & bolts',
      racks: 3,
      rows: 4,
      levels: 2,
    ),
    'Z5': ZoneInfo(
      name: 'Climate-Controlled Area',
      color: Colors.cyan.shade300,
      description: 'ECUs, sensors, rubber gaskets',
      racks: 4,
      rows: 2,
      levels: 4,
    ),
    'Z6': ZoneInfo(
      name: 'Hazardous Material Area',
      color: Colors.red.shade300,
      description: 'Batteries, airbags, brake fluid, paints',
      racks: 2,
      rows: 2,
      levels: 3,
    ),
  };

  Set<String> get productLocationIds {
    return widget.productLocations.map((loc) => loc.locationId).toSet();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Product locations quick navigation
        _buildLocationQuickNav(),

        // Zoom controls bar
        _buildZoomControls(),

        // Map
        Expanded(
          child: InteractiveViewer(
            transformationController: _transformationController,
            minScale: _minZoom,
            maxScale: _maxZoom,
            constrained: false,
            onInteractionUpdate: (details) {
              setState(() {
                _currentZoom = _transformationController.value.getMaxScaleOnAxis();
              });
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              child: _buildWarehouseGrid(),
            ),
          ),
        ),

        // Selected location info
        if (selectedLocation != null) _buildLocationInfo(),
      ],
    );
  }

  Widget _buildLocationQuickNav() {
    // Group locations by zone for quick navigation
    final locationsByZone = <String, List<WarehouseLocation>>{};
    for (final location in widget.productLocations) {
      locationsByZone.putIfAbsent(location.zoneId, () => []).add(location);
    }

    return Container(
      height: 60,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Product Locations (${widget.productLocations.length})',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: locationsByZone.keys.length,
              itemBuilder: (context, index) {
                final zoneId = locationsByZone.keys.elementAt(index);
                final locations = locationsByZone[zoneId]!;
                final totalQty = locations.fold<int>(0, (sum, loc) => sum + (loc.quantityStored ?? 0));

                return Container(
                  margin: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () => _handleZoneSelection(zoneId, locations),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 50,
                        maxWidth: 90,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: _getZoneColor(zoneId).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _getZoneColor(zoneId),
                          width: navigationTarget?.startsWith(zoneId) == true ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Zone ID
                          Text(
                            zoneId,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              color: _getZoneColor(zoneId),
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(width: 2),
                          // Location count badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: _getZoneColor(zoneId),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${locations.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                height: 1.0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          // Quantity
                          Flexible(
                            child: Text(
                              '$totalQty',
                              style: TextStyle(
                                fontSize: 8,
                                color: _getZoneColor(zoneId),
                                height: 1.0,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _handleZoneSelection(String zoneId, List<WarehouseLocation> locations) {
    if (locations.length == 1) {
      // Only one location, navigate directly
      _navigateToLocation(locations.first.locationId);
    } else {
      // Multiple locations, show selection dialog
      _showLocationSelectionDialog(zoneId, locations);
    }
  }

  // Dialog to select specific location within a zone
  void _showLocationSelectionDialog(String zoneId, List<WarehouseLocation> locations) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select Location in $zoneId'),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: locations.length,
              itemBuilder: (context, index) {
                final location = locations[index];
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getZoneColor(zoneId).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _getZoneColor(zoneId)),
                    ),
                    child: Center(
                      child: Text(
                        '${location.quantityStored ?? 0}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _getZoneColor(zoneId),
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    location.locationId,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Quantity: ${location.quantityStored ?? 0}'),
                      if (location.metadata?['poNumber'] != null)
                        Text('PO: ${location.metadata!['poNumber']}',
                            style: const TextStyle(fontSize: 12)),
                      if (location.metadata?['supplierName'] != null)
                        Text('Supplier: ${location.metadata!['supplierName']}',
                            style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  trailing: Icon(
                    Icons.navigation,
                    color: _getZoneColor(zoneId),
                  ),
                  onTap: () {
                    Navigator.of(context).pop(); // Close dialog
                    _navigateToSpecificLocation(location.locationId);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _navigateToSpecificLocation(String locationId) {
    setState(() {
      navigationTarget = locationId;
      isNavigating = true;
      selectedLocation = locationId; // This will show the location info
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigation to $locationId started!'),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildZoomControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: _currentZoom < _maxZoom ? _zoomIn : null,
            iconSize: 20,
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: _currentZoom > _minZoom ? _zoomOut : null,
            iconSize: 20,
          ),
          IconButton(
            icon: const Icon(Icons.center_focus_strong),
            onPressed: _resetZoom,
            iconSize: 20,
            tooltip: 'Reset Zoom',
          ),
          const SizedBox(width: 12),
          Text(
            'Zoom: ${(_currentZoom * 100).toInt()}%',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          if (isNavigating) ...[
            // Fixed: Use Flexible to prevent overflow
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.navigation, color: Colors.blue[600], size: 14),
                    const SizedBox(width: 4),
                    // Fixed: Added Flexible and TextOverflow.ellipsis
                    Flexible(
                      child: Text(
                        'Navigating to: $navigationTarget',
                        style: TextStyle(
                          color: Colors.blue[800],
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis, // Fixed overflow
                        maxLines: 1, // Ensure single line
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _stopNavigation,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: const Size(60, 28),
              ),
              child: const Text('Arrived', style: TextStyle(fontSize: 11)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWarehouseGrid() {
    return Container(
      width: 1000,
      height: 800,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade800, width: 2),
        color: Colors.grey.shade50,
      ),
      child: Stack(
        children: [
          // Zone Areas - increased sizes to accommodate detailed racks
          _buildZoneArea('Z1', 20, 50, 230, 300),   // Fast-Moving (top-left)
          _buildZoneArea('Z2', 270, 50, 250, 300),  // Medium-Moving (top-center)
          _buildZoneArea('Z3', 540, 50, 220, 300),  // Slow-Moving (top-right)
          _buildZoneArea('Z4', 20, 390, 230, 220),  // Bulk Storage (mid-left)
          _buildZoneArea('Z5', 270, 390, 250, 220), // Climate-Controlled (mid-center)
          _buildZoneArea('Z6', 540, 390, 220, 220), // Hazardous (mid-right)

          // Aisles and pathways
          _buildAisles(),

          // Entry/Exit points
          _buildEntryExitPoints(),

          // REMOVED: Blue product location highlights
          // ..._buildProductLocationHighlights(),

          // Navigation path (if active)
          if (isNavigating && navigationTarget != null) _buildNavigationPath(),
        ],
      ),
    );
  }

  Widget _buildZoneArea(String zoneId, double left, double top, double width, double height) {
    final zone = zones[zoneId]!;
    final isSelected = selectedLocation?.startsWith(zoneId) ?? false;
    final isNavigationTarget = navigationTarget?.startsWith(zoneId) ?? false;
    final hasProductLocations = widget.productLocations.any((loc) => loc.zoneId == zoneId);
    final totalQuantity = widget.productLocations
        .where((loc) => loc.zoneId == zoneId)
        .fold<int>(0, (sum, loc) => sum + (loc.quantityStored ?? 0));

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onTap: () => _selectZone(zoneId),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: hasProductLocations
                ? zone.color.withOpacity(0.9)
                : zone.color.withOpacity(0.3),
            border: Border.all(
              color: isSelected ? Colors.black :
              isNavigationTarget ? Colors.red :
              hasProductLocations ? Colors.red.withOpacity(0.6) :
              Colors.grey.shade600,
              width: (isSelected || isNavigationTarget || hasProductLocations) ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            children: [
              // Zone label
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: hasProductLocations ? Colors.red[100] : Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: hasProductLocations
                        ? Border.all(color: Colors.red, width: 1)
                        : null,
                  ),
                  child: Text(
                    zoneId,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: hasProductLocations ? Colors.red[800] : Colors.black,
                    ),
                  ),
                ),
              ),

              // MOVED: Product count badge to bottom right with total quantity
              if (hasProductLocations)
                Positioned(
                  bottom: 4,  // Changed from top: 4 to bottom: 4
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${widget.productLocations.where((loc) => loc.zoneId == zoneId).length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Qty: $totalQuantity',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Rack grid
              Positioned(
                top: 30,
                left: 8,
                right: 8,
                bottom: hasProductLocations ? 50 : 8, // Add bottom padding if has products
                child: _buildRackGrid(zoneId, zone),
              ),

              // Special indicators
              if (zoneId == 'Z6') _buildHazardIndicator(),
              if (zoneId == 'Z5') _buildClimateIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRackGrid(String zoneId, ZoneInfo zone) {
    const double rackSize = 60.0;
    const double rackSpacing = 8.0;

    return Wrap(
      spacing: rackSpacing,
      runSpacing: rackSpacing,
      children: List.generate(zone.racks, (index) {
        final rackId = 'R${index + 1}';
        final locationId = '$zoneId-$rackId';
        final isSelected = selectedLocation?.startsWith(locationId) ?? false;
        final hasProducts = widget.productLocations.any((loc) => loc.locationId.startsWith(locationId));

        return GestureDetector(
          onTap: () => _selectLocation(locationId),
          child: Container(
            width: rackSize,
            height: rackSize,
            decoration: BoxDecoration(
              color: isSelected ? Colors.yellow.shade100 :
              hasProducts ? Colors.red.shade50 : Colors.white,
              border: Border.all(
                color: isSelected ? Colors.black :
                hasProducts ? Colors.red : Colors.grey.shade400,
                width: (isSelected || hasProducts) ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(6),
              boxShadow: isSelected ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 3,
                  offset: const Offset(1, 1),
                )
              ] : null,
            ),
            child: Column(
              children: [
                // Rack header
                Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: hasProducts ? Colors.red[100] : Colors.grey.shade200,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(5),
                      topRight: Radius.circular(5),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      rackId,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: hasProducts ? Colors.red[800] : Colors.black,
                      ),
                    ),
                  ),
                ),
                // Rows within rack
                Expanded(
                  child: _buildRowsInRack(zoneId, rackId, zone),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildRowsInRack(String zoneId, String rackId, ZoneInfo zone) {
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Column(
        children: [
          Expanded(
            child: _buildRow(zoneId, rackId, 'A', zone.levels),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: _buildRow(zoneId, rackId, 'B', zone.levels),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String zoneId, String rackId, String rowId, int levels) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade300, width: 0.5),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(2),
                bottomLeft: Radius.circular(2),
              ),
            ),
            child: Center(
              child: Text(
                rowId,
                style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: List.generate(math.min(levels, 4), (levelIndex) {
                final levelId = '${levelIndex + 1}';
                final fullLocationId = '$zoneId-$rackId-$rowId-$levelId';
                final isLevelSelected = selectedLocation == fullLocationId;
                final hasProduct = productLocationIds.contains(fullLocationId);
                final isNavigationTarget = navigationTarget == fullLocationId;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => _selectLocation(fullLocationId),
                    child: Container(
                      margin: const EdgeInsets.all(0.5),
                      decoration: BoxDecoration(
                        color: isNavigationTarget ? Colors.orange : // Add orange for navigation target
                        isLevelSelected ? Colors.yellow :
                        hasProduct ? Colors.red : Colors.white,
                        border: Border.all(
                          color: isNavigationTarget ? Colors.deepOrange : // Add border for nav target
                          isLevelSelected ? Colors.orange :
                          hasProduct ? Colors.red : Colors.grey.shade400,
                          width: isNavigationTarget ? 2 : 0.5, // Thicker border for nav target
                        ),
                        borderRadius: BorderRadius.circular(1),
                      ),
                      child: Center(
                        child: Text(
                          levelId,
                          style: TextStyle(
                            fontSize: 6,
                            fontWeight: (isLevelSelected || hasProduct) ? FontWeight.bold : FontWeight.normal,
                            color: (isLevelSelected || hasProduct) ? Colors.white : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  void _zoomIn() {
    final newZoom = (_currentZoom + _zoomStep).clamp(_minZoom, _maxZoom);
    _setZoom(newZoom);
  }

  void _zoomOut() {
    final newZoom = (_currentZoom - _zoomStep).clamp(_minZoom, _maxZoom);
    _setZoom(newZoom);
  }

  void _resetZoom() {
    _setZoom(1.0);
  }

  void _setZoom(double zoom) {
    setState(() {
      _currentZoom = zoom;
    });

    final Matrix4 matrix = Matrix4.identity()..scale(zoom);
    _transformationController.value = matrix;
  }

  Color _getZoneColor(String zone) {
    switch (zone) {
      case 'Z1': return Colors.red;
      case 'Z2': return Colors.orange;
      case 'Z3': return Colors.yellow[700]!;
      case 'Z4': return Colors.green;
      case 'Z5': return Colors.blue;
      case 'Z6': return Colors.purple;
      default: return Colors.grey;
    }
  }

  void _selectZone(String zoneId) {
    setState(() {
      selectedLocation = zoneId;
    });
  }

  void _selectLocation(String locationId) {
    setState(() {
      selectedLocation = locationId;
    });

    // Auto-navigate if this is a product location
    if (productLocationIds.contains(locationId)) {
      _navigateToLocation(locationId);
    }
  }

  void _navigateToLocation(String location) {
    setState(() {
      navigationTarget = location;
      isNavigating = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigation to $location started!'),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildLocationInfo() {
    final locationParts = selectedLocation!.split('-');
    final zoneId = locationParts[0];
    final zone = zones[zoneId];

    // Check if this is a product location
    final productLocation = widget.productLocations.firstWhere(
          (loc) => loc.locationId == selectedLocation,
      orElse: () => widget.productLocations.firstWhere(
            (loc) => loc.locationId.startsWith(selectedLocation!),
        orElse: () => WarehouseLocation(
          locationId: '',
          zoneId: '',
          rackId: '',
          rowId: '',
          level: 0,
          isOccupied: false,
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: productLocation.locationId.isNotEmpty ? Colors.red[50] : Colors.blue[50],
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                productLocation.locationId.isNotEmpty ? Icons.inventory : Icons.location_on,
                color: productLocation.locationId.isNotEmpty ? Colors.red[600] : Colors.blue[600],
                size: 20,
              ),
              const SizedBox(width: 8),
              // Fixed: Use Expanded to prevent overflow
              Expanded(
                child: Text(
                  productLocation.locationId.isNotEmpty
                      ? 'Product Location: $selectedLocation'
                      : 'Location: $selectedLocation',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: productLocation.locationId.isNotEmpty ? Colors.red[800] : Colors.blue[800],
                  ),
                  overflow: TextOverflow.ellipsis, // Fixed overflow
                  maxLines: 2, // Allow up to 2 lines for long location names
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (productLocation.locationId.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[100],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.red[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quantity Stored: ${productLocation.quantityStored ?? 0}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.red[800],
                    ),
                  ),
                  if (productLocation.metadata?['poNumber'] != null)
                    Text(
                      'PO: ${productLocation.metadata!['poNumber']}',
                      style: TextStyle(fontSize: 12, color: Colors.red[700]),
                      overflow: TextOverflow.ellipsis, // Fixed potential overflow
                    ),
                  if (productLocation.metadata?['supplierName'] != null)
                    Text(
                      'Supplier: ${productLocation.metadata!['supplierName']}',
                      style: TextStyle(fontSize: 12, color: Colors.red[700]),
                      overflow: TextOverflow.ellipsis, // Fixed potential overflow
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          // Fixed: Use Flexible for zone name
          Flexible(
            child: Text(
              'Zone: ${zone?.name ?? 'Unknown'}',
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          // Fixed: Wrap buttons in a responsive layout
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () => _navigateToLocation(selectedLocation!),
                icon: const Icon(Icons.navigation, size: 16),
                label: const Text('Navigate Here'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: productLocation.locationId.isNotEmpty ? Colors.red : Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              OutlinedButton(
                onPressed: () => setState(() => selectedLocation = null),
                child: const Text('Clear'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAisles() {
    return Stack(
      children: [
        Positioned(
          left: 0,
          top: 360,
          right: 0,
          child: Container(
            height: 20,
            color: Colors.grey.shade300,
            child: const Center(
              child: Text('MAIN AISLE', style: TextStyle(fontSize: 10)),
            ),
          ),
        ),
        Positioned(
          left: 260,
          top: 0,
          bottom: 0,
          child: Container(width: 10, color: Colors.grey.shade200),
        ),
        Positioned(
          left: 530,
          top: 0,
          bottom: 0,
          child: Container(width: 10, color: Colors.grey.shade200),
        ),
      ],
    );
  }

  Widget _buildEntryExitPoints() {
    return Stack(
      children: [
        Positioned(
          left: 485,
          bottom: 0,
          child: Container(
            width: 100,
            height: 20,
            color: Colors.green.shade600,
            child: const Center(
              child: Text('ENTRANCE',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHazardIndicator() {
    return const Positioned(
      top: 4,
      right: 4,
      child: Icon(Icons.warning, color: Colors.orange, size: 16),
    );
  }

  Widget _buildClimateIndicator() {
    return const Positioned(
      top: 4,
      right: 4,
      child: Icon(Icons.thermostat, color: Colors.blue, size: 16),
    );
  }

  Widget _buildNavigationPath() {
    return Container(
      child: CustomPaint(
        size: const Size(1000, 800),
        painter: ProductNavigationPathPainter(navigationTarget: navigationTarget),
      ),
    );
  }

  void _stopNavigation() {
    setState(() {
      isNavigating = false;
      navigationTarget = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Navigation completed!'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );
  }
}

class ProductNavigationPathPainter extends CustomPainter {
  final String? navigationTarget;

  const ProductNavigationPathPainter({this.navigationTarget});

  @override
  void paint(Canvas canvas, Size size) {
    if (navigationTarget == null) return;

    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final arrowPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    // Starting point (entrance)
    final startPoint = Offset(535, size.height - 10);

    // Target coordinates
    final targetCoords = _getTargetCoordinates(navigationTarget!);
    if (targetCoords == null) return;

    // Create path from entrance to target
    final path = Path();
    path.moveTo(startPoint.dx, startPoint.dy);

    // Go up to main aisle
    path.lineTo(startPoint.dx, 370);

    // Go horizontally to target zone
    path.lineTo(targetCoords.dx, 370);

    // Go to specific location
    path.lineTo(targetCoords.dx, targetCoords.dy);

    canvas.drawPath(path, paint);

    // Draw arrow at target location
    _drawArrowHead(canvas, targetCoords, arrowPaint);
  }

  void _drawArrowHead(Canvas canvas, Offset target, Paint paint) {
    const double arrowSize = 6;

    // Draw a pulsing circle at the exact location
    final circlePaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    final outlineCirclePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Draw white outline circle
    canvas.drawCircle(target, 5, outlineCirclePaint);
    // Draw red center circle
    canvas.drawCircle(target, 3, circlePaint);

    // Draw arrow pointing down to the location
    final arrowPath = Path();
    arrowPath.moveTo(target.dx, target.dy - 10); // Arrow tip
    arrowPath.lineTo(target.dx - arrowSize, target.dy - 20); // Left arrow wing
    arrowPath.lineTo(target.dx + arrowSize, target.dy - 20); // Right arrow wing
    arrowPath.close();

    canvas.drawPath(arrowPath, paint);
  }

  Offset? _getTargetCoordinates(String target) {
    final parts = target.split('-');
    if (parts.length < 4) {
      return _getZoneCenter(parts[0]);
    }

    final zoneId = parts[0];
    final rackId = parts[1]; // e.g., "R1"
    final rowId = parts[2];  // e.g., "A" or "B"
    final levelId = parts[3]; // e.g., "1", "2", "3", "4"

    // Get zone info
    final zoneInfo = _getZoneInfo(zoneId);
    if (zoneInfo == null) return null;

    // Calculate rack position
    final rackNumber = int.tryParse(rackId.substring(1)) ?? 1;
    final rackIndex = rackNumber - 1;

    // Rack layout constants (matching your buildRackGrid)
    const double rackSize = 60.0;
    const double rackSpacing = 8.0;

    // Calculate racks per row based on zone width
    final racksPerRow = ((zoneInfo['width']! - 16) / (rackSize + rackSpacing)).floor();

    final rackRow = rackIndex ~/ racksPerRow;
    final rackCol = rackIndex % racksPerRow;

    // Base rack position
    final rackX = zoneInfo['left']! + 8 + (rackCol * (rackSize + rackSpacing));
    final rackY = zoneInfo['top']! + 30 + (rackRow * (rackSize + rackSpacing));

    // Now calculate precise position within the rack
    // Rack structure: 16px header + 44px content (split into 2 rows A & B)
    const double rackHeaderHeight = 16.0;
    const double rackContentHeight = 44.0; // 60 - 16
    const double rowSpacing = 2.0;
    const double availableRowHeight = (rackContentHeight - rowSpacing) / 2; // ~21px per row

    // Calculate row position (A = top, B = bottom)
    double rowY = rackY + rackHeaderHeight; // Start after header
    if (rowId == 'B') {
      rowY += availableRowHeight + rowSpacing; // Move to bottom row
    }

    // Add half row height to center vertically in the row
    rowY += availableRowHeight / 2;

    // Calculate level position within row
    const double rowLabelWidth = 12.0; // Width of A/B label
    final availableLevelWidth = rackSize - rowLabelWidth; // ~48px for levels

    final levelNumber = int.tryParse(levelId) ?? 1;
    final levelIndex = levelNumber - 1;

    // Get zone info to determine max levels
    final maxLevels = _getMaxLevelsForZone(zoneId);
    final levelWidth = availableLevelWidth / maxLevels;

    // Calculate level position
    double levelX = rackX + rowLabelWidth + (levelIndex * levelWidth) + (levelWidth / 2);

    return Offset(levelX, rowY);
  }

  int _getMaxLevelsForZone(String zoneId) {
    final levelsByZone = {
      'Z1': 5,
      'Z2': 4,
      'Z3': 3,
      'Z4': 2,
      'Z5': 4,
      'Z6': 3,
    };

    return levelsByZone[zoneId] ?? 4;
  }

// Helper method to get zone information
  Map<String, double>? _getZoneInfo(String zoneId) {
    final zoneCoords = {
      'Z1': {'left': 20.0, 'top': 50.0, 'width': 230.0, 'height': 300.0},
      'Z2': {'left': 270.0, 'top': 50.0, 'width': 250.0, 'height': 300.0},
      'Z3': {'left': 540.0, 'top': 50.0, 'width': 220.0, 'height': 300.0},
      'Z4': {'left': 20.0, 'top': 390.0, 'width': 230.0, 'height': 220.0},
      'Z5': {'left': 270.0, 'top': 390.0, 'width': 250.0, 'height': 220.0},
      'Z6': {'left': 540.0, 'top': 390.0, 'width': 220.0, 'height': 220.0},
    };

    return zoneCoords[zoneId];
  }

// Fallback method for zone centers
  Offset? _getZoneCenter(String zoneId) {
    final zoneCoords = {
      'Z1': const Offset(135, 200),
      'Z2': const Offset(395, 200),
      'Z3': const Offset(650, 200),
      'Z4': const Offset(135, 500),
      'Z5': const Offset(395, 500),
      'Z6': const Offset(650, 500),
    };

    return zoneCoords[zoneId];
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Zone info class (reuse from original)
class ZoneInfo {
  final String name;
  final Color color;
  final String description;
  final int racks;
  final int rows;
  final int levels;

  ZoneInfo({
    required this.name,
    required this.color,
    required this.description,
    required this.racks,
    required this.rows,
    required this.levels,
  });
}