import 'package:flutter/material.dart';

class QuantityInputWidget extends StatefulWidget {
  final String label;
  final int initialValue;
  final int maxValue;
  final int minValue; // Add minimum value parameter
  final Function(int) onChanged;
  final bool enabled;
  final Color? color;

  const QuantityInputWidget({
    Key? key,
    required this.label,
    required this.initialValue,
    required this.maxValue,
    required this.minValue, // Add minimum value parameter
    required this.onChanged,
    this.enabled = true,
    this.color,
  }) : super(key: key);

  @override
  State<QuantityInputWidget> createState() => _QuantityInputWidgetState();
}

class _QuantityInputWidgetState extends State<QuantityInputWidget> {
  late int _currentValue;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.initialValue;
    _controller = TextEditingController(text: _currentValue.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _increment() {
    if (widget.enabled && _currentValue < widget.maxValue) {
      setState(() {
        _currentValue++;
        _controller.text = _currentValue.toString();
      });
      widget.onChanged(_currentValue);
    }
  }

  void _decrement() {
    if (widget.enabled && _currentValue > widget.minValue) {
      setState(() {
        _currentValue--;
        _controller.text = _currentValue.toString();
      });
      widget.onChanged(_currentValue);
    }
  }

  void _onTextChanged(String value) {
    int? newValue = int.tryParse(value);
    if (newValue != null && newValue >= widget.minValue && newValue <= widget.maxValue) {
      setState(() {
        _currentValue = newValue;
      });
      widget.onChanged(_currentValue);
    } else if (value.isEmpty) {
      setState(() {
        _currentValue = widget.minValue;
      });
      widget.onChanged(widget.minValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${widget.label} (min: ${widget.minValue})',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            // Decrement button
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: widget.enabled ? Colors.grey[100] : Colors.grey[50],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: IconButton(
                onPressed: widget.enabled ? _decrement : null,
                icon: Icon(
                  Icons.remove,
                  size: 16,
                  color: widget.enabled ? Colors.grey[700] : Colors.grey[400],
                ),
                padding: EdgeInsets.zero,
              ),
            ),
            
            // Input field
            Expanded(
              child: Container(
                height: 32,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: TextField(
                  controller: _controller,
                  enabled: widget.enabled,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  onChanged: _onTextChanged,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: widget.color ?? Colors.blue),
                    ),
                    filled: true,
                    fillColor: widget.enabled ? Colors.white : Colors.grey[50],
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: widget.enabled ? Colors.black : Colors.grey[400],
                  ),
                ),
              ),
            ),
            
            // Increment button
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: widget.enabled ? Colors.grey[100] : Colors.grey[50],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: IconButton(
                onPressed: widget.enabled ? _increment : null,
                icon: Icon(
                  Icons.add,
                  size: 16,
                  color: widget.enabled ? Colors.grey[700] : Colors.grey[400],
                ),
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
