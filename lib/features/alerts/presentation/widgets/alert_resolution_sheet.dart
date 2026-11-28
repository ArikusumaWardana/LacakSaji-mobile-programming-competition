import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/lacak_buttons.dart';
import '../../../../core/widgets/lacak_status_badge.dart';
import '../../../../core/widgets/lacak_text_field.dart';
import '../../domain/cluster_alert_models.dart';
import '../cluster_alert_controller.dart';

/// Verified 2-step resolution modal allowing Admin SPPG or Reporter School
/// to transition an active cluster alert to `clarified_safe` or `confirmed_klb`.
class AlertResolutionSheet extends ConsumerStatefulWidget {
  const AlertResolutionSheet({
    super.key,
    required this.alert,
    required this.verifierName,
  });

  final ClusterAlertEvent alert;
  final String verifierName;

  @override
  ConsumerState<AlertResolutionSheet> createState() =>
      _AlertResolutionSheetState();
}

class _AlertResolutionSheetState extends ConsumerState<AlertResolutionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  AlertResolutionStatus _selectedStatus = AlertResolutionStatus.clarifiedSafe;
  int _step = 1;
  bool _auditConfirmed = false;
  bool _submitting = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.alert.resolutionStatus.canTransitionTo(
      AlertResolutionStatus.clarifiedSafe,
    )
        ? AlertResolutionStatus.clarifiedSafe
        : AlertResolutionStatus.confirmedKlb;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _advanceToConfirmation() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _step = 2;
      _errorText = null;
    });
  }

  Future<void> _submitResolution() async {
    if (!_auditConfirmed || _submitting) {
      return;
    }
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    try {
      final updated = await ref
          .read(clusterAlertControllerProvider.notifier)
          .resolveAlertStatus(
            alert: widget.alert,
            newStatus: _selectedStatus,
            resolutionNote: _reasonController.text.trim(),
          );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(updated);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _errorText = error.toString().replaceFirst('FormatException: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final isClarifiedSafe =
        _selectedStatus == AlertResolutionStatus.clarifiedSafe;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg + viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Langkah $_step dari 2 · Verifikasi Audit',
                            style: AppTypography.captionMuted,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Klarifikasi / Status Darurat',
                            style: AppTypography.titleSection,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      tooltip: 'Tutup',
                      constraints: const BoxConstraints(
                        minWidth: AppSpacing.minTouchTarget,
                        minHeight: AppSpacing.minTouchTarget,
                      ),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (_step == 1) ...[
                  if (widget.alert.resolutionStatus.canTransitionTo(
                    AlertResolutionStatus.clarifiedSafe,
                  )) ...[
                    _ResolutionOptionTile(
                      selected: isClarifiedSafe,
                      level: LacakStatusLevel.safe,
                      title: 'Klarifikasi: Aman Kembali',
                      subtitle:
                          'Gunakan bila kendala terlokalisir (misalnya 1 wadah jatuh saat transit) dan batch utama aman dikonsumsi.',
                      onTap: () => setState(
                        () => _selectedStatus =
                            AlertResolutionStatus.clarifiedSafe,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  _ResolutionOptionTile(
                    selected: !isClarifiedSafe,
                    level: LacakStatusLevel.danger,
                    title: 'Terkonfirmasi KLB',
                    subtitle:
                        'Tetapkan seluruh batch tidak layak dan wajib tindak lanjut penuh Puskesmas / Dinkes.',
                    onTap: () => setState(
                      () => _selectedStatus = AlertResolutionStatus.confirmedKlb,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  LacakTextField(
                    label: 'Alasan Terverifikasi (Wajib, min 10 karakter)',
                    controller: _reasonController,
                    hintText:
                        'Contoh: Hanya 1 ompreng tumpah saat bongkar muat, sampel lain segar dan aman.',
                    maxLines: 3,
                    validator: (value) {
                      final clean = (value ?? '').trim();
                      if (clean.length < 10) {
                        return 'Tuliskan alasan lengkap minimal 10 karakter untuk jejak audit.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  LacakPrimaryButton(
                    label: 'Lanjut ke Konfirmasi Akhir',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: _advanceToConfirmation,
                  ),
                ] else ...[
                  LacakStatusBanner(
                    level: isClarifiedSafe
                        ? LacakStatusLevel.safe
                        : LacakStatusLevel.danger,
                    title: isClarifiedSafe
                        ? 'Konfirmasi Status: Aman Kembali'
                        : 'Konfirmasi Status: Terkonfirmasi KLB',
                    description:
                        'Perubahan status akan disiarkan seketika ke seluruh sekolah mitra dan dicatat permanen di log audit.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusSurface,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pejabat Pemverifikasi', style: AppTypography.captionMuted),
                        const SizedBox(height: 2),
                        Text(widget.verifierName, style: AppTypography.titleItem),
                        const SizedBox(height: AppSpacing.sm),
                        Text('Alasan Resmi', style: AppTypography.captionMuted),
                        const SizedBox(height: 2),
                        Text(
                          _reasonController.text.trim(),
                          style: AppTypography.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.primary,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      'Saya menyatakan verifikasi lapangan telah dilakukan dan tercatat pada log audit.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    value: _auditConfirmed,
                    onChanged: _submitting
                        ? null
                        : (v) => setState(() => _auditConfirmed = v ?? false),
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _errorText!,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.dangerFg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  if (isClarifiedSafe)
                    LacakPrimaryButton(
                      label: 'Konfirmasi & Siarkan Pembaruan',
                      icon: Icons.verified_user_rounded,
                      isLoading: _submitting,
                      onPressed: _auditConfirmed ? _submitResolution : null,
                    )
                  else
                    LacakDangerButton(
                      label: 'Konfirmasi Status KLB',
                      icon: Icons.notification_important_rounded,
                      isLoading: _submitting,
                      onPressed: _auditConfirmed ? _submitResolution : null,
                    ),
                  const SizedBox(height: AppSpacing.xs),
                  LacakSecondaryButton(
                    label: 'Ubah Alasan',
                    onPressed: _submitting
                        ? null
                        : () => setState(() => _step = 1),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResolutionOptionTile extends StatelessWidget {
  const _ResolutionOptionTile({
    required this.selected,
    required this.level,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final LacakStatusLevel level;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeBorder = level == LacakStatusLevel.safe
        ? AppColors.primary
        : AppColors.dangerFg;
    final activeBg = level == LacakStatusLevel.safe
        ? AppColors.safeBg
        : AppColors.dangerBg;

    return Semantics(
      button: true,
      selected: selected,
      label: title,
      child: Material(
        color: selected ? activeBg : AppColors.surfaceSoft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSurface),
          side: selected
              ? BorderSide(color: activeBorder, width: 1.8)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSurface),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.titleItem.copyWith(
                    color: selected ? activeBorder : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTypography.bodyMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
