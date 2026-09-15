import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/sms/sms_providers.dart';

/// Generic persisted boolean flags backed by the AppSettings table - used
/// both for one-time UI hints (so they don't nag the user on every app open
/// once dismissed) and "don't ask again" style opt-outs from confirmation
/// dialogs.
const swipeToExcludeHintKey = 'seen_swipe_to_exclude_hint';
const skipExcludeConfirmKey = 'skip_exclude_confirm_dialog';
const skipDismissSmsConfirmKey = 'skip_dismiss_sms_confirm_dialog';

final hasSeenHintProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, key) async {
  final db = ref.watch(databaseProvider);
  final row = await (db.select(db.appSettings)
        ..where((t) => t.settingKey.equals(key)))
      .getSingleOrNull();
  return row?.settingValue == 'true';
});

/// One-shot read (not a watched provider) for use inside callbacks like
/// Dismissible.confirmDismiss, where a stale cached `ref.watch` value could
/// let a dialog flash briefly before the flag loads.
Future<bool> readHintFlag(WidgetRef ref, String key) async {
  final db = ref.read(databaseProvider);
  final row = await (db.select(db.appSettings)
        ..where((t) => t.settingKey.equals(key)))
      .getSingleOrNull();
  return row?.settingValue == 'true';
}

Future<void> markHintSeen(WidgetRef ref, String key) async {
  final db = ref.read(databaseProvider);
  await db.into(db.appSettings).insertOnConflictUpdate(
        AppSettingsCompanion.insert(settingKey: key, settingValue: 'true'),
      );
  ref.invalidate(hasSeenHintProvider(key));
}

/// Reverses [markHintSeen] - lets a "don't ask again" choice be undone from
/// Settings rather than being a permanent dead end.
Future<void> clearHintFlag(WidgetRef ref, String key) async {
  final db = ref.read(databaseProvider);
  await db.into(db.appSettings).insertOnConflictUpdate(
        AppSettingsCompanion.insert(settingKey: key, settingValue: 'false'),
      );
  ref.invalidate(hasSeenHintProvider(key));
}
