import 'package:flutter/material.dart';

import '../providers/date_filter_provider.dart';

/// Result of [pickSyncSinceDate]: [cancelled] means the user dismissed the
/// sheet without choosing anything (distinct from explicitly picking "All
/// time", which also has a null [since] but was a deliberate choice) -
/// callers that let the user retry (e.g. a "Re-scan" button) should treat
/// cancelled as "do nothing", while a first-run flow might reasonably
/// default to syncing everything either way.
class SyncDepthChoice {
  const SyncDepthChoice.cancelled()
      : since = null,
        cancelled = true;
  const SyncDepthChoice.since(this.since) : cancelled = false;

  final DateTime? since;
  final bool cancelled;
}

/// Asks how far back to sync SMS from the phone's inbox.
Future<SyncDepthChoice> pickSyncSinceDate(BuildContext context) async {
  final preset = await showModalBottomSheet<DateRangePreset>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _SyncDurationSheet(),
  );
  if (preset == null) return const SyncDepthChoice.cancelled();
  if (preset == DateRangePreset.all) return const SyncDepthChoice.since(null);

  if (preset == DateRangePreset.custom) {
    if (!context.mounted) return const SyncDepthChoice.cancelled();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
    );
    if (range == null) return const SyncDepthChoice.cancelled();
    return SyncDepthChoice.since(range.start);
  }

  final (start, _) = SharedDateFilter(preset: preset).resolveBounds();
  return SyncDepthChoice.since(start);
}

class _SyncDurationSheet extends StatelessWidget {
  const _SyncDurationSheet();

  @override
  Widget build(BuildContext context) {
    // Bottom sheets default to a fixed max height with no scrolling - this
    // list (title + subtitle + 4 presets + custom range) overflows that on
    // smaller screens. Bounding height and letting it scroll instead mirrors
    // _SheetShell in transaction_filter_bar.dart.
    return SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text('How far back should we sync?',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('You can re-scan for more history later in Settings.'),
            ),
            for (final preset in DateRangePreset.values)
              if (preset != DateRangePreset.custom)
                ListTile(
                  title: Text(dateRangePresetLabel(preset)),
                  onTap: () => Navigator.of(context).pop(preset),
                ),
            ListTile(
              title: const Text('Custom range'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).pop(DateRangePreset.custom),
            ),
          ],
        ),
      ),
    );
  }
}
