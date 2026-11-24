import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';
import 'app_semantic_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Material 3 light theme following DESIGN.md v2.0.0 (Modern Minimalist Editorial).
abstract final class AppTheme {
  static ThemeData get lightTheme {
    const colorScheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primaryTint,
      onPrimaryContainer: AppColors.onPrimaryTint,
      secondary: AppColors.primary,
      onSecondary: AppColors.onPrimary,
      secondaryContainer: AppColors.surfaceSoft,
      onSecondaryContainer: AppColors.textPrimary,
      surface: AppColors.bgCanvas,
      surfaceContainerLowest: AppColors.bgCanvas,
      surfaceContainerLow: AppColors.surfaceSoft,
      surfaceContainer: AppColors.surfaceSoft,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      error: AppColors.emergencyBg,
      onError: AppColors.emergencyFg,
      errorContainer: AppColors.dangerBg,
      onErrorContainer: AppColors.dangerFg,
      outline: AppColors.borderStrong,
      outlineVariant: AppColors.borderHairline,
    );

    final textTheme = AppTypography.buildTextTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.bgCanvas,
      canvasColor: AppColors.bgCanvas,
      textTheme: textTheme,
      extensions: const [LacakSemanticColors.light],
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bgCanvas,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: AppTypography.titleSection,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shadowColor: Colors.transparent,
        color: AppColors.surfaceBase,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          side: const BorderSide(color: AppColors.borderHairline, width: 1),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceSoft,
        selectedColor: AppColors.primary,
        disabledColor: AppColors.surfaceSoft,
        labelStyle: AppTypography.labelTag.copyWith(
          color: AppColors.chipInactiveText,
        ),
        secondaryLabelStyle: AppTypography.labelTag.copyWith(
          color: AppColors.onPrimary,
          fontWeight: FontWeight.w600,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
      dividerTheme: const DividerThemeData(
        thickness: 1,
        space: 1,
        color: AppColors.borderHairline,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceSoft,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 15,
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
        labelStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.textSecondary,
        ),
        floatingLabelStyle: AppTypography.labelTag.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
        errorStyle: AppTypography.captionLegal.copyWith(
          color: AppColors.dangerFg,
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
          borderSide: BorderSide.none,
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
          borderSide: const BorderSide(
            color: AppColors.borderFocus,
            width: 1.8,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
          borderSide: const BorderSide(color: AppColors.dangerFg, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
          borderSide: const BorderSide(color: AppColors.dangerFg, width: 1.8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(double.infinity, AppSpacing.primaryButtonMinHeight),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: 14,
            ),
          ),
          elevation: const WidgetStatePropertyAll(0),
          shadowColor: const WidgetStatePropertyAll(Colors.transparent),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return AppColors.surfaceSoft;
            }
            if (states.contains(WidgetState.pressed)) {
              return AppColors.primaryPressed;
            }
            return AppColors.primary;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return AppColors.textMuted;
            }
            return AppColors.onPrimary;
          }),
          textStyle: WidgetStatePropertyAll(AppTypography.labelButton),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
            ),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(AppSpacing.minTouchTarget, AppSpacing.secondaryButtonMinHeight),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: 14),
          ),
          elevation: const WidgetStatePropertyAll(0),
          shadowColor: const WidgetStatePropertyAll(Colors.transparent),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return AppColors.surfaceSoft;
            }
            if (states.contains(WidgetState.pressed)) {
              return AppColors.primaryPressed;
            }
            return AppColors.primary;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return AppColors.textMuted;
            }
            return AppColors.onPrimary;
          }),
          textStyle: WidgetStatePropertyAll(AppTypography.labelButton),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
            ),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(double.infinity, AppSpacing.secondaryButtonMinHeight),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: 14,
            ),
          ),
          elevation: const WidgetStatePropertyAll(0),
          shadowColor: const WidgetStatePropertyAll(Colors.transparent),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return AppColors.primaryTint;
            }
            return AppColors.surfaceBase;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return AppColors.textMuted;
            }
            return AppColors.primary;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return const BorderSide(
                color: AppColors.borderHairline,
                width: 1,
              );
            }
            return const BorderSide(color: AppColors.borderStrong, width: 1.2);
          }),
          textStyle: WidgetStatePropertyAll(AppTypography.labelButton),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
            ),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(
            AppSpacing.minTouchTarget,
            AppSpacing.minTouchTarget,
          ),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(
            AppSpacing.minTouchTarget,
            AppSpacing.minTouchTarget,
          ),
          foregroundColor: AppColors.primary,
          tapTargetSize: MaterialTapTargetSize.padded,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: AppSpacing.navBarHeight,
        elevation: 0,
        backgroundColor: AppColors.surfaceBase,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primaryTint,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(
              color: AppColors.onPrimaryTint,
              size: 24,
            );
          }
          return const IconThemeData(color: AppColors.textSecondary, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTypography.labelTag.copyWith(
              color: AppColors.onPrimaryTint,
              fontWeight: FontWeight.w600,
            );
          }
          return AppTypography.labelTag.copyWith(color: AppColors.textSecondary);
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        elevation: 0,
        backgroundColor: AppColors.surfaceBase,
        indicatorColor: AppColors.primaryTint,
        labelType: NavigationRailLabelType.all,
        selectedIconTheme: const IconThemeData(
          color: AppColors.onPrimaryTint,
          size: 24,
        ),
        unselectedIconTheme: const IconThemeData(
          color: AppColors.textSecondary,
          size: 24,
        ),
        selectedLabelTextStyle: AppTypography.labelTag.copyWith(
          color: AppColors.onPrimaryTint,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: AppTypography.labelTag.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        elevation: 0,
        backgroundColor: AppColors.surfaceBase,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusHero),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: AppColors.surfaceBase,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSurface),
          side: const BorderSide(color: AppColors.borderHairline, width: 1),
        ),
        titleTextStyle: AppTypography.titleSection,
        contentTextStyle: AppTypography.bodyLarge,
      ),
      snackBarTheme: SnackBarThemeData(
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.surfaceBase,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
        ),
      ),
    );
  }
}
