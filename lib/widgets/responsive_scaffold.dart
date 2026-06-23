import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'page_fab.dart';

enum AppLayoutSize { mobile, tablet, desktop }

AppLayoutSize layoutSizeForWidth(double width) {
  if (width >= 1100) {
    return AppLayoutSize.desktop;
  }
  if (width >= 700) {
    return AppLayoutSize.tablet;
  }
  return AppLayoutSize.mobile;
}

AppLayoutSize layoutSizeOf(BuildContext context) {
  return layoutSizeForWidth(MediaQuery.sizeOf(context).width);
}

bool isDesktopLayout(BuildContext context) {
  return layoutSizeOf(context) == AppLayoutSize.desktop;
}

class ResponsiveScaffold extends StatelessWidget {
  const ResponsiveScaffold({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.body,
    required this.mobileItems,
    this.floatingActionButton,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationRailDestination> destinations;
  final List<BottomNavigationBarItem> mobileItems;
  final Widget body;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final layoutSize = layoutSizeOf(context);
    if (layoutSize == AppLayoutSize.mobile) {
      return Scaffold(
        body: body,
        bottomNavigationBar: SafeArea(
          child: Container(
            height: 70,
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.border),
              boxShadow: AppTheme.cardShadow,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BottomNavigationBar(
                currentIndex: currentIndex,
                onTap: onDestinationSelected,
                selectedFontSize: 12,
                unselectedFontSize: 12,
                iconSize: 24,
                items: mobileItems,
              ),
            ),
          ),
        ),
        floatingActionButtonLocation: const AppTuckedEndFabLocation(),
        floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
        floatingActionButton: floatingActionButton,
      );
    }

    return Scaffold(
      body: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              border: const Border(right: BorderSide(color: AppTheme.border)),
              boxShadow: layoutSize == AppLayoutSize.desktop
                  ? [
                      BoxShadow(
                        color: AppTheme.ink.withValues(alpha: 0.04),
                        blurRadius: 18,
                        offset: const Offset(8, 0),
                      ),
                    ]
                  : null,
            ),
            child: NavigationRail(
              selectedIndex: currentIndex,
              onDestinationSelected: onDestinationSelected,
              labelType: layoutSize == AppLayoutSize.desktop
                  ? NavigationRailLabelType.all
                  : NavigationRailLabelType.selected,
              minWidth: layoutSize == AppLayoutSize.desktop ? 84 : 68,
              backgroundColor: AppTheme.surface,
              indicatorColor: AppTheme.primarySoft,
              indicatorShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusControl),
              ),
              selectedIconTheme: const IconThemeData(
                color: AppTheme.primary,
                size: 23,
              ),
              unselectedIconTheme: const IconThemeData(
                color: AppTheme.muted,
                size: 22,
              ),
              selectedLabelTextStyle: AppTheme.operationText(
                const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
              unselectedLabelTextStyle: AppTheme.operationText(
                const TextStyle(
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
              leading: Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 12),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                    border: Border.all(color: AppTheme.border),
                    boxShadow: AppTheme.liftShadow,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset('assets/app_icon.png', fit: BoxFit.cover),
                ),
              ),
              destinations: destinations,
            ),
          ),
          Expanded(child: body),
        ],
      ),
      floatingActionButtonLocation: const AppTuckedEndFabLocation(),
      floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
      floatingActionButton: floatingActionButton,
    );
  }
}

class AdaptiveWorkspace extends StatelessWidget {
  const AdaptiveWorkspace({
    super.key,
    required this.primary,
    this.secondary,
    this.tertiary,
    this.primaryFlex = 5,
    this.secondaryFlex = 4,
    this.tertiaryFlex = 3,
    this.padding = const EdgeInsets.all(AppTheme.space3),
  });

  final Widget primary;
  final Widget? secondary;
  final Widget? tertiary;
  final int primaryFlex;
  final int secondaryFlex;
  final int tertiaryFlex;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      Expanded(flex: primaryFlex, child: primary),
      if (secondary != null) ...[
        const SizedBox(width: AppTheme.space3),
        Expanded(flex: secondaryFlex, child: secondary!),
      ],
      if (tertiary != null) ...[
        const SizedBox(width: AppTheme.space3),
        Expanded(flex: tertiaryFlex, child: tertiary!),
      ],
    ];

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
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
    return DecoratedBox(
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
                      color: AppTheme.ink,
                      fontWeight: FontWeight.w800,
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
              AnimatedSwitcher(
                duration: AppTheme.medium,
                switchInCurve: AppTheme.motionCurve,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.04, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: trailing!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SyncActionButton extends StatelessWidget {
  const SyncActionButton({
    super.key,
    required this.onPressed,
    required this.tooltip,
    this.isSyncing = false,
  });

  final Future<void> Function() onPressed;
  final String tooltip;
  final bool isSyncing;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: isSyncing ? null : () => unawaited(onPressed()),
      icon: isSyncing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.sync),
      color: AppTheme.primary,
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      padding: EdgeInsets.zero,
      iconSize: 19,
      style: IconButton.styleFrom(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppTheme.border),
        ),
      ),
    );
  }
}
