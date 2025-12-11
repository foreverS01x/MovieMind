import 'package:flutter/material.dart';

class ExpandableText extends StatefulWidget {
  final String text;
  final int maxLines;
  final TextStyle? style;

  const ExpandableText({
    super.key, 
    required this.text, 
    this.maxLines = 3,
    this.style,
  });

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, size) {
      final span = TextSpan(text: widget.text, style: widget.style);
      final tp = TextPainter(
        text: span, 
        maxLines: widget.maxLines, 
        textDirection: TextDirection.ltr
      );
      tp.layout(maxWidth: size.maxWidth);

      if (!tp.didExceedMaxLines) {
        return Text(widget.text, style: widget.style);
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.text,
            maxLines: _expanded ? null : widget.maxLines,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: widget.style,
          ),
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                _expanded ? '收起' : '显示全部',
                style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
        ],
      );
    });
  }
}

