import 'package:flutter/material.dart';

class DoodlBackground extends StatelessWidget {
  const DoodlBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFF7F7FA),
            Color(0xFFF2F2F6),
          ],
        ),
      ),
      child: Container(color: Colors.white.withOpacity(0.70)),
    );
  }
}
