import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../theme/app_theme.dart';

class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = AppTheme.motionOffset,
  });

  final Widget child;
  final Duration delay;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppTheme.medium + delay,
      curve: AppTheme.motionCurve,
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

Future<T?> showAppActionSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    isScrollControlled: isScrollControlled,
    sheetAnimationStyle: const AnimationStyle(
      duration: AppTheme.medium,
      reverseDuration: AppTheme.fast,
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: builder(sheetContext),
        ),
      );
    },
  );
}

class ContextualFabAction {
  const ContextualFabAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.label,
    this.backgroundColor,
    this.foregroundColor,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final String? label;
  final Color? backgroundColor;
  final Color? foregroundColor;
}

class PageFabConfig {
  const PageFabConfig({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.isDestructive = false,
    this.actions = const [],
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isDestructive;
  final List<ContextualFabAction> actions;

  String get visualSignature {
    return [
      tooltip,
      _iconSignature(icon),
      isDestructive,
      onPressed != null,
      for (final action in actions) _actionSignature(action),
    ].join('|');
  }
}

class PageFabController extends ChangeNotifier {
  final Map<int, PageFabConfig> _configs = {};
  int _currentPage = 0;

  PageFabConfig? get currentConfig => _configs[_currentPage];

  void setCurrentPage(int page) {
    if (_currentPage == page) {
      return;
    }
    _currentPage = page;
    notifyListeners();
  }

  void setConfig(int page, PageFabConfig config) {
    final previousSignature = _configs[page]?.visualSignature;
    _configs[page] = config;
    if (page == _currentPage && previousSignature != config.visualSignature) {
      notifyListeners();
    }
  }

  void clearConfig(int page) {
    final removed = _configs.remove(page);
    if (removed != null && page == _currentPage) {
      notifyListeners();
    }
  }
}

class PageFabHost extends StatelessWidget {
  const PageFabHost({super.key, required this.controller});

  final PageFabController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final config = controller.currentConfig;
        if (config == null) {
          return const SizedBox.shrink();
        }
        return ContextualActionFab(
          tooltip: config.tooltip,
          icon: config.icon,
          onPressed: config.onPressed,
          isDestructive: config.isDestructive,
          actions: config.actions,
        );
      },
    );
  }
}

class ContextualActionFab extends StatelessWidget {
  const ContextualActionFab({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.isDestructive = false,
    this.actions = const [],
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isDestructive;
  final List<ContextualFabAction> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 2, bottom: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          AnimatedSwitcher(
            duration: AppTheme.medium,
            switchInCurve: AppTheme.motionCurve,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: AppTheme.motionCurve,
                reverseCurve: Curves.easeInCubic,
              );
              return FadeTransition(
                opacity: curved,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.82, end: 1).animate(curved),
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.16),
                      end: Offset.zero,
                    ).animate(curved),
                    child: child,
                  ),
                ),
              );
            },
            child: Column(
              key: ValueKey(_actionsSignature(actions)),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  _ContextualSmallFab(
                    action: actions[i],
                    delay: Duration(milliseconds: 32 * i),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: AppTheme.medium,
            switchInCurve: AppTheme.motionCurve,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: AppTheme.motionCurve,
                reverseCurve: Curves.easeInCubic,
              );
              return FadeTransition(
                opacity: curved,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.72, end: 1).animate(curved),
                  child: RotationTransition(
                    turns: Tween<double>(begin: -0.08, end: 0).animate(curved),
                    child: child,
                  ),
                ),
              );
            },
            child: _ContextualMainFab(
              key: ValueKey(_mainFabSignature(icon, isDestructive, onPressed)),
              tooltip: tooltip,
              icon: icon,
              onPressed: onPressed,
              isDestructive: isDestructive,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContextualMainFab extends StatelessWidget {
  const _ContextualMainFab({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    required this.isDestructive,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'app-contextual-fab',
      tooltip: tooltip,
      onPressed: onPressed,
      backgroundColor: isDestructive ? AppTheme.danger : null,
      child: Icon(icon, size: 25),
    );
  }
}

class _ContextualSmallFab extends StatelessWidget {
  const _ContextualSmallFab({required this.action, required this.delay});

  final ContextualFabAction action;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return FadeSlideIn(
      delay: delay,
      offset: const Offset(0, 0.08),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (action.label != null) ...[
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                border: Border.all(color: AppTheme.border),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                child: Text(
                  action.label!,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusControl),
              ),
              onTap: action.onPressed,
              child: Tooltip(
                message: action.tooltip,
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: action.backgroundColor ?? AppTheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                    border: Border.all(
                      color: (action.foregroundColor ?? AppTheme.primary)
                          .withValues(alpha: 0.36),
                      width: 1.2,
                    ),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Icon(
                    action.icon,
                    size: 25,
                    color: action.foregroundColor ?? AppTheme.primary,
                    shadows: [
                      Shadow(
                        color: AppTheme.surface.withValues(alpha: 0.9),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _iconSignature(IconData icon) {
  return [
    icon.fontFamily,
    icon.fontPackage,
    icon.codePoint,
    icon.matchTextDirection,
  ].join(':');
}

String _actionSignature(ContextualFabAction action) {
  return [
    _iconSignature(action.icon),
    action.tooltip,
    action.onPressed != null,
    action.backgroundColor?.toARGB32(),
    action.foregroundColor?.toARGB32(),
  ].join(':');
}

String _actionsSignature(List<ContextualFabAction> actions) {
  if (actions.isEmpty) {
    return 'actions-empty';
  }
  return actions.map(_actionSignature).join('|');
}

String _mainFabSignature(
  IconData icon,
  bool isDestructive,
  VoidCallback? onPressed,
) {
  return [_iconSignature(icon), isDestructive, onPressed != null].join(':');
}

class AppTuckedEndFabLocation extends FloatingActionButtonLocation {
  const AppTuckedEndFabLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    return FloatingActionButtonLocation.endFloat.getOffset(scaffoldGeometry);
  }
}

class AppSheetHeader extends StatelessWidget {
  const AppSheetHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.accent = AppTheme.primary,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FlatIllustrationBadge(icon: icon, color: accent, size: 48),
        const SizedBox(width: AppTheme.space3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.titleLarge?.copyWith(
                  color: AppTheme.ink,
                  fontWeight: FontWeight.w900,
                  height: 1.12,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                description,
                style: theme.bodyMedium?.copyWith(
                  color: AppTheme.muted,
                  height: 1.38,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class FlatIllustrationBadge extends StatelessWidget {
  const FlatIllustrationBadge({
    super.key,
    required this.icon,
    this.color = AppTheme.primary,
    this.size = 44,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppTheme.radiusControl),
              ),
            ),
          ),
          Positioned(
            right: -3,
            bottom: -3,
            child: Container(
              width: size * 0.36,
              height: size * 0.36,
              decoration: BoxDecoration(
                color: AppTheme.sunshine,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                border: Border.all(color: AppTheme.surface, width: 2),
              ),
            ),
          ),
          Center(
            child: Icon(icon, color: color, size: size * 0.5),
          ),
        ],
      ),
    );
  }
}

class AppActionTile extends StatelessWidget {
  const AppActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent = AppTheme.primary,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      padding: EdgeInsets.zero,
      color: AppTheme.raisedSurface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              FlatIllustrationBadge(icon: icon, color: accent, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.muted,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: accent, size: 22),
            ],
          ),
        ),
      ),
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
    this.showContext = true,
    this.showCompactMeta = false,
  });

  final String eyebrow;
  final String title;
  final String description;
  final Widget? trailing;
  final bool showContext;
  final bool showCompactMeta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return FadeSlideIn(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.border)),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showContext) ...[
                      Text(
                        eyebrow.toUpperCase(),
                        style: AppTheme.operationText(
                          theme.labelSmall?.copyWith(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                    ],
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                        height: 1.06,
                      ),
                    ),
                    if (showContext) ...[
                      const SizedBox(height: 5),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.operationText(
                          theme.bodySmall?.copyWith(
                            color: AppTheme.muted,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    if (!showContext &&
                        showCompactMeta &&
                        description.trim().isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.operationText(
                          theme.bodySmall?.copyWith(
                            color: AppTheme.muted,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 10),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 70),
                  offset: const Offset(0.02, 0),
                  child: trailing!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AppPanel extends StatelessWidget {
  const AppPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.color = AppTheme.surface,
    this.borderColor = AppTheme.border,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppTheme.fast,
      curve: AppTheme.motionCurve,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: borderColor),
        boxShadow: color == AppTheme.surface ? AppTheme.cardShadow : null,
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
      padding: const EdgeInsets.all(12),
      child: Stack(
        children: [
          Positioned(
            right: -16,
            top: -18,
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              ),
            ),
          ),
          Row(
            children: [
              if (icon != null) ...[
                FlatIllustrationBadge(icon: icon!, color: accent, size: 38),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.operationText(
                        theme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppTheme.ink,
                          height: 1.02,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.operationText(
                        theme.labelSmall?.copyWith(
                          color: AppTheme.muted,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
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
            style: theme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.bodyMedium?.copyWith(
              color: AppTheme.muted,
              height: 1.35,
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
      iconSize: 19,
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        backgroundColor: AppTheme.surface,
        disabledForegroundColor: AppTheme.faint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
          ],
          if (maxWidth == null)
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
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
                  fontWeight: FontWeight.w800,
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
