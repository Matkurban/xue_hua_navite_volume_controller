import 'package:material_ui/material_ui.dart';

/// Shared outlined card shell used by every dashboard section.
///
/// Includes a bottom margin so that sections hidden on unsupported platforms
/// (returning `SizedBox.shrink()`) do not leave stray spacing behind.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(16),
    this.outlined = true,
  });

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: color,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: outlined
            ? BorderSide(color: colorScheme.outlineVariant)
            : BorderSide.none,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Bold section title used at the top of each [SectionCard].
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}
