import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'package:kaascan/components/soma_robot.dart';
import 'package:kaascan/provider/values_provider.dart';

/// The two Soma engines a parent can pick. Values match the backend's
/// `engine` field on POST /ask.
enum SomaEngine { big, nano }

extension SomaEngineInfo on SomaEngine {
  String get label => this == SomaEngine.big ? 'Big Soma' : 'Nano Soma';
  String get blurb => this == SomaEngine.big
      ? 'Smartest. Reads files and photos, handles long questions.'
      : 'Fastest. Quick answers for simple questions, no files.';
  SomaRobotColor get robotColor =>
      this == SomaEngine.big ? SomaRobotColor.orange : SomaRobotColor.green;
}

/// The engine's own Soma robot: orange for Big, green for Nano.
class _EngineRobot extends StatelessWidget {
  const _EngineRobot(this.engine, {required this.size});

  final SomaEngine engine;
  final double size;

  @override
  Widget build(BuildContext context) {
    // The robot fills under half of its animation canvas.
    final canvas = size * 2.3;
    return IgnorePointer(
      child: SizedBox(
        width: size,
        height: size,
        child: OverflowBox(
          maxWidth: canvas,
          maxHeight: canvas,
          child: SomaRobot(
            size: canvas,
            floating: false,
            color: engine.robotColor,
          ),
        ),
      ),
    );
  }
}

const _kadiBlue = Color(0xFF0019CD);
const _ink = Color(0xFF11142D);
const _maxAttachments = 3;
const _maxBytes = 5 * 1024 * 1024;

/// Camera, Photos and Files in the "+" menu. Off until the backend's
/// attachment reading is ready; they show as "Soon" meanwhile.
const _attachmentsEnabled = false;

/// Soma Report (scan a report card) in the "+" menu. Shows as "Soon" while off.
const _somaReportEnabled = false;

class SomaChatInput extends StatelessWidget {
  const SomaChatInput({
    super.key,
    required this.controller,
    required this.attachments,
    required this.onAttach,
    required this.onRemoveAttachment,
    required this.engine,
    required this.onEngineChanged,
    required this.waiting,
    required this.onSend,
    required this.onScan,
    this.onChanged,
  });

  final TextEditingController controller;
  final List<ChatAttachment> attachments;
  final ValueChanged<ChatAttachment> onAttach;
  final ValueChanged<int> onRemoveAttachment;
  final SomaEngine engine;
  final ValueChanged<SomaEngine> onEngineChanged;
  final bool waiting;
  final VoidCallback onSend;
  final VoidCallback onScan;
  final ValueChanged<String>? onChanged;

  bool get _canSend =>
      !waiting &&
      (controller.text.trim().isNotEmpty || attachments.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (attachments.isNotEmpty) ...[
            _AttachmentStrip(
              attachments: attachments,
              onRemove: onRemoveAttachment,
            ),
            if (engine == SomaEngine.nano)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Nano Soma can\'t read files. Switch to Big Soma to use them.',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFFB45309),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            const SizedBox(height: 6),
          ],
          TextField(
            controller: controller,
            minLines: 1,
            maxLines: 5,
            cursorColor: _kadiBlue,
            textCapitalization: TextCapitalization.sentences,
            onChanged: onChanged,
            style: GoogleFonts.outfit(color: _ink, fontSize: 16),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Ask me anything about your kids…',
              hintStyle: GoogleFonts.outfit(
                color: _ink.withValues(alpha: 0.4),
                fontSize: 16,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _RoundButton(
                icon: Icons.add_rounded,
                tooltip: 'Add files or photos',
                onTap: () => _openAddMenu(context),
              ),
              const SizedBox(width: 8),
              _EngineMenu(engine: engine, onChanged: onEngineChanged),
              const Spacer(),
              _SendButton(
                enabled: _canSend,
                waiting: waiting,
                onTap: onSend,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── adding files ──────────────────────────────────────────────────────────

  void _openAddMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheet) {
        Widget badge(String text, Color color) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                text,
                style: GoogleFonts.outfit(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            );

        // Not available yet: shown greyed out so parents know it's coming.
        Widget soon(IconData icon, String label, String sub, VoidCallback go) {
          if (_attachmentsEnabled) {
            return ListTile(
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _kadiBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: _kadiBlue),
              ),
              title: Text(label,
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600, color: _ink)),
              subtitle: Text(sub,
                  style: GoogleFonts.outfit(
                      fontSize: 12, color: _ink.withValues(alpha: 0.55))),
              onTap: () {
                Navigator.pop(sheet);
                go();
              },
            );
          }
          return Opacity(
            opacity: 0.45,
            child: ListTile(
              enabled: false,
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _ink.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: _ink.withValues(alpha: 0.6)),
              ),
              title: Row(
                children: [
                  Text(label,
                      style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600, color: _ink)),
                  const SizedBox(width: 8),
                  badge('SOON', _ink),
                ],
              ),
              subtitle: Text(sub,
                  style: GoogleFonts.outfit(
                      fontSize: 12, color: _ink.withValues(alpha: 0.55))),
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(
                  opacity: _somaReportEnabled ? 1 : 0.45,
                  child: ListTile(
                    enabled: _somaReportEnabled,
                    leading: Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: somaBrandOrange.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const _EngineRobot(SomaEngine.big, size: 34),
                    ),
                    title: Row(
                      children: [
                        Text('Soma Report',
                            style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w600, color: _ink)),
                        const SizedBox(width: 8),
                        _somaReportEnabled
                            ? badge('BETA', somaBrandOrange)
                            : badge('SOON', _ink),
                      ],
                    ),
                    subtitle: Text('Scan a school report card',
                        style: GoogleFonts.outfit(
                            fontSize: 12, color: _ink.withValues(alpha: 0.55))),
                    onTap: () {
                      Navigator.pop(sheet);
                      onScan();
                    },
                  ),
                ),
                const Divider(height: 16, indent: 20, endIndent: 20),
                soon(Icons.photo_camera_rounded, 'Camera',
                    'Take a photo of a receipt or report',
                    () => _pickImage(ImageSource.camera)),
                soon(Icons.photo_library_rounded, 'Photos',
                    'Choose an image from your gallery',
                    () => _pickImage(ImageSource.gallery)),
                soon(Icons.attach_file_rounded, 'Files',
                    'PDF, text or CSV, up to 5 MB', _pickFile),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _hasRoom() {
    if (attachments.length < _maxAttachments) return true;
    Fluttertoast.showToast(msg: 'You can attach up to $_maxAttachments files');
    return false;
  }

  void _accept(String name, String mime, Uint8List bytes) {
    if (bytes.length > _maxBytes) {
      Fluttertoast.showToast(msg: '$name is larger than 5 MB');
      return;
    }
    onAttach(ChatAttachment(name: name, mime: mime, bytes: bytes));
  }

  Future<void> _pickImage(ImageSource source) async {
    if (!_hasRoom()) return;
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 75,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      _accept(file.name, _mimeFor(file.name, file.mimeType), bytes);
    } catch (e) {
      Fluttertoast.showToast(msg: 'Could not open the photo');
    }
  }

  Future<void> _pickFile() async {
    if (!_hasRoom()) return;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'txt', 'csv', 'jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );
      final file = result?.files.single;
      final bytes = file?.bytes;
      if (file == null || bytes == null) return;
      _accept(file.name, _mimeFor(file.name, null), bytes);
    } catch (e) {
      Fluttertoast.showToast(msg: 'Could not open the file');
    }
  }

  static String _mimeFor(String name, String? reported) {
    if (reported != null && reported.isNotEmpty) return reported;
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'jpg' || 'jpeg' => 'image/jpeg',
      'pdf' => 'application/pdf',
      'csv' => 'text/csv',
      _ => 'text/plain',
    };
  }
}

// ── pieces ──────────────────────────────────────────────────────────────────

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: _kadiBlue.withValues(alpha: 0.08),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, color: _kadiBlue, size: 24),
          ),
        ),
      ),
    );
  }
}

/// The model picker: a compact pill that opens a dropdown card anchored to it.
class _EngineMenu extends StatefulWidget {
  const _EngineMenu({required this.engine, required this.onChanged});

  final SomaEngine engine;
  final ValueChanged<SomaEngine> onChanged;

  @override
  State<_EngineMenu> createState() => _EngineMenuState();
}

class _EngineMenuState extends State<_EngineMenu> {
  final _controller = MenuController();
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      controller: _controller,
      alignmentOffset: const Offset(0, 8),
      onOpen: () => setState(() => _open = true),
      onClose: () => setState(() => _open = false),
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(Colors.white),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.white),
        elevation: const WidgetStatePropertyAll(10),
        shadowColor:
            WidgetStatePropertyAll(Colors.black.withValues(alpha: 0.18)),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
      menuChildren: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          child: Text(
            'MODEL',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
              color: _ink.withValues(alpha: 0.45),
            ),
          ),
        ),
        for (final e in SomaEngine.values)
          _EngineOption(
            engine: e,
            selected: e == widget.engine,
            onTap: () {
              _controller.close();
              if (e != widget.engine) widget.onChanged(e);
            },
          ),
      ],
      builder: (context, controller, _) => Semantics(
        button: true,
        label: 'Model: ${widget.engine.label}',
        child: Material(
          color: _open
              ? _kadiBlue.withValues(alpha: 0.12)
              : _kadiBlue.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => controller.isOpen ? controller.close() : controller.open(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(11, 8, 7, 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _EngineRobot(widget.engine, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    widget.engine.label,
                    style: GoogleFonts.outfit(
                      color: _ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 2),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more_rounded,
                      color: _ink.withValues(alpha: 0.5),
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EngineOption extends StatelessWidget {
  const _EngineOption({
    required this.engine,
    required this.selected,
    required this.onTap,
  });

  final SomaEngine engine;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tag = engine == SomaEngine.big ? 'Smart' : 'Fast';
    return Semantics(
      button: true,
      selected: selected,
      label: '${engine.label}. ${engine.blurb}',
      child: Material(
        color: selected ? _kadiBlue.withValues(alpha: 0.06) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 280,
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: engine.robotColor.inner
                        .withValues(alpha: selected ? 0.16 : 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? engine.robotColor.inner
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: _EngineRobot(engine, size: 32),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            engine.label,
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: _ink.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              tag,
                              style: GoogleFonts.outfit(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: _ink.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        engine.blurb,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          height: 1.3,
                          color: _ink.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedOpacity(
                  opacity: selected ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: const Icon(Icons.check_rounded,
                      color: _kadiBlue, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.enabled,
    required this.waiting,
    required this.onTap,
  });

  final bool enabled;
  final bool waiting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Send',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: enabled || waiting ? _kadiBlue : _ink.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: Center(
              child: waiting
                  ? const _ThinkingDots()
                  : const Icon(Icons.arrow_upward_rounded,
                      color: Colors.white, size: 24),
            ),
          ),
        ),
      ),
    );
  }
}

/// Three dots that brighten one after another: Soma is thinking.
class _ThinkingDots extends StatefulWidget {
  const _ThinkingDots();

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Soma is thinking',
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 3),
              _dot(i),
            ],
          ],
        ),
      ),
    );
  }

  Widget _dot(int i) {
    // Each dot peaks a third of a cycle after the one before it.
    final phase = (_c.value - i / 3) % 1.0;
    final wave = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
    final t = Curves.easeInOut.transform(wave);
    return Transform.translate(
      offset: Offset(0, -2.5 * t),
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.3 + 0.7 * t),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _AttachmentStrip extends StatelessWidget {
  const _AttachmentStrip({required this.attachments, required this.onRemove});

  final List<ChatAttachment> attachments;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: attachments.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final a = attachments[i];
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6, right: 6),
                child: AttachmentPreview(attachment: a, size: 56),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => onRemove(i),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: _ink,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 13),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A square thumbnail for a photo, or a file tile with its type and name.
class AttachmentPreview extends StatelessWidget {
  const AttachmentPreview({
    super.key,
    required this.attachment,
    this.size = 56,
  });

  final ChatAttachment attachment;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (attachment.isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          attachment.bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      );
    }
    final ext = attachment.name.contains('.')
        ? attachment.name.split('.').last.toUpperCase()
        : 'FILE';
    return Container(
      width: size * 2.4,
      height: size,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _kadiBlue.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            ext == 'PDF'
                ? Icons.picture_as_pdf_rounded
                : Icons.description_rounded,
            color: _kadiBlue,
            size: 22,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _ink),
                ),
                Text(
                  ext,
                  style: GoogleFonts.outfit(
                      fontSize: 11, color: _ink.withValues(alpha: 0.5)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
