import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Flat 1dp-bordered white surface container preventing nested card-soup.
class LacakSectionSurface extends StatelessWidget {
  const LacakSectionSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.backgroundColor = AppColors.surfaceBase,
  });

  /// Builds a grouped list separated by 1dp dividers inside one outer surface.
  factory LacakSectionSurface.separated({
    Key? key,
    required List<Widget> children,
    Color backgroundColor = AppColors.surfaceBase,
  }) {
    final spacedChildren = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      spacedChildren.add(children[i]);
      if (i < children.length - 1) {
        spacedChildren.add(const Divider(height: 1, thickness: 1));
      }
    }
    return LacakSectionSurface(
      key: key,
      padding: EdgeInsets.zero,
      backgroundColor: backgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: spacedChildren,
      ),
    );
  }

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSurface),
        side: const BorderSide(color: AppColors.borderHairline, width: 1),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
