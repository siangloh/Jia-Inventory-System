import 'package:flutter/material.dart';

class ExpandableCard extends StatefulWidget {
  final String id;
  final Widget header;
  final Widget content;
  final Widget expandedContent;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final Color? statusColor;
  final String? statusText;
  
  const ExpandableCard({
    Key? key,
    required this.id,
    required this.header,
    required this.content,
    required this.expandedContent,
    required this.isExpanded,
    required this.onToggleExpand,
    this.statusColor,
    this.statusText,
  }) : super(key: key);
  
  @override
  State<ExpandableCard> createState() => _ExpandableCardState();
}

class _ExpandableCardState extends State<ExpandableCard> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 200),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    
    if (widget.isExpanded) {
      _animationController.forward();
    }
  }
  
  @override
  void didUpdateWidget(ExpandableCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: widget.isExpanded ? 4 : 2,
      color: widget.isExpanded ? Colors.white : Colors.grey[50], // Light color when collapsed
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: widget.isExpanded 
              ? Theme.of(context).primaryColor.withOpacity(0.3)
              : Colors.grey[200]!,
          width: widget.isExpanded ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: widget.onToggleExpand,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          child: Column(
            children: [
              // Header with status badge
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: widget.header),
                        if (widget.statusText != null)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: widget.statusColor?.withOpacity(0.1) ?? Colors.grey[100],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: widget.statusColor?.withOpacity(0.3) ?? Colors.grey[300]!,
                              ),
                            ),
                            child: Text(
                              widget.statusText!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: widget.statusColor ?? Colors.grey[700],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    widget.content,
                  ],
                ),
              ),
              
              // Expandable details section
              SizeTransition(
                sizeFactor: _expandAnimation,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(12),
                    ),
                  ),
                  child: Column(
                    children: [
                      Divider(height: 1, color: Colors.grey[300]),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: widget.expandedContent,
                      ),
                    ],
                  ),
                ),
              ),
              
              // Expand/Collapse indicator
              Container(
                padding: const EdgeInsets.only(bottom: 8),
                child: Icon(
                  widget.isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 20,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}