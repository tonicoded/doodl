import 'package:flutter/material.dart';
import '../theme/background.dart';

class DoodlPage extends StatelessWidget {
  const DoodlPage({
    super.key,
    required this.child,
    this.safeArea = true,
  });

  final Widget child;
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    final content = safeArea ? SafeArea(child: child) : child;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Stack(
          children: [
            const DoodlBackground(),
            content,
          ],
        ),
      ),
    );
  }
}
