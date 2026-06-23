import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/app_localizations.dart';
import '../widgets/app_components.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onContinue});

  final Future<void> Function() onContinue;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = context.l10n;
    return Scaffold(
      body: ColoredBox(
        color: AppTheme.background,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 30, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FadeSlideIn(
                        child: Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: AppTheme.cardShadow,
                          ),
                          child: const Icon(
                            Icons.bolt_rounded,
                            size: 28,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 70),
                        child: Text(
                          l10n.welcomeTitle,
                          style: textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppTheme.ink,
                            height: 1.02,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 120),
                        child: Text(
                          l10n.welcomeSubtitle,
                          style: textTheme.bodyLarge?.copyWith(
                            height: 1.42,
                            color: AppTheme.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: AppPanel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    child: Column(
                      children: [
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 180),
                          child: _WelcomePoint(
                            icon: Icons.cloud_done_outlined,
                            title: l10n.welcomeSyncTitle,
                            description: l10n.welcomeSyncBody,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 240),
                          child: _WelcomePoint(
                            icon: Icons.hub_outlined,
                            title: l10n.welcomeObjectsTitle,
                            description: l10n.welcomeObjectsBody,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 300),
                          child: _WelcomePoint(
                            icon: Icons.offline_bolt_outlined,
                            title: l10n.welcomeLocalTitle,
                            description: l10n.welcomeLocalBody,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                  child: FadeSlideIn(
                    delay: const Duration(milliseconds: 360),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async => onContinue(),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(l10n.startTracking),
                      ),
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
}

class _WelcomePoint extends StatelessWidget {
  const _WelcomePoint({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppTheme.primarySoft,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: AppTheme.primary, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.36,
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
