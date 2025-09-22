import 'package:flutter/material.dart';

import '../../models/product_category_model.dart';

class CategoryFormWidget extends StatefulWidget {
  final CategoryModel? category;
  final Function(CategoryModel) onSubmit;
  final VoidCallback? onCancel;

  const CategoryFormWidget({
    super.key,
    this.category,
    required this.onSubmit,
    this.onCancel,
  });

  @override
  State<CategoryFormWidget> createState() => _CategoryFormWidgetState();
}

class _CategoryFormWidgetState extends State<CategoryFormWidget> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  late String _selectedIcon;
  late Color _selectedColor;

  // Available icons for categories
  static const Map<String, IconData> availableIcons = {
    'category': Icons.category,
    'build': Icons.build,
    'car_repair': Icons.car_repair,
    'electrical_services': Icons.electrical_services,
    'local_gas_station': Icons.local_gas_station,
    'tire_repair': Icons.tire_repair,
    'settings': Icons.settings,
    'lightbulb': Icons.lightbulb,
    'air': Icons.air,
    'speed': Icons.speed,
    'ac_unit': Icons.ac_unit,
    'water_drop': Icons.water_drop,
    'power': Icons.power,
    'tune': Icons.tune,
    'directions_car': Icons.directions_car,
  };

  // Predefined colors for categories
  static const List<Color> availableColors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.red,
    Colors.purple,
    Colors.teal,
    Colors.indigo,
    Colors.pink,
    Colors.amber,
    Colors.cyan,
    Colors.lime,
    Colors.deepOrange,
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _descriptionController =
        TextEditingController(text: widget.category?.description ?? '');
    _selectedIcon = widget.category?.iconName ?? 'category';
    _selectedColor = widget.category?.color ?? Colors.blue;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.category != null;

  void _handleSubmit() {
    if (_formKey.currentState!.validate()) {
      final now = DateTime.now();
      final category = CategoryModel(
        id: widget.category?.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        iconName: _selectedIcon,
        color: _selectedColor,
        isActive: widget.category?.isActive ?? true,
        createdAt: widget.category?.createdAt ?? now,
        updatedAt: now,
      );

      widget.onSubmit(category);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNameField(),
            const SizedBox(height: 16),
            _buildDescriptionField(),
            const SizedBox(height: 16),
            _buildIconSelection(),
            const SizedBox(height: 16),
            _buildColorSelection(),
            const SizedBox(height: 16),
            _buildPreview(),
            const SizedBox(height: 24),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      decoration: const InputDecoration(
        labelText: 'Category Name *',
        border: OutlineInputBorder(),
        hintText: 'e.g., Engine Parts',
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter category name';
        }
        return null;
      },
      onChanged: (value) => setState(() {}), // Trigger preview update
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      decoration: const InputDecoration(
        labelText: 'Description',
        border: OutlineInputBorder(),
        hintText: 'Brief description of this category',
      ),
      maxLines: 3,
      onChanged: (value) => setState(() {}), // Trigger preview update
    );
  }

  Widget _buildIconSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Icon:', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: availableIcons.length,
            itemBuilder: (context, index) {
              final iconEntry = availableIcons.entries.elementAt(index);
              final iconName = iconEntry.key;
              final iconData = iconEntry.value;
              final isSelected = _selectedIcon == iconName;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedIcon = iconName;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  width: 50,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected ? _selectedColor : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: isSelected ? _selectedColor.withOpacity(0.1) : null,
                  ),
                  child: Icon(
                    iconData,
                    color: isSelected ? _selectedColor : Colors.grey[600],
                    size: 24,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildColorSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Color:', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: availableColors.length,
            itemBuilder: (context, index) {
              final color = availableColors[index];
              final isSelected = _selectedColor == color;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedColor = color;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.black : Colors.grey[400]!,
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Preview:', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _selectedColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  availableIcons[_selectedIcon]!,
                  color: _selectedColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nameController.text.isEmpty
                          ? 'Category Name'
                          : _nameController.text,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    if (_descriptionController.text.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _descriptionController.text,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (widget.onCancel != null)
          TextButton(
            onPressed: widget.onCancel,
            child: const Text('Cancel'),
          ),
        const SizedBox(width: 8),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _isEditing ? Colors.orange : Colors.green,
            foregroundColor: Colors.white,
          ),
          onPressed: _handleSubmit,
          child: Text(_isEditing ? 'Update' : 'Create'),
        ),
      ],
    );
  }
}