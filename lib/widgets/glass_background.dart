import 'package:flutter/material.dart';

class GlassBackground extends StatelessWidget {
  final Widget child;

  const GlassBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base mesh dark background
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF0F172A), // Dark slate blue
                Color(0xFF020617), // Deep midnight blue/black
                Color(0xFF1E1E2F), // Dark purple tint
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        
        // Orange/Red glowing blob (Top Left)
        Positioned(
          top: -120,
          left: -120,
          child: Container(
            width: 380,
            height: 380,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFF7E5F).withValues(alpha: 0.12),
            ),
          ),
        ),

        // Purple glowing blob (Bottom Right)
        Positioned(
          bottom: -80,
          right: -100,
          child: Container(
            width: 420,
            height: 420,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF9B5DE5).withValues(alpha: 0.15),
            ),
          ),
        ),

        // Deep blue glowing blob (Center Left)
        Positioned(
          top: MediaQuery.of(context).size.height * 0.4,
          left: -150,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF00F2FE).withValues(alpha: 0.10),
            ),
          ),
        ),

        // Content
        child,
      ],
    );
  }
}
