import 'package:flutter/material.dart';

class MultiSelectSupplierDropdown extends StatefulWidget {
  final List<String> selectedSuppliers;
  final List<String> allSuppliers;
  final Function(List<String>) onChanged;
  final String hintText;
  final List<Map<String, dynamic>> purchaseOrders;

  const MultiSelectSupplierDropdown({
    Key? key,
    required this.selectedSuppliers,
    required this.allSuppliers,
    required this.onChanged,
    this.hintText = 'Search suppliers...',
    this.purchaseOrders = const [],
  }) : super(key: key);

  @override
  State<MultiSelectSupplierDropdown> createState() => _MultiSelectSupplierDropdownState();
}

class _MultiSelectSupplierDropdownState extends State<MultiSelectSupplierDropdown> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isDropdownOpen = false;
  List<String> _filteredSuppliers = [];
  OverlayEntry? _overlayEntry;
  final GlobalKey _searchFieldKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _filteredSuppliers = List.from(widget.allSuppliers);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(MultiSelectSupplierDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 🔧 Force rebuild when selected suppliers change for immediate visual feedback
    if (oldWidget.selectedSuppliers != widget.selectedSuppliers) {
      setState(() {});
      // 🔧 FIX: Use post-frame callback to avoid markNeedsBuild during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_overlayEntry != null && mounted) {
          _overlayEntry!.markNeedsBuild();
        }
      });
    }
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _hideDropdown();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus && !_isDropdownOpen) {
      _filteredSuppliers = List.from(widget.allSuppliers);
      _showDropdown();
    }
  }

  void _showDropdown() {
    if (_overlayEntry != null) return;
    
    setState(() {
      _isDropdownOpen = true;
    });

    _overlayEntry = OverlayEntry(
      builder: (context) => _buildDropdownOverlay(),
    );
    
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideDropdown() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
    setState(() {
      _isDropdownOpen = false;
    });
  }

  void _onSearchChanged(String query) {
    List<String> newFilteredSuppliers;
    if (query.isEmpty) {
      newFilteredSuppliers = List.from(widget.allSuppliers);
    } else {
      newFilteredSuppliers = widget.allSuppliers
          .where((supplier) => supplier.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
    
    setState(() {
      _filteredSuppliers = newFilteredSuppliers;
    });
    
    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
    }
  }

  // 🔧 FIX: Toggle supplier with proper timing to avoid build cycle conflicts
  void _toggleSupplier(String supplier) {
    
    List<String> newSelection = List.from(widget.selectedSuppliers);
    if (newSelection.contains(supplier)) {
      newSelection.remove(supplier);
    } else {
      if (!newSelection.contains(supplier)) {
        newSelection.add(supplier);
      }
    }
    
    
    // 🔧 Immediately notify parent (parent will setState and trigger our didUpdateWidget)
    widget.onChanged(newSelection);
    
    // 🔧 FIX: Use post-frame callback to avoid markNeedsBuild during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_overlayEntry != null && mounted) {
        _overlayEntry!.markNeedsBuild();
      }
    });
  }

  void _removeSupplier(String supplier) {
    List<String> newSelection = List.from(widget.selectedSuppliers);
    bool wasRemoved = newSelection.remove(supplier);
    widget.onChanged(newSelection);
  }

  Widget _buildDropdownOverlay() {
    final RenderBox? renderBox = _searchFieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return Container();
    
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final screenSize = MediaQuery.of(context).size;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    
    final spaceBelow = screenSize.height - position.dy - size.height - keyboardHeight - 20;
    final maxDropdownHeight = spaceBelow > 300 ? 300.0 : spaceBelow;

    return GestureDetector(
      onTap: () {
        _focusNode.unfocus();
        _hideDropdown();
      },
      behavior: HitTestBehavior.translucent,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(color: Colors.transparent),
            ),
            Positioned(
              left: position.dx,
              top: position.dy + size.height + 4,
              width: size.width,
              child: GestureDetector(
                onTap: () {},
                child: Material(
                  elevation: 12,
                  borderRadius: BorderRadius.circular(8),
                  shadowColor: Colors.black.withOpacity(0.3),
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: maxDropdownHeight,
                      minHeight: 60,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(8),
                              topRight: Radius.circular(8),
                            ),
                            border: Border(
                              bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                '${_filteredSuppliers.length} supplier${_filteredSuppliers.length == 1 ? '' : 's'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              // 🔧 DISPLAY: Use widget.selectedSuppliers for tags (parent is source of truth for display)
              if (widget.selectedSuppliers.isNotEmpty) ...[
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[100],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${widget.selectedSuppliers.length} selected',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.blue[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        
                        // Supplier list
                        if (_filteredSuppliers.isEmpty)
                          _buildNoResultsFound()
                        else
                          Flexible(
                            child: ListView.separated(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: _filteredSuppliers.length,
                              separatorBuilder: (context, index) => Divider(
                                height: 1,
                                thickness: 0.5,
                                color: Colors.grey[200],
                              ),
                              itemBuilder: (context, index) {
                                final supplier = _filteredSuppliers[index];
                                // 🔧 SIMPLE: Use widget state directly (parent setState ensures fresh data)
                                final isSelected = widget.selectedSuppliers.contains(supplier);
                                final pos = _getPOsForSupplier(supplier);
                                
                                
                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => _toggleSupplier(supplier),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      color: isSelected ? Colors.blue[50] : Colors.white,
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  pos.map((po) => po['poNumber'] ?? 'N/A').join(', '),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 14,
                                                    color: isSelected ? Colors.blue[700] : Colors.grey[800],
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Supplier: $supplier | ${pos.length} order${pos.length == 1 ? '' : 's'}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: isSelected ? Colors.blue[600] : Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Right tick design
                                          Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              color: isSelected ? Colors.blue[600] : Colors.transparent,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: isSelected ? Colors.blue[600]! : Colors.grey[400]!,
                                                width: isSelected ? 0 : 2,
                                              ),
                                            ),
                                            child: isSelected
                                              ? Icon(Icons.check, color: Colors.white, size: 16)
                                              : null,
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
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsFound() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            'No suppliers found',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getPOsForSupplier(String supplier) {
    return widget.purchaseOrders.where((po) => 
      (po['supplierName'] ?? '') == supplier
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Supplier',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        
        // Search field
        Container(
          key: _searchFieldKey,
          decoration: BoxDecoration(
            border: Border.all(
              color: _focusNode.hasFocus ? Colors.blue : Colors.grey[300]!,
              width: _focusNode.hasFocus ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _focusNode,
            decoration: InputDecoration(
              hintText: widget.hintText,
              prefixIcon: Icon(
                Icons.search, 
                color: _focusNode.hasFocus ? Colors.blue : Colors.grey[600], 
                size: 20
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey[600], size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : Icon(Icons.keyboard_arrow_down, color: Colors.grey[600], size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            onChanged: _onSearchChanged,
            onTap: () {
              if (!_isDropdownOpen) {
                _filteredSuppliers = List.from(widget.allSuppliers);
                _showDropdown();
              }
            },
          ),
        ),
        
        // Selected suppliers tags (no duplicates possible)
        if (widget.selectedSuppliers.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: widget.selectedSuppliers.toSet().map((supplier) { // Use toSet() to ensure uniqueness
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue[300]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      supplier,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => _removeSupplier(supplier),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.blue[600],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}