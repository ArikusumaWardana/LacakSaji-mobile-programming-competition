import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../features/auth/domain/auth_models.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Floating confirmation notification shown above routes after login or logout.
/// Positioned cleanly below the AppBar band so AppBar actions and bottom navigation remain unobstructed.
class LacakFloatingAuthNotice extends StatefulWidget {
  const LacakFloatingAuthNotice({
    super.key,
    required this.notice,
    required this.onDismiss,
    this.autoHideDuration = const Duration(seconds: 4),
  });

  final AuthFeedbackNotice? notice;
  final VoidCallback onDismiss;
  final Duration autoHideDuration;

  @override
  State<LacakFloatingAuthNotice> createState() =>
      _LacakFloatingAuthNoticeState();
}

class _LacakFloatingAuthNoticeState extends State<LacakFloatingAuthNotice> {
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _syncTimer(null, widget.notice);
  }

  @override
  void didUpdateWidget(covariant LacakFloatingAuthNotice oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTimer(oldWidget.notice, widget.notice);
  }

  void _syncTimer(AuthFeedbackNotice? previous, AuthFeedbackNotice? current) {
    if (current == null) {
      _dismissTimer?.cancel();
      _dismissTimer = null;
      return;
    }
    if (previous?.id == current.id) {
      return;
    }
    _dismissTimer?.cancel();
    _dismissTimer = Timer(widget.autoHideDuration, () {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notice = widget.notice;
    if (notice == null) {
      return const SizedBox.shrink();
    }

    final width = MediaQuery.sizeOf(context).width;
    final horizontalPad = AppSpacing.horizontalPadding(width);
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 220);

    final isLogin = notice.type == AuthFeedbackType.loggedIn;
    final bgColor = isLogin ? AppColors.safeBg : AppColors.infoBg;
    final accentColor = isLogin ? AppColors.safeFg : AppColors.infoFg;
    final iconData = isLogin ? Icons.check_circle_rounded : Icons.logout_rounded;
    final bottomOffset = width < 600 ? 92.0 : AppSpacing.lg;

    return Positioned(
      top: isLogin ? null : 0,
      bottom: isLogin ? 0 : null,
      left: 0,
      right: 0,
      child: SafeArea(
        top: !isLogin,
        bottom: isLogin,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPad,
            isLogin ? 0 : AppSpacing.md,
            horizontalPad,
            isLogin ? bottomOffset : 0,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSpacing.largePhoneFormMaxWidth,
              ),
              child: TapRegion(
                onTapOutside: (_) => widget.onDismiss(),
                child: Semantics(
                  liveRegion: true,
                  container: true,
                  explicitChildNodes: true,
                  label: '${notice.title}. ${notice.message}',
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey<int>(notice.id),
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      final yOffset = (isLogin ? 12.0 : -12.0) * (1 - value);
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, yOffset),
                          child: child,
                        ),
                      );
                    },
                    child: Material(
                      color: bgColor,
                      elevation: 2,
                      shadowColor: const Color(0x1F181E1B),
                      surfaceTintColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSurface,
                        ),
                        side: BorderSide(color: accentColor, width: 1.5),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.sm,
                          AppSpacing.xs,
                          AppSpacing.sm,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(iconData, size: 22, color: accentColor),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    notice.title,
                                    style: AppTypography.titleItem.copyWith(
                                      color: accentColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    notice.message,
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Semantics(
                              button: true,
                              label: 'Tutup notifikasi',
                              child: Material(
                                type: MaterialType.transparency,
                                child: InkWell(
                                  key: const ValueKey<String>(
                                    'auth_feedback_close_button',
                                  ),
                                  onTap: widget.onDismiss,
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.minTouchTarget / 2,
                                  ),
                                  child: SizedBox(
                                    width: AppSpacing.minTouchTarget,
                                    height: AppSpacing.minTouchTarget,
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 20,
                                      color: accentColor,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
