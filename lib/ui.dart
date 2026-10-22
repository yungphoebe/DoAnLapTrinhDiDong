import 'package:flutter/material.dart';

abstract final class GymColors {
  static const background = Color(0xFF111111);
  static const surface = Color(0xFF1E1E1E);
  static const border = Color(0xFF323232);
  static const purple = Color(0xFF983BFA);
  static const muted = Color(0xFF909094);
  static const green = Color(0xFF30D66A);
}

ThemeData gymTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: GymColors.background,
    colorScheme: const ColorScheme.dark(
      primary: GymColors.purple,
      onPrimary: Colors.white,
      surface: GymColors.surface,
      onSurface: Color(0xFFF4F4F5),
      outline: GymColors.border,
    ),
    textTheme: base.textTheme.apply(
      fontFamily: 'Roboto',
      bodyColor: const Color(0xFFF4F4F5),
      displayColor: const Color(0xFFF4F4F5),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: GymColors.background,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: GymColors.surface,
      hintStyle: const TextStyle(color: GymColors.muted, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      prefixIconColor: GymColors.muted,
      suffixIconColor: GymColors.muted,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: GymColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: GymColors.purple),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: GymColors.purple,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 52),
        textStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: GymColors.muted,
        side: const BorderSide(color: GymColors.border),
        minimumSize: const Size(0, 50),
      ),
    ),
    dividerTheme: const DividerThemeData(color: GymColors.border, thickness: 1),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Color(0xFF333036),
      contentTextStyle: TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: GymColors.surface,
      showDragHandle: true,
    ),
  );
}

class GymCard extends StatelessWidget {
  const GymCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color ?? GymColors.surface,
      border: Border.all(color: GymColors.border),
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(child: Text(label, textAlign: TextAlign.center)),
          if (icon != null) ...[
            const SizedBox(width: 10),
            Icon(icon, size: 18),
          ],
        ],
      ),
    ),
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            child: Text(action!, style: const TextStyle(fontSize: 12)),
          ),
      ],
    ),
  );
}

class CircleBackButton extends StatelessWidget {
  const CircleBackButton({super.key, this.onPressed});
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Quay lại',
    onPressed: onPressed ?? () => Navigator.maybePop(context),
    icon: Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: GymColors.surface,
        border: Border.all(color: GymColors.border),
      ),
      child: const Icon(Icons.chevron_left, size: 20),
    ),
  );
}

class ChoiceTile extends StatelessWidget {
  const ChoiceTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: selected ? const Color(0xFF30243E) : GymColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: selected ? GymColors.purple : GymColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 17,
                  color: selected ? GymColors.purple : GymColors.muted,
                ),
                const SizedBox(width: 7),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: selected ? Colors.white : GymColors.muted,
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

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
