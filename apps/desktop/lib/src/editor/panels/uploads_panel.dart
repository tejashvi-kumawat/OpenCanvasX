import 'package:document_model/document_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../providers.dart';
import '../../theme/ocx_theme.dart';
import '../editor_controller.dart';

/// Uploads (P1.6.1, P1.6.2): import PNG, JPEG, WebP, GIF, BMP or SVG files
/// from disk, and reuse images already in this design. Files are checked
/// (type from content, size caps, SVG sanitising) before they are added.
class UploadsPanel extends ConsumerStatefulWidget {
  const UploadsPanel({super.key});

  @override
  ConsumerState<UploadsPanel> createState() => _UploadsPanelState();
}

class _UploadsPanelState extends ConsumerState<UploadsPanel> {
  bool _busy = false;

  Future<void> _upload() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final files = await ref.read(imagePickerProvider)();
      final editor = ref.read(editorProvider.notifier);
      final rejected = <String>[];
      for (final file in files) {
        try {
          editor.insertImage(file.bytes, name: file.name);
        } on FormatException catch (e) {
          rejected.add('${file.name}: ${e.message}');
        }
      }
      if (rejected.isNotEmpty) {
        messenger.showSnackBar(
          SnackBar(content: Text('Not added — ${rejected.join(' · ')}')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(editorProvider);
    final media = ref.watch(mediaCacheProvider);
    final c = context.ocx;
    final images = [
      for (final MapEntry(key: hash, value: info)
          in session?.document.assets.entries ??
              const <MapEntry<String, AssetInfo>>[])
        if (info.mime.startsWith('image/') && info.licenseRef == null)
          if (media.bytesOf(hash) case final bytes?) (hash, info.mime, bytes),
    ];
    return ListView(
      padding: const EdgeInsets.only(bottom: Space.xl),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, 0),
          child: FilledButton.icon(
            onPressed: _busy ? null : _upload,
            icon:
                _busy
                    ? const SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.upload_outlined, size: Chrome.icon),
            label: const Text('Upload files'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(Space.md),
          child: Text(
            'PNG, JPEG, WebP, GIF, BMP or SVG, up to 50 MB. Files stay on '
            'this computer and are saved inside the design.',
            style: OcxText.caption(
              context,
            ).copyWith(color: c.textTertiary, fontWeight: FontWeight.w400),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.sm),
          child: Text('In this design', style: OcxText.bodyStrong(context)),
        ),
        if (images.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.md),
            child: Text(
              'Uploaded images appear here so you can reuse them.',
              style: OcxText.caption(
                context,
              ).copyWith(color: c.textTertiary, fontWeight: FontWeight.w400),
            ),
          )
        else
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: Space.md),
            mainAxisSpacing: Space.sm,
            crossAxisSpacing: Space.sm,
            children: [
              for (final (hash, mime, bytes) in images)
                Material(
                  key: ValueKey(hash),
                  color: c.surfaceSunken,
                  borderRadius: BorderRadius.circular(Radii.md),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap:
                        () => ref
                            .read(editorProvider.notifier)
                            .insertImage(bytes),
                    child: Padding(
                      padding: const EdgeInsets.all(Space.sm),
                      child:
                          mime == 'image/svg+xml'
                              ? SvgPicture.memory(bytes)
                              : Image.memory(
                                bytes,
                                fit: BoxFit.contain,
                                cacheWidth: 240,
                              ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
