import 'package:flutter/material.dart';

class DoodlLogo extends StatelessWidget {
  const DoodlLogo({
    super.key,
    this.height = 44,
  });

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo.png',
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Text(
          'DOODL.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: height,
            height: 1,
            fontWeight: FontWeight.w900,
            color: Colors.black.withOpacity(0.92),
            letterSpacing: -1,
          ),
        );
      },
    );
  }
}
