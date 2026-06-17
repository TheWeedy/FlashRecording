import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_components.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onContinue});

  final Future<void> Function() onContinue;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: ColoredBox(
        color: AppTheme.background,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 42, 24, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FadeSlideIn(
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppTheme.border),
                            boxShadow: AppTheme.cardShadow,
                          ),
                          child: const Icon(
                            Icons.schedule_rounded,
                            size: 34,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 70),
                        child: Text(
                          'Record My Time',
                          style: textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.ink,
                            height: 1.05,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 120),
                        child: Text(
                          'A calm operating layer for entries, tasks, notes, and sync. Keep the local-first flow you trust, with a cleaner workspace around it.',
                          style: textTheme.bodyLarge?.copyWith(
                            height: 1.55,
                            color: AppTheme.muted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: AppPanel(
                    color: AppTheme.raisedSurface,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                    child: Column(
                      children: const [
                        FadeSlideIn(
                          delay: Duration(milliseconds: 180),
                          child: _WelcomePoint(
                            icon: Icons.cloud_done_outlined,
                            title: 'Automatic cloud sync',
                            description:
                                'Sign in once and changes will move between devices through PocketBase.',
                          ),
                        ),
                        SizedBox(height: 16),
                        FadeSlideIn(
                          delay: Duration(milliseconds: 240),
                          child: _WelcomePoint(
                            icon: Icons.hub_outlined,
                            title: 'Connected work objects',
                            description:
                                'Entries, tasks, and notes stay together so context does not drift.',
                          ),
                        ),
                        SizedBox(height: 16),
                        FadeSlideIn(
                          delay: Duration(milliseconds: 300),
                          child: _WelcomePoint(
                            icon: Icons.offline_bolt_outlined,
                            title: 'Local-first by default',
                            description:
                                'Keep recording offline. Sync resumes quietly when the network returns.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                  child: FadeSlideIn(
                    delay: const Duration(milliseconds: 360),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async => onContinue(),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Start tracking'),
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
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.primarySoft,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Icon(icon, color: AppTheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: AppTheme.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
