import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _nameKey = 'player_name';

  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController();
    _loadName();
  }

  Future<void> _loadName() async {
    final preferences =
        await SharedPreferences.getInstance();

    final name =
        preferences.getString(_nameKey) ?? '';

    if (!mounted) {
      return;
    }

    _nameController.text = name;
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();

    final preferences =
        await SharedPreferences.getInstance();

    if (name.isEmpty) {
      await preferences.remove(_nameKey);
    } else {
      await preferences.setString(
        _nameKey,
        name,
      );
    }

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Name saved'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            tooltip: 'Save',
            icon: const Icon(Icons.check),
            onPressed: _saveName,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Player',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            textCapitalization:
                TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'Enter your name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person_outline),
            ),
            onSubmitted: (_) => _saveName(),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}