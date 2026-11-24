import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../auth/presentation/widgets/location_helper.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Expandable examination summary block matching editorial detail screens.
class ExpandableAuditSummary extends StatefulWidget {
  const ExpandableAuditSummary({
    super.key,
    this.title = 'Ringkasan Pemeriksaan',
    required this.text,
    this.collapsedMaxLines = 3,
    this.extraDetails,
  });

  final String title;
  final String text;
  final int collapsedMaxLines;
  final Widget? extraDetails;

  @override
  State<ExpandableAuditSummary> createState() => _ExpandableAuditSummaryState();
}

class _ExpandableAuditSummaryState extends State<ExpandableAuditSummary> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final canExpand = widget.text.length > 130 || widget.extraDetails != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.title, style: AppTypography.titleSection),
        const SizedBox(height: AppSpacing.sm),
        Text(
          widget.text,
          maxLines: _expanded ? null : widget.collapsedMaxLines,
          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: AppTypography.bodyLarge.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        if (_expanded && widget.extraDetails != null) ...[
          const SizedBox(height: AppSpacing.md),
          widget.extraDetails!,
        ],
        if (canExpand) ...[
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              style: TextButton.styleFrom(
                minimumSize: const Size(
                  AppSpacing.minTouchTarget,
                  AppSpacing.minTouchTarget,
                ),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                foregroundColor: AppColors.primary,
              ),
              child: Text(
                _expanded ? 'Ringkas' : 'Selengkapnya',
                style: AppTypography.labelTag.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Circular initial avatar + partner name/role + two square #234B3E action buttons (phone & WA).
class PartnerContactRow extends StatelessWidget {
  const PartnerContactRow({
    super.key,
    required this.name,
    this.roleLabel = 'Dapur SPPG Mitra',
    this.phoneOrWaNumber,
    this.copyFallbackCode,
    this.waPrefillMessage,
  });

  final String name;
  final String roleLabel;
  final String? phoneOrWaNumber;
  final String? copyFallbackCode;
  final String? waPrefillMessage;

  String _initials() {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList(growable: false);
    if (words.isEmpty) {
      return 'SP';
    }
    if (words.length == 1) {
      return words.first.substring(0, words.first.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }

  Future<void> _handleCall(BuildContext context) async {
    final digits = normalizeIndonesianWaNumber(phoneOrWaNumber ?? '');
    if (digits.isNotEmpty) {
      final uri = Uri(scheme: 'tel', path: digits);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (ok || !context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hubungi nomor terkait: +$digits')),
      );
      return;
    }
    final code = copyFallbackCode?.trim();
    if (code != null && code.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: code));
    }
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          code != null && code.isNotEmpty
              ? '$name (Kode Mitra $code disalin untuk koordinasi).'
              : 'Koordinasi langsung dengan $name.',
        ),
      ),
    );
  }

  Future<void> _handleWhatsApp(BuildContext context) async {
    final digits = normalizeIndonesianWaNumber(phoneOrWaNumber ?? '');
    final msg = waPrefillMessage ?? 'Halo $name, koordinasi pengiriman MBG.';
    final query = <String, String>{'text': msg};
    final uri = digits.isNotEmpty
        ? Uri.https('wa.me', '/$digits', query)
        : Uri.https('wa.me', '/', query);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      await Clipboard.setData(ClipboardData(text: msg));
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('WhatsApp tidak terbuka. Pesan koordinasi telah disalin.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.primaryTint,
          child: Text(
            _initials(),
            style: AppTypography.labelTag.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.titleItem.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                roleLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.captionMuted,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _ContactSquareButton(
          icon: Icons.call_rounded,
          tooltip: 'Telepon / Salin Kode Mitra',
          onTap: () => _handleCall(context),
        ),
        const SizedBox(width: AppSpacing.sm),
        _ContactSquareButton(
          icon: Icons.chat_rounded,
          tooltip: 'Koordinasi via WhatsApp',
          onTap: () => _handleWhatsApp(context),
        ),
      ],
    );
  }
}

class _ContactSquareButton extends StatelessWidget {
  const _ContactSquareButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
            child: SizedBox(
              width: AppSpacing.minTouchTarget,
              height: AppSpacing.minTouchTarget,
              child: Icon(icon, size: 20, color: AppColors.onPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

/// Slot descriptor inside [AuditEvidenceGallery].
class AuditGallerySlot {
  const AuditGallerySlot({
    required this.label,
    required this.fallbackIcon,
    this.image,
    this.active = false,
  });

  final String label;
  final IconData fallbackIcon;
  final ImageProvider? image;
  final bool active;
}

/// 4-column horizontal thumbnail row (10dp radius) with "+N" overflow overlay on the 4th tile.
class AuditEvidenceGallery extends StatelessWidget {
  const AuditEvidenceGallery({
    super.key,
    this.title = 'Galeri Bukti Audit',
    required this.slots,
  });

  final String title;
  final List<AuditGallerySlot> slots;

  void _openPreview(BuildContext context, AuditGallerySlot slot) {
    if (slot.image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${slot.label} siap pada tahap pemeriksaan ini.')),
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.surfaceBase,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusHero),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Image(image: slot.image!, fit: BoxFit.cover),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Text(slot.label, style: AppTypography.titleItem),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Tutup'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = slots.take(4).toList(growable: false);
    final overflowCount = slots.length > 4 ? slots.length - 3 : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: AppTypography.titleSection),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 10.0;
            final itemCount = visible.length;
            if (itemCount == 0) {
              return const SizedBox.shrink();
            }
            final tileSize =
                ((constraints.maxWidth - gap * (itemCount - 1)) / itemCount)
                    .clamp(56.0, 96.0);

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(itemCount, (index) {
                final slot = visible[index];
                final showPlus = index == 3 && overflowCount > 1;
                return _GalleryThumbBox(
                  size: tileSize,
                  slot: slot,
                  plusCount: showPlus ? overflowCount : 0,
                  onTap: () => _openPreview(context, slot),
                );
              }),
            );
          },
        ),
      ],
    );
  }
}

class _GalleryThumbBox extends StatelessWidget {
  const _GalleryThumbBox({
    required this.size,
    required this.slot,
    required this.plusCount,
    required this.onTap,
  });

  final double size;
  final AuditGallerySlot slot;
  final int plusCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bgColor = slot.active ? AppColors.primaryTint : AppColors.surfaceSoft;
    final fgColor = slot.active ? AppColors.primary : AppColors.textSecondary;

    return Semantics(
      button: true,
      label: slot.label,
      child: Material(
        color: bgColor,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (slot.image != null)
                  Image(
                    image: slot.image!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _GalleryFallback(
                      slot: slot,
                      fgColor: fgColor,
                    ),
                  )
                else
                  _GalleryFallback(slot: slot, fgColor: fgColor),
                if (plusCount > 0)
                  Container(
                    color: AppColors.scrimPill,
                    alignment: Alignment.center,
                    child: Text(
                      '+$plusCount',
                      style: AppTypography.tabular(
                        AppTypography.titleSection.copyWith(
                          color: AppColors.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GalleryFallback extends StatelessWidget {
  const _GalleryFallback({
    required this.slot,
    required this.fgColor,
  });

  final AuditGallerySlot slot;
  final Color fgColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(slot.fallbackIcon, size: 22, color: fgColor),
          const SizedBox(height: 4),
          Text(
            slot.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTypography.captionLegal.copyWith(
              color: fgColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
