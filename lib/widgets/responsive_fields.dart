import 'package:flutter/material.dart';

/// Affiche deux champs côte à côte lorsque l'espace le permet et les empile
/// automatiquement sur les petits écrans.
class ResponsiveFields extends StatelessWidget {
  const ResponsiveFields({
    super.key,
    required this.first,
    required this.second,
    this.breakpoint = 520,
    this.spacing = 12,
  });

  final Widget first;
  final Widget second;
  final double breakpoint;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [first, SizedBox(height: spacing), second],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            SizedBox(width: spacing),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}
