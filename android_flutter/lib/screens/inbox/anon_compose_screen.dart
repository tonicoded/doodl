import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scribble/scribble.dart';

import '../../i18n/strings_provider.dart';
import '../../models/onboarding.dart';
import '../../services/doodl_api.dart';
import '../../utils/data_url.dart';
import '../../widget/widget_service.dart';
import '../../widgets/doodle_tools.dart';
import '../../widgets/doodl_logo.dart';

class AnonComposeScreen extends ConsumerStatefulWidget {
  const AnonComposeScreen({super.key, required this.onboarding});

  final OnboardingData onboarding;

  @override
  ConsumerState<AnonComposeScreen> createState() => _AnonComposeScreenState();
}

class _AnonComposeScreenState extends ConsumerState<AnonComposeScreen> {
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
        builder: (_) {
          final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
          return Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: _SendAnonDoodleSheet(
              onboarding: widget.onboarding,
              contentBase64: content,
            ),
          );
        },
      );

      if (sent == true) controller.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final size = MediaQuery.sizeOf(context);
    final canvasSize = (size.width - 36).clamp(260, 520).toDouble();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 160),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                    const Spacer(),
                    const DoodlLogo(height: 44),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  strings.lang == 'nl' ? 'stuur anoniem' : 'send anonymous',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900),
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
                        onTap: () => _openTools(context)),
                    _toolPill(
                      children: [
                        IconButton(
                            onPressed: () => controller.undo(),
                            icon: const Icon(Icons.undo_rounded)),
                        IconButton(
                            onPressed: () => controller.redo(),
                            icon: const Icon(Icons.redo_rounded)),
                        IconButton(
                            onPressed: () => controller.clear(),
                            icon: const Icon(Icons.delete_outline_rounded)),
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
        ),
      ),
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

class _AnonReceiver {
  const _AnonReceiver(
      {required this.profileId,
      required this.username,
      required this.avatarUrl});

  final String profileId;
  final String username;
  final String? avatarUrl;
}

class _SendAnonDoodleSheet extends ConsumerStatefulWidget {
  const _SendAnonDoodleSheet(
      {required this.onboarding, required this.contentBase64});

  final OnboardingData onboarding;
  final String contentBase64;

  @override
  ConsumerState<_SendAnonDoodleSheet> createState() =>
      _SendAnonDoodleSheetState();
}

class _SendAnonDoodleSheetState extends ConsumerState<_SendAnonDoodleSheet> {
  bool loading = false;
  bool sending = false;
  String query = '';
  List<_AnonReceiver> results = const [];
  _AnonReceiver? selected;

  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _search(String text) async {
    final q = text.trim();
    if (q.length < 2) {
      setState(() => results = const []);
      return;
    }
    setState(() => loading = true);
    try {
      final api = DoodlApi.shared;
      final rows = await api.searchAnonymousReceivers(
        requesterProfileId: widget.onboarding.profileId,
        requesterPairingCode: widget.onboarding.pairingCode,
        query: q,
        limit: 12,
      );
      final mapped = rows
          .map(
            (m) => _AnonReceiver(
              profileId: m['profile_id']?.toString() ?? '',
              username: m['username']?.toString() ?? '',
              avatarUrl: m['avatar_url']?.toString(),
            ),
          )
          .where((r) => r.profileId.isNotEmpty && r.username.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() => results = mapped);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Search failed: $e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _send() async {
    if (sending) return;
    final target = selected;
    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(ref.read(stringsProvider).pickAtLeastOneRecipient)),
      );
      return;
    }
    setState(() => sending = true);
    try {
      final api = DoodlApi.shared;
      await api.submitAnonymousDoodleToProfile(
        senderProfileId: widget.onboarding.profileId,
        senderPairingCode: widget.onboarding.pairingCode,
        recipientProfileId: target.profileId,
        contentBase64: widget.contentBase64,
      );
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
              Text(strings.sendTo,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              TextField(
                decoration: InputDecoration(
                  hintText: strings.searchUsername,
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.04),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none),
                ),
                onChanged: (v) {
                  setState(() => query = v);
                  _debounce?.cancel();
                  _debounce = Timer(
                      const Duration(milliseconds: 220), () => _search(v));
                },
              ),
              const SizedBox(height: 10),
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : results.isEmpty
                        ? Center(
                            child: Text(
                              query.trim().length >= 2
                                  ? (strings.lang == 'nl'
                                      ? 'geen users gevonden'
                                      : 'no users found')
                                  : strings.typeToSearch,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w700),
                            ),
                          )
                        : ListView.separated(
                            itemCount: results.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final r = results[i];
                              final isSelected =
                                  selected?.profileId == r.profileId;
                              return InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () => setState(() => selected = r),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.90),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.black.withOpacity(0.40)
                                          : Colors.black.withOpacity(0.08),
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor:
                                            Colors.black.withOpacity(0.06),
                                        backgroundImage: (r.avatarUrl != null &&
                                                r.avatarUrl!.trim().isNotEmpty)
                                            ? NetworkImage(r.avatarUrl!)
                                            : null,
                                        child: (r.avatarUrl == null ||
                                                r.avatarUrl!.trim().isEmpty)
                                            ? Text(
                                                r.username.isNotEmpty
                                                    ? r.username[0]
                                                        .toUpperCase()
                                                    : '?',
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    color: Colors.black))
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text('@${r.username}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w900)),
                                      ),
                                      if (isSelected)
                                        const Icon(Icons.check_circle_rounded,
                                            color: Colors.black)
                                      else
                                        Icon(Icons.circle_outlined,
                                            color:
                                                Colors.black.withOpacity(0.28)),
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
