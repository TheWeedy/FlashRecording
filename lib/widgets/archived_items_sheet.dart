import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/responsive_scaffold.dart';

Future<void> showArchivedItemsSheet({
  required BuildContext context,
  required String eyebrow,
  required String title,
  required String emptyMessage,
  required int itemCount,
  required Widget Function(BuildContext context, int index) itemBuilder,
}) async {
  await showAppActionSheet<void>(
    context: context,
    builder: (sheetContext) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.72,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                eyebrow: eyebrow,
                title: '$title ($itemCount)',
                description: emptyMessage,
                showContext: false,
                showCompactMeta: itemCount == 0,
              ),
              const SizedBox(height: AppTheme.space3),
              Flexible(
                child: itemCount == 0
                    ? EmptyState(
                        icon: Icons.archive_outlined,
                        title: title,
                        message: emptyMessage,
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: itemCount,
                        itemBuilder: itemBuilder,
                      ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
