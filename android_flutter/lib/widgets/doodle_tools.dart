import 'dart:math' as math;

import 'package:flutter/material.dart';

enum DoodleBrushStyle { pen, pencil, marker, highlighter }

double doodleDefaultWidthForStyle(DoodleBrushStyle style) {
  return switch (style) {
    DoodleBrushStyle.pen => 6,
    DoodleBrushStyle.pencil => 3.5,
    DoodleBrushStyle.marker => 9,
    DoodleBrushStyle.highlighter => 13,
  };
}

double doodleDefaultOpacityForStyle(DoodleBrushStyle style) {
  return switch (style) {
    DoodleBrushStyle.pen => 1.0,
    DoodleBrushStyle.pencil => 0.55,
    DoodleBrushStyle.marker => 0.95,
    DoodleBrushStyle.highlighter => 0.28,
  };
}

enum DoodleTemplate {
  none,
  grid,
  dots,
  face,
  heart,
  star,
  lightning,
  crown,
  butterfly,
}

const doodleFeaturedTemplates = <DoodleTemplate>[
  DoodleTemplate.none,
  DoodleTemplate.grid,
  DoodleTemplate.dots,
  DoodleTemplate.face,
  DoodleTemplate.heart,
  DoodleTemplate.star,
  DoodleTemplate.lightning,
  DoodleTemplate.crown,
  DoodleTemplate.butterfly,
];

class DoodleTemplateOverlay extends StatelessWidget {
  const DoodleTemplateOverlay({
    super.key,
    required this.template,
    required this.opacity,
    this.isDarkBackground = false,
  });

  final DoodleTemplate template;
  final double opacity;
  final bool isDarkBackground;

  @override
  Widget build(BuildContext context) {
    if (template == DoodleTemplate.none || opacity <= 0)
      return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        painter: _DoodleTemplatePainter(
          template: template,
          opacity: opacity,
          isDarkBackground: isDarkBackground,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class DoodleToolsSheet extends StatelessWidget {
  const DoodleToolsSheet({
    super.key,
    required this.isEraser,
    required this.brushStyle,
    required this.selectedColor,
    required this.strokeWidth,
    required this.opacity,
    required this.template,
    required this.templateOpacity,
    required this.onEraserChanged,
    required this.onBrushStyleChanged,
    required this.onColorChanged,
    required this.onStrokeWidthChanged,
    required this.onOpacityChanged,
    required this.onTemplateChanged,
    required this.onTemplateOpacityChanged,
  });

  final bool isEraser;
  final DoodleBrushStyle brushStyle;
  final Color selectedColor;
  final double strokeWidth;
  final double opacity;
  final DoodleTemplate template;
  final double templateOpacity;

  final ValueChanged<bool> onEraserChanged;
  final ValueChanged<DoodleBrushStyle> onBrushStyleChanged;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<double> onStrokeWidthChanged;
  final ValueChanged<double> onOpacityChanged;
  final ValueChanged<DoodleTemplate> onTemplateChanged;
  final ValueChanged<double> onTemplateOpacityChanged;

  @override
  Widget build(BuildContext context) {
    final colors = <Color>[
      Colors.black,
      Colors.red,
      Colors.orange,
      Colors.yellow,
      Colors.green,
      Colors.teal,
      Colors.blue,
      Colors.purple,
      Colors.pink,
      Colors.brown,
      const Color(0xFF2AD1D1),
      const Color(0xFFFFFC00),
    ];

    Widget sectionTitle(String text) {
      return Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: Colors.black.withOpacity(0.65),
        ),
      );
    }

    Widget card(Widget child) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.86),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withOpacity(0.08)),
        ),
        child: child,
      );
    }

    Widget styleChip(DoodleBrushStyle style, String label, IconData icon) {
      final selected = !isEraser && brushStyle == style;
      return ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
        selected: selected,
        onSelected: (_) => onBrushStyleChanged(style),
        selectedColor: Colors.black.withOpacity(0.08),
        backgroundColor: Colors.black.withOpacity(0.04),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              sectionTitle('template'),
              const SizedBox(height: 10),
              SizedBox(
                height: 54,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: doodleFeaturedTemplates.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final t = doodleFeaturedTemplates[i];
                    final selected = t == template;
                    return GestureDetector(
                      onTap: () => onTemplateChanged(t),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        width: 54,
                        height: 54,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selected
                                ? Colors.black
                                : Colors.black.withOpacity(0.14),
                            width: selected ? 3 : 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: DoodleTemplateOverlay(
                            template: t,
                            opacity: 0.65,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'template opacity',
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.70),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(templateOpacity * 100).round()}%',
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.70),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              Slider(
                value: templateOpacity,
                min: 0,
                max: 0.9,
                onChanged: onTemplateOpacityChanged,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              sectionTitle('brush'),
              const SizedBox(height: 10),
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => onEraserChanged(!isEraser),
                    icon: Icon(isEraser
                        ? Icons.edit_rounded
                        : Icons.cleaning_services_rounded),
                    label: Text(isEraser ? 'pen' : 'eraser'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'stroke ${strokeWidth.toStringAsFixed(1)}',
                          style: TextStyle(
                            color: Colors.black.withOpacity(0.70),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 9),
                            overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 18),
                          ),
                          child: Slider(
                            value: strokeWidth,
                            min: 1.5,
                            max: 22,
                            onChanged: onStrokeWidthChanged,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  styleChip(
                      DoodleBrushStyle.pencil, 'pencil', Icons.edit_outlined),
                  styleChip(DoodleBrushStyle.pen, 'pen', Icons.brush_rounded),
                  styleChip(
                      DoodleBrushStyle.marker, 'marker', Icons.brush_outlined),
                  styleChip(DoodleBrushStyle.highlighter, 'highlight',
                      Icons.auto_awesome_rounded),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'opacity',
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.70),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(opacity * 100).round()}%',
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.70),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              Slider(
                value: opacity,
                min: 0.05,
                max: 1,
                onChanged: isEraser ? null : onOpacityChanged,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: colors.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final c = colors[i];
                    final selected =
                        !isEraser && c.value == selectedColor.value;
                    return GestureDetector(
                      onTap: () => onColorChanged(c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? Colors.black
                                : Colors.black.withOpacity(0.15),
                            width: selected ? 3 : 1,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _DoodleTemplatePainter extends CustomPainter {
  _DoodleTemplatePainter({
    required this.template,
    required this.opacity,
    required this.isDarkBackground,
  });

  final DoodleTemplate template;
  final double opacity;
  final bool isDarkBackground;

  @override
  void paint(Canvas canvas, Size size) {
    final c = isDarkBackground ? Colors.white : Colors.black;
    final base = c.withOpacity((opacity * 0.75).clamp(0.0, 1.0));
    final paint = Paint()
      ..color = base
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = math.max(1, size.shortestSide * 0.012);

    final s = size.shortestSide;
    final pad = s * 0.10;
    final rect =
        Rect.fromLTWH(pad, pad, size.width - pad * 2, size.height - pad * 2);

    switch (template) {
      case DoodleTemplate.none:
        return;
      case DoodleTemplate.grid:
        _paintGrid(canvas, rect, paint);
        return;
      case DoodleTemplate.dots:
        _paintDots(canvas, rect, paint);
        return;
      case DoodleTemplate.face:
        _paintFaceGuide(canvas, rect, paint);
        return;
      case DoodleTemplate.heart:
        _paintHeart(canvas, rect, paint);
        return;
      case DoodleTemplate.star:
        _paintStar(canvas, rect, paint);
        return;
      case DoodleTemplate.lightning:
        _paintLightning(canvas, rect, paint);
        return;
      case DoodleTemplate.crown:
        _paintCrown(canvas, rect, paint);
        return;
      case DoodleTemplate.butterfly:
        _paintButterfly(canvas, rect, paint);
        return;
    }
  }

  void _paintGrid(Canvas canvas, Rect rect, Paint paint) {
    final step = rect.width / 6;
    final p = paint..strokeWidth = math.max(1, paint.strokeWidth * 0.75);
    for (var i = 1; i < 6; i++) {
      final x = rect.left + step * i;
      final y = rect.top + step * i;
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), p);
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), p);
    }
    canvas.drawRect(
        rect,
        p
          ..color =
              paint.color.withOpacity((paint.color.opacity * 0.6).clamp(0, 1)));
  }

  void _paintDots(Canvas canvas, Rect rect, Paint paint) {
    final dotPaint = Paint()
      ..color =
          paint.color.withOpacity((paint.color.opacity * 0.8).clamp(0, 1));
    final step = rect.width / 6.5;
    final r = math.max(1.1, paint.strokeWidth * 0.55);
    for (var y = rect.top + step * 0.6; y < rect.bottom; y += step) {
      for (var x = rect.left + step * 0.6; x < rect.right; x += step) {
        canvas.drawCircle(Offset(x, y), r, dotPaint);
      }
    }
  }

  void _paintFaceGuide(Canvas canvas, Rect rect, Paint paint) {
    final r = rect.shortestSide * 0.44;
    canvas.drawCircle(rect.center, r, paint);
    final eyeY = rect.center.dy - r * 0.18;
    final eyeX = r * 0.38;
    final eyeR = r * 0.10;
    canvas.drawCircle(Offset(rect.center.dx - eyeX, eyeY), eyeR, paint);
    canvas.drawCircle(Offset(rect.center.dx + eyeX, eyeY), eyeR, paint);
    final noseTop = Offset(rect.center.dx, rect.center.dy - r * 0.02);
    final noseLeft =
        Offset(rect.center.dx - r * 0.08, rect.center.dy + r * 0.10);
    final noseRight =
        Offset(rect.center.dx + r * 0.08, rect.center.dy + r * 0.10);
    canvas.drawPath(
      Path()
        ..moveTo(noseTop.dx, noseTop.dy)
        ..lineTo(noseLeft.dx, noseLeft.dy)
        ..lineTo(noseRight.dx, noseRight.dy)
        ..close(),
      paint..strokeWidth = math.max(1, paint.strokeWidth * 0.85),
    );
  }

  void _paintHeart(Canvas canvas, Rect rect, Paint paint) {
    final cx = rect.center.dx;
    final cy = rect.center.dy;
    final w = rect.width * 0.72;
    final h = rect.height * 0.66;
    final top = cy - h * 0.20;

    final path = Path()
      ..moveTo(cx, top + h * 0.60)
      ..cubicTo(
          cx - w * 0.55, top + h * 0.34, cx - w * 0.55, top, cx, top + h * 0.24)
      ..cubicTo(
          cx + w * 0.55, top, cx + w * 0.55, top + h * 0.34, cx, top + h * 0.60)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _paintStar(Canvas canvas, Rect rect, Paint paint) {
    final c = rect.center;
    final outer = rect.shortestSide * 0.42;
    final inner = outer * 0.46;
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final isOuter = i.isEven;
      final r = isOuter ? outer : inner;
      final a = (-math.pi / 2) + (math.pi / 5) * i;
      final p = Offset(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _paintLightning(Canvas canvas, Rect rect, Paint paint) {
    final path = Path();
    final x = rect.left + rect.width * 0.55;
    final y = rect.top + rect.height * 0.14;
    final w = rect.width * 0.30;
    final h = rect.height * 0.72;
    path
      ..moveTo(x, y)
      ..lineTo(x - w * 0.55, y + h * 0.40)
      ..lineTo(x + w * 0.05, y + h * 0.40)
      ..lineTo(x - w * 0.25, y + h)
      ..lineTo(x + w * 0.65, y + h * 0.55)
      ..lineTo(x + w * 0.15, y + h * 0.55)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _paintCrown(Canvas canvas, Rect rect, Paint paint) {
    final left = rect.left + rect.width * 0.18;
    final right = rect.right - rect.width * 0.18;
    final bottom = rect.bottom - rect.height * 0.18;
    final top = rect.top + rect.height * 0.26;
    final mid = rect.center.dx;

    final path = Path()
      ..moveTo(left, bottom)
      ..lineTo(left + rect.width * 0.10, top + rect.height * 0.16)
      ..lineTo(mid - rect.width * 0.14, top + rect.height * 0.28)
      ..lineTo(mid, top)
      ..lineTo(mid + rect.width * 0.14, top + rect.height * 0.28)
      ..lineTo(right - rect.width * 0.10, top + rect.height * 0.16)
      ..lineTo(right, bottom)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawLine(Offset(left, bottom), Offset(right, bottom), paint);
  }

  void _paintButterfly(Canvas canvas, Rect rect, Paint paint) {
    final c = rect.center;
    final w = rect.width * 0.34;
    final h = rect.height * 0.40;
    final path = Path();

    Path wingPath(double dir) {
      final p = Path()
        ..moveTo(c.dx, c.dy)
        ..cubicTo(c.dx + dir * w * 0.15, c.dy - h * 1.0, c.dx + dir * w * 1.2,
            c.dy - h * 0.5, c.dx + dir * w * 0.95, c.dy)
        ..cubicTo(c.dx + dir * w * 1.2, c.dy + h * 0.5, c.dx + dir * w * 0.15,
            c.dy + h * 1.0, c.dx, c.dy)
        ..close();
      return p;
    }

    path.addPath(wingPath(-1), Offset.zero);
    path.addPath(wingPath(1), Offset.zero);
    canvas.drawPath(path, paint);

    final bodyPaint = Paint()
      ..color = paint.color.withOpacity((paint.color.opacity * 0.9).clamp(0, 1))
      ..strokeWidth = math.max(1.2, paint.strokeWidth * 0.9)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(c.dx, c.dy - h * 0.55),
        Offset(c.dx, c.dy + h * 0.55), bodyPaint);
  }

  @override
  bool shouldRepaint(covariant _DoodleTemplatePainter oldDelegate) {
    return oldDelegate.template != template ||
        oldDelegate.opacity != opacity ||
        oldDelegate.isDarkBackground != isDarkBackground;
  }
}
