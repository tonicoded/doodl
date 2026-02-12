import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scribble/scribble.dart';

import '../../models/direct_chat_thread.dart';
import '../../models/group_summary.dart';
import '../../models/onboarding.dart';
import '../../i18n/strings_provider.dart';
import '../../services/doodl_api.dart';
import '../../utils/data_url.dart';
import '../../widgets/doodl_logo.dart';
import '../../widgets/doodle_tools.dart';
import '../../widget/widget_service.dart';

class DoodleScreen extends ConsumerStatefulWidget {
  const DoodleScreen({super.key, required this.onboarding});

  final OnboardingData onboarding;

  @override
  ConsumerState<DoodleScreen> createState() => _DoodleScreenState();
}

class _DoodleScreenState extends ConsumerState<DoodleScreen> {
  final controller = ScribbleNotifier();
  final repaintKey = GlobalKey();

  bool sending = false;
  bool isEraser = false;
  double strokeWidth = 6;
  double _strokeScale = 1.0;
  double brushOpacity = 1.0;
  Color selectedColor = Colors.black;
  DoodleBrushStyle brushStyle = DoodleBrushStyle.pen;
  DoodleTemplate template = DoodleTemplate.none;
  double templateOpacity = 0.26;

  @override
  void initState() {
    super.initState();
    brushOpacity = doodleDefaultOpacityForStyle(brushStyle);
    _applyBrush();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.sizeOf(context);
    final canvasSize = (size.width - 36).clamp(260, 520).toDouble();
    final scale = (360 / canvasSize).clamp(0.8, 1.0);
    if (_strokeScale != scale) {
      _strokeScale = scale;
      _applyBrush();
    }
  }

  void _applyBrush() {
    controller.setStrokeWidth(strokeWidth * _strokeScale);
    if (isEraser) {
      controller.setEraser();
      return;
    }
    var c = selectedColor;
    controller.setColor(c.withOpacity(brushOpacity.clamp(0.05, 1.0)));
  }

  void _setBrushStyle(DoodleBrushStyle style) {
    setState(() {
      brushStyle = style;
      isEraser = false;
      strokeWidth = doodleDefaultWidthForStyle(style);
      brushOpacity = doodleDefaultOpacityForStyle(style);
    });
    _applyBrush();
  }

  void _setColor(Color c) {
    setState(() {
      selectedColor = c;
      isEraser = false;
    });
    _applyBrush();
  }

  void _setStrokeWidth(double v) {
    setState(() => strokeWidth = v);
    _applyBrush();
  }

  void _setOpacity(double v) {
    setState(() => brushOpacity = v);
    _applyBrush();
  }

  Future<Uint8List> _exportPng() async {
    final boundary =
        repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) throw Exception('canvas not ready');
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw Exception('export failed');
    return bytes.buffer.asUint8List();
  }

  Future<void> _openSendSheet() async {
    if (sending) return;
    try {
      final png = await _exportPng();
      final content = pngBytesToDataUrl(png);
      if (!mounted) return;

      final sent = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) {
          final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
          return Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: _SendDoodleSheet(
              onboarding: widget.onboarding,
              contentBase64: content,
            ),
          );
        },
      );

      if (sent == true) {
        controller.clear();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final size = MediaQuery.sizeOf(context);
    final canvasSize = (size.width - 36).clamp(260, 520).toDouble();

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 160),
          children: [
            const Center(child: DoodlLogo(height: 90)),
            const SizedBox(height: 8),
            Text(
              strings.drawAndSend,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            Center(
              child: SizedBox(
                width: canvasSize,
                height: canvasSize,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                          color: Colors.black.withOpacity(0.10), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 22,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: RepaintBoundary(
                      key: repaintKey,
                      // Include a solid background in exports; otherwise PNGs can be transparent.
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Container(color: Colors.white),
                          ),
                          Positioned.fill(
                            child: DoodleTemplateOverlay(
                              template: template,
                              opacity: templateOpacity,
                            ),
                          ),
                          Scribble(notifier: controller),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _toolButton(
                  icon: Icons.brush_rounded,
                  onTap: () => _openTools(context),
                ),
                _toolPill(
                  children: [
                    IconButton(
                      onPressed: () => controller.undo(),
                      icon: const Icon(Icons.undo_rounded),
                    ),
                    IconButton(
                      onPressed: () => controller.redo(),
                      icon: const Icon(Icons.redo_rounded),
                    ),
                    IconButton(
                      onPressed: () => controller.clear(),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 98,
          child: Center(
            child: GestureDetector(
              onTap: _openSendSheet,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.black.withOpacity(0.14), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.14),
                      blurRadius: 28,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 30),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _toolButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.white.withOpacity(0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: Colors.black.withOpacity(0.78)),
              const SizedBox(width: 8),
              const Text('tools',
                  style: TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolPill({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withOpacity(0.10)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  Future<void> _openTools(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        var localIsEraser = isEraser;
        var localBrushStyle = brushStyle;
        var localColor = selectedColor;
        var localStrokeWidth = strokeWidth;
        var localOpacity = brushOpacity;
        var localTemplate = template;
        var localTemplateOpacity = templateOpacity;

        return StatefulBuilder(
          builder: (context, setSheetState) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: DoodleToolsSheet(
              isEraser: localIsEraser,
              brushStyle: localBrushStyle,
              selectedColor: localColor,
              strokeWidth: localStrokeWidth,
              opacity: localOpacity,
              template: localTemplate,
              templateOpacity: localTemplateOpacity,
              onEraserChanged: (value) {
                setSheetState(() => localIsEraser = value);
                setState(() => isEraser = value);
                _applyBrush();
              },
              onBrushStyleChanged: (style) {
                setSheetState(() => localBrushStyle = style);
                _setBrushStyle(style);
              },
              onColorChanged: (color) {
                setSheetState(() => localColor = color);
                _setColor(color);
              },
              onStrokeWidthChanged: (value) {
                setSheetState(() => localStrokeWidth = value);
                _setStrokeWidth(value);
              },
              onOpacityChanged: (value) {
                setSheetState(() => localOpacity = value);
                _setOpacity(value);
              },
              onTemplateChanged: (t) {
                setSheetState(() => localTemplate = t);
                setState(() => template = t);
              },
              onTemplateOpacityChanged: (value) {
                setSheetState(() => localTemplateOpacity = value);
                setState(() => templateOpacity = value);
              },
            ),
          ),
        );
      },
    );
  }
}

class _Recipient {
  const _Recipient(
      {required this.code, required this.title, required this.subtitle});

  final String code;
  final String title;
  final String subtitle;
}

class _SendDoodleSheet extends ConsumerStatefulWidget {
  const _SendDoodleSheet(
      {required this.onboarding, required this.contentBase64});

  final OnboardingData onboarding;
  final String contentBase64;

  @override
  ConsumerState<_SendDoodleSheet> createState() => _SendDoodleSheetState();
}

class _SendDoodleSheetState extends ConsumerState<_SendDoodleSheet> {
  bool loading = true;
  bool sending = false;
  String query = '';

  final selectedCodes = <String>{};
  List<_Recipient> recipients = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final strings = ref.read(stringsProvider);
      final api = DoodlApi.shared;
      final profileId = widget.onboarding.profileId;
      final pairing = widget.onboarding.pairingCode;

      final results = <_Recipient>[];

      final threads = await api.listDirectChats(
          profileId: profileId, pairingCode: pairing, limit: 60);
      for (final row in threads) {
        final thread = DirectChatThread.fromMap(row);
        if (thread.code.isEmpty) continue;
        results.add(_Recipient(
            code: thread.code,
            title: '@${thread.otherUsername}',
            subtitle: strings.friend));
      }

      final groups = await api.listGroupsV2(
          profileId: profileId, pairingCode: pairing, limit: 60);
      for (final row in groups) {
        final g = GroupSummaryRow.fromMap(row);
        if (g.code.isEmpty) continue;
        final name = (g.displayName ?? '').trim();
        results.add(_Recipient(
            code: g.code,
            title: name.isEmpty ? g.code : name,
            subtitle: strings.group));
      }

      if (!mounted) return;
      setState(() => recipients = results);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Load failed: $e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<_Recipient> get filtered {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return recipients;
    return recipients.where((r) => r.title.toLowerCase().contains(q)).toList();
  }

  Future<void> _send() async {
    if (sending) return;
    if (selectedCodes.isEmpty) {
      final strings = ref.read(stringsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.pickAtLeastOneRecipient)));
      return;
    }
    setState(() => sending = true);
    try {
      final api = DoodlApi.shared;
      for (final code in selectedCodes) {
        await api.createDoodle(
          code: code,
          senderProfileId: widget.onboarding.profileId,
          senderPairingCode: widget.onboarding.pairingCode,
          contentBase64: widget.contentBase64,
        );
      }
      unawaited(WidgetService.setLatestFromDataUrl(widget.contentBase64,
          senderUsername: null));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Send failed: $e')));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.92,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(strings.sendTo,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900)),
                  const Spacer(),
                  IconButton(
                    onPressed: loading ? null : _load,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                decoration: InputDecoration(
                  hintText: strings.search,
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.04),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none),
                ),
                onChanged: (v) => setState(() => query = v),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final r = filtered[i];
                          final selected = selectedCodes.contains(r.code);
                          return InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () {
                              setState(() {
                                if (selected) {
                                  selectedCodes.remove(r.code);
                                } else {
                                  selectedCodes.add(r.code);
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.90),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: selected
                                      ? Colors.black.withOpacity(0.40)
                                      : Colors.black.withOpacity(0.08),
                                  width: selected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(r.title,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w900)),
                                        const SizedBox(height: 2),
                                        Text(r.subtitle,
                                            style: const TextStyle(
                                                color: Colors.black54,
                                                fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                  if (selected)
                                    const Icon(Icons.check_circle_rounded,
                                        color: Colors.black)
                                  else
                                    Icon(Icons.circle_outlined,
                                        color: Colors.black.withOpacity(0.28)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: const Color(0xFFFFFC00),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: sending ? null : _send,
                  child: Text(sending ? strings.sending : strings.send,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
