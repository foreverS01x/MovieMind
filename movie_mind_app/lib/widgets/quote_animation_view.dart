import 'dart:math';
import 'package:flutter/material.dart';

class QuoteAnimationView extends StatefulWidget {
  final List<String> quotes;
  const QuoteAnimationView({super.key, required this.quotes});

  @override
  State<QuoteAnimationView> createState() => _QuoteAnimationViewState();
}

class _QuoteAnimationViewState extends State<QuoteAnimationView> with TickerProviderStateMixin {
  late AnimationController _controller;
  final List<BubbleState> _bubbles = [];
  bool _showCinema = false;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 15));
    _startAnimationSequence();
  }

  void _startAnimationSequence() async {
    // 1. Generate bubbles one by one
    for (int i = 0; i < widget.quotes.length; i++) {
      if (!mounted) return;
      await Future.delayed(Duration(milliseconds: 300 + Random().nextInt(500)));
      if (mounted) {
        setState(() {
          _bubbles.add(BubbleState(
            text: widget.quotes[i],
            position: _getRandomPosition(),
            controller: AnimationController(
              vsync: this,
              duration: const Duration(milliseconds: 600),
            )..forward(),
          ));
        });
      }
    }

    // 2. Wait a bit then fade out
    await Future.delayed(const Duration(seconds: 2));
    
    // Fade out bubbles one by one
    for (var bubble in _bubbles) {
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 100));
      bubble.controller.reverse();
    }
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    // 3. Show cinema icon
    if (mounted) {
      setState(() {
        _showCinema = true;
      });
    }
  }

  Offset _getRandomPosition() {
    final random = Random();
    // Generate position in center area
    // Assuming container size roughly 300x400
    double dx = random.nextDouble() * 200 - 100; // -100 to 100
    double dy = random.nextDouble() * 200 - 100; // -100 to 100
    return Offset(dx, dy);
  }

  @override
  void dispose() {
    _controller.dispose();
    for (var bubble in _bubbles) {
      bubble.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Speakers and Ears on sides
          Positioned(
            left: 0,
            child: Icon(Icons.volume_up, size: 40, color: Colors.black54),
          ),
          Positioned(
            right: 0,
            child: Icon(Icons.hearing, size: 40, color: Colors.black54),
          ),
          
          // Bubbles area
          ..._bubbles.map((bubble) => AnimatedBuilder(
            animation: bubble.controller,
            builder: (context, child) {
              final scale = bubble.controller.value;
              final opacity = bubble.controller.value;
              
              if (scale == 0) return const SizedBox();
              
              return Transform.translate(
                offset: bubble.position,
                child: Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: scale,
                    child: _buildBubble(bubble.text),
                  ),
                ),
              );
            },
          )).toList(),

          // Final Cinema Icon
          if (_showCinema)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(seconds: 1),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.scale(
                    scale: value,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.movie_creation_outlined, size: 80, color: Colors.black87),
                        const SizedBox(height: 16),
                        const Text('MovieMind', style: TextStyle(
                          fontSize: 24, 
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Georgia',
                          fontStyle: FontStyle.italic
                        )),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBubble(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }
}

class BubbleState {
  final String text;
  final Offset position;
  final AnimationController controller;

  BubbleState({
    required this.text, 
    required this.position, 
    required this.controller
  });
}

