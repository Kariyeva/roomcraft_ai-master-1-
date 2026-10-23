import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

class StudioPanel extends StatelessWidget {
  const StudioPanel({
    super.key,
    required this.child,
    this.glass = false,
    this.padding = const EdgeInsets.all(24),
  });
  final Widget child;
  final bool glass;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) {
    final panel = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.paper.withValues(alpha: glass ? 0.82 : 1),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
    return glass
        ? ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: panel,
            ),
          )
        : panel;
  }
}

class StudioButton extends StatelessWidget {
  const StudioButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.secondary = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final bool secondary;
  @override
  Widget build(BuildContext context) {
    final child = busy
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label, textAlign: TextAlign.center);
    return secondary
        ? OutlinedButton(onPressed: busy ? null : onPressed, child: child)
        : FilledButton(onPressed: busy ? null : onPressed, child: child);
  }
}

class StudioField extends StatelessWidget {
  const StudioField({
    super.key,
    required this.label,
    required this.controller,
    this.validator,
    this.lines = 1,
    this.keyboardType,
    this.obscure = false,
    this.maxLength,
    this.autofillHints,
  });
  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final int lines;
  final TextInputType? keyboardType;
  final bool obscure;
  final int? maxLength;
  final Iterable<String>? autofillHints;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: TextFormField(
      controller: controller,
      validator: validator,
      maxLines: lines,
      obscureText: obscure,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: lines > 1,
      ),
    ),
  );
}

class StudioHeading extends StatelessWidget {
  const StudioHeading({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
  });
  final String eyebrow;
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(eyebrow, style: AppText.label),
      const SizedBox(height: 14),
      Text(
        title,
        style: AppText.heading.copyWith(
          fontSize: MediaQuery.sizeOf(context).width < 600 ? 30 : 42,
        ),
      ),
      if (subtitle != null) ...[
        const SizedBox(height: 16),
        Text(subtitle!, style: AppText.body),
      ],
    ],
  );
}

class StudioState extends StatelessWidget {
  const StudioState({
    super.key,
    required this.title,
    required this.message,
    this.action,
  });
  final String title;
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => StudioPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppText.heading.copyWith(fontSize: 26)),
        const SizedBox(height: 14),
        Text(message, style: AppText.body),
        if (action != null) ...[const SizedBox(height: 24), action!],
      ],
    ),
  );
}

class AuthFrame extends StatelessWidget {
  const AuthFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title;
  final String subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('ROOMCRAFT / AI'),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false),
          child: const Text('На сайт ↗'),
        ),
      ],
    ),
    body: LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final form = Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: StudioPanel(
              glass: true,
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StudioHeading(
                    eyebrow: 'ВАШЕ РАБОЧЕЕ ПРОСТРАНСТВО',
                    title: title,
                    subtitle: subtitle,
                  ),
                  const SizedBox(height: 32),
                  child,
                ],
              ),
            ),
          ),
        );
        return SingleChildScrollView(
          padding: EdgeInsets.all(wide ? 48 : 16),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.sand, AppColors.ivory, Color(0xFFE8DAD3)],
              ),
            ),
            padding: EdgeInsets.all(wide ? 36 : 8),
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(220),
                            bottom: Radius.circular(16),
                          ),
                          child: Stack(
                            children: [
                              Image.asset(
                                'assets/images/concept-stone.jpg',
                                height: 660,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                cacheWidth: 900,
                              ),
                              const Positioned(
                                left: 28,
                                bottom: 32,
                                right: 28,
                                child: StudioPanel(
                                  glass: true,
                                  child: Text(
                                    'Место для ваших\nследующих идей.',
                                    style: AppText.heading,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 40),
                      Expanded(child: form),
                    ],
                  )
                : form,
          ),
        );
      },
    ),
  );
}
