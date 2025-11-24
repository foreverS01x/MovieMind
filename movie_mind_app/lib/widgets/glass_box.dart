import 'dart:ui';
import 'package:flutter/material.dart';

class GlassBox extends StatelessWidget {
  final double? width;
  final double? height;
  final Widget child;
  final double borderRadius;
  final double blur;
  final double opacity;
  final Color color;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BoxBorder? border;

  const GlassBox({
    super.key,
    this.width,
    this.height,
    required this.child,
    this.borderRadius = 15,
    this.blur = 10,
    this.opacity = 0.1, // 默认很淡的白色
    this.color = Colors.white,
    this.padding,
    this.margin,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: color.withOpacity(opacity),
              borderRadius: BorderRadius.circular(borderRadius),
              border: border ?? Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

