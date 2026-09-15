import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/date_filter_provider.dart';

/// A capsule chip showing the current shared date filter; tapping opens a
/// picker. Used on both the Dashboard and the Transactions/History screen so
/// picking a range on either automatically scopes the other.
class DateFilterCapsule extends ConsumerWidget {
  const DateFilterCapsule({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(sharedDateFilterProvider);
    final active = filter.isActive;
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => showModalBottomSheet(
        context: context,
        builder: (_) => const _DateFilterSheet(),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month,
                size: 16,
                color: active ? scheme.onPrimaryContainer : scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              active ? dateRangePresetLabel(filter.preset) : 'Date',
              style: TextStyle(
                color: active ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down,
                size: 18,
                color: active ? scheme.onPrimaryContainer : scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _DateFilterSheet extends ConsumerWidget {
  const _DateFilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(sharedDateFilterProvider);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(
              title: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
          for (final preset in DateRangePreset.values)
            if (preset != DateRangePreset.custom)
              ListTile(
                title: Text(dateRangePresetLabel(preset)),
                trailing: filter.preset == preset
                    ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () {
                  ref.read(sharedDateFilterProvider.notifier).state =
                      SharedDateFilter(preset: preset);
                  Navigator.of(context).pop();
                },
              ),
          ListTile(
            title: const Text('Custom range'),
            trailing: filter.preset == DateRangePreset.custom
                ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                : const Icon(Icons.chevron_right),
            onTap: () async {
              final range = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2015),
                lastDate: DateTime.now(),
              );
              if (range == null) return;
              ref.read(sharedDateFilterProvider.notifier).state = SharedDateFilter(
                preset: DateRangePreset.custom,
                startDate: range.start,
                endDate: range.end.add(const Duration(days: 1)),
              );
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
