import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: const [
          ListTile(leading: Icon(Icons.notifications_outlined), title: Text('Notifications')),
          ListTile(leading: Icon(Icons.dark_mode_outlined), title: Text('Theme')),
          ListTile(leading: Icon(Icons.file_download_outlined), title: Text('Export Data')),
          ListTile(leading: Icon(Icons.lock_outline), title: Text('Permissions')),
          ListTile(leading: Icon(Icons.info_outline), title: Text('About')),
        ],
      ),
    );
  }
}
