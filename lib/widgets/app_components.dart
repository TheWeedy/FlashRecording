import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../theme/app_theme.dart';

class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = const Offset(0, 0.06),
  });

  final Widget child;
  final Duration delay;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppTheme.medium + delay,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final easedValue = value.clamp(0.0, 1.0);
        return Opacity(
          opacity: easedValue,
          child: Transform.translate(
            offset: offset * (1 - easedValue) * 120,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class PageIntro extends StatelessWidget {
  const PageIntro({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final String description;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return FadeSlideIn(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow.toUpperCase(),
                  style: theme.labelSmall?.copyWith(
                    color: AppTheme.copper,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  title,
                  style: theme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.ink,
                    height: 1.08,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: theme.bodyMedium?.copyWith(
                    color: AppTheme.muted,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

class AppPanel extends StatelessWidget {
  const AppPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = AppTheme.surface,
    this.borderColor = AppTheme.border,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: borderColor),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.accent = AppTheme.primary,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return AppPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 17, color: accent),
                const SizedBox(width: 7),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.labelMedium?.copyWith(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return AppPanel(
      color: AppTheme.raisedSurface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppTheme.primarySoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(icon, color: AppTheme.primary),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.bodyMedium?.copyWith(
              color: AppTheme.muted,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class ColorDot extends StatelessWidget {
  const ColorDot({super.key, required this.color, this.size = 12});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
    );
  }
}

class QuietIconButton extends StatelessWidget {
  const QuietIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color = AppTheme.primary,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      color: color,
      style: IconButton.styleFrom(
        backgroundColor: AppTheme.raisedSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusControl),
          side: const BorderSide(color: AppTheme.border),
        ),
      ),
    );
  }
}

class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.color = AppTheme.primary,
    this.icon,
    this.maxWidth,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
          ],
          if (maxWidth == null)
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
    final width = maxWidth;
    if (width == null) {
      return chip;
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width),
      child: chip,
    );
  }
}

class AiMarkdownBlock extends StatelessWidget {
  const AiMarkdownBlock({super.key, required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final bodyStyle = theme.bodyMedium?.copyWith(
      color: AppTheme.ink,
      height: 1.5,
      fontWeight: FontWeight.w500,
    );

    return MarkdownBody(
      data: data,
      selectable: true,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: bodyStyle,
        listBullet: bodyStyle?.copyWith(color: AppTheme.primary),
        strong: bodyStyle?.copyWith(fontWeight: FontWeight.w800),
        em: bodyStyle?.copyWith(fontStyle: FontStyle.italic),
        h1: theme.titleLarge?.copyWith(
          color: AppTheme.ink,
          fontWeight: FontWeight.w800,
          height: 1.25,
        ),
        h2: theme.titleMedium?.copyWith(
          color: AppTheme.ink,
          fontWeight: FontWeight.w800,
          height: 1.3,
        ),
        h3: theme.titleSmall?.copyWith(
          color: AppTheme.ink,
          fontWeight: FontWeight.w800,
          height: 1.35,
        ),
        blockquote: bodyStyle?.copyWith(color: AppTheme.muted),
        code: theme.bodyMedium?.copyWith(
          color: AppTheme.steel,
          backgroundColor: AppTheme.primarySoft,
          fontFamily: 'monospace',
        ),
        codeblockDecoration: BoxDecoration(
          color: AppTheme.primarySoft,
          borderRadius: BorderRadius.circular(AppTheme.radiusControl),
          border: Border.all(color: AppTheme.border),
        ),
        blockSpacing: 10,
        listIndent: 22,
      ),
    );
  }
}
