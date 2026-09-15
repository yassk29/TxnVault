import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/sms/sms_providers.dart';
import '../../../../shared/providers/app_settings_provider.dart';
import '../../../../shared/widgets/sync_duration_picker.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _syncing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: _syncing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync),
            title: const Text('Re-scan SMS Inbox'),
            subtitle: const Text(
                'Pull in any SMS not yet captured - useful after a coverage change'),
            onTap: _syncing ? null : _resync,
          ),
          const Divider(height: 1),
          const _ConfirmExcludeToggle(),
          const _ConfirmDismissSmsToggle(),
          const Divider(height: 1),
          const ListTile(
              leading: Icon(Icons.notifications_outlined), title: Text('Notifications')),
          const ListTile(leading: Icon(Icons.dark_mode_outlined), title: Text('Theme')),
          const ListTile(
              leading: Icon(Icons.file_download_outlined), title: Text('Export Data')),
          const ListTile(leading: Icon(Icons.lock_outline), title: Text('Permissions')),
          const ListTile(leading: Icon(Icons.info_outline), title: Text('About')),
        ],
      ),
    );
  }

  Future<void> _resync() async {
    final choice = await pickSyncSinceDate(context);
    if (choice.cancelled || !mounted) return;

    setState(() => _syncing = true);
    final inserted = await ref
        .read(smsSyncServiceProvider)
        .syncInboxHistory(since: choice.since);
    setState(() => _syncing = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(inserted == 0
              ? 'No new SMS found.'
              : '$inserted new SMS captured - processing in the background.'),
        ),
      );
    }
  }
}

/// Undoes a "don't ask again" tap on the exclude-transaction dialog (see
/// transactions_screen.dart) - otherwise checking that box once would be a
/// permanent, invisible dead end with no way back.
class _ConfirmExcludeToggle extends ConsumerWidget {
  const _ConfirmExcludeToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skipConfirm = ref.watch(hasSeenHintProvider(skipExcludeConfirmKey));

    return SwitchListTile(
      secondary: const Icon(Icons.help_outline),
      title: const Text('Confirm before excluding transactions'),
      subtitle: const Text('Shows the swipe-to-exclude confirmation dialog'),
      value: !(skipConfirm.valueOrNull ?? false),
      onChanged: (enabled) {
        if (enabled) {
          clearHintFlag(ref, skipExcludeConfirmKey);
        } else {
          markHintSeen(ref, skipExcludeConfirmKey);
        }
      },
    );
  }
}

/// Mirrors _ConfirmExcludeToggle for the SMS Review "dismiss" dialog (see
/// sms_review_screen.dart).
class _ConfirmDismissSmsToggle extends ConsumerWidget {
  const _ConfirmDismissSmsToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skipConfirm =
        ref.watch(hasSeenHintProvider(skipDismissSmsConfirmKey));

    return SwitchListTile(
      secondary: const Icon(Icons.help_outline),
      title: const Text('Confirm before dismissing SMS'),
      subtitle: const Text('Shows the swipe-to-dismiss confirmation dialog '
          'in SMS Review'),
      value: !(skipConfirm.valueOrNull ?? false),
      onChanged: (enabled) {
        if (enabled) {
          clearHintFlag(ref, skipDismissSmsConfirmKey);
        } else {
          markHintSeen(ref, skipDismissSmsConfirmKey);
        }
      },
    );
  }
}
