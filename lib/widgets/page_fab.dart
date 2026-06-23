import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_components.dart';

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

mixin PageFabBinding<T extends StatefulWidget> on State<T> {
  PageFabController get pageFabController;
  int get pageFabIndex;
  bool get pageFabReady => true;
  PageFabConfig buildPageFabConfig();

  bool _pageFabSyncScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    schedulePageFabSync();
  }

  @override
  void dispose() {
    pageFabController.clearConfig(pageFabIndex);
    super.dispose();
  }

  void schedulePageFabSync() {
    if (_pageFabSyncScheduled) {
      return;
    }
    _pageFabSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pageFabSyncScheduled = false;
      if (!mounted) {
        return;
      }
      if (!pageFabReady) {
        pageFabController.clearConfig(pageFabIndex);
        return;
      }
      pageFabController.setConfig(pageFabIndex, buildPageFabConfig());
    });
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
