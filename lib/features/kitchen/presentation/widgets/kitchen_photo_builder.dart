import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../kitchen_providers.dart';

/// Pure presentation helper resolving a local file or signed Supabase batch photo
/// into an [ImageProvider] without altering providers or repositories.
class KitchenBatchPhotoBuilder extends ConsumerStatefulWidget {
  const KitchenBatchPhotoBuilder({
    super.key,
    required this.localPhotoPath,
    required this.storagePath,
    required this.builder,
  });

  final String? localPhotoPath;
  final String? storagePath;
  final Widget Function(BuildContext context, ImageProvider? imageProvider)
      builder;

  @override
  ConsumerState<KitchenBatchPhotoBuilder> createState() =>
      _KitchenBatchPhotoBuilderState();
}

class _KitchenBatchPhotoBuilderState
    extends ConsumerState<KitchenBatchPhotoBuilder> {
  Future<String?>? _signedUrlFuture;
  String? _resolvedStoragePath;

  @override
  void initState() {
    super.initState();
    _syncSignedUrlFuture();
  }

  @override
  void didUpdateWidget(covariant KitchenBatchPhotoBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storagePath != widget.storagePath ||
        oldWidget.localPhotoPath != widget.localPhotoPath) {
      _syncSignedUrlFuture();
    }
  }

  void _syncSignedUrlFuture() {
    final local = widget.localPhotoPath;
    if (local != null && local.isNotEmpty && File(local).existsSync()) {
      _resolvedStoragePath = null;
      _signedUrlFuture = null;
      return;
    }
    final storage = widget.storagePath;
    if (storage == null || storage.isEmpty) {
      _resolvedStoragePath = null;
      _signedUrlFuture = null;
      return;
    }
    if (_resolvedStoragePath != storage || _signedUrlFuture == null) {
      _resolvedStoragePath = storage;
      _signedUrlFuture =
          ref.read(kitchenRepositoryProvider).createSignedPhotoUrl(storage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final local = widget.localPhotoPath;
    if (local != null && local.isNotEmpty && File(local).existsSync()) {
      return widget.builder(context, FileImage(File(local)));
    }
    final future = _signedUrlFuture;
    if (future == null) {
      return widget.builder(context, null);
    }
    return FutureBuilder<String?>(
      future: future,
      builder: (context, snapshot) {
        final url = snapshot.data;
        final provider = (url != null && url.isNotEmpty)
            ? NetworkImage(url)
            : null;
        return widget.builder(context, provider);
      },
    );
  }
}
