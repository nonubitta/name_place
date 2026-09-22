import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/theme_controller.dart';
import '../services/app_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _nameController = TextEditingController();

  List<String> _categories = [];

  int _roundDuration = AppPreferences.defaultRoundDuration;

  String _appVersion = '';
  String _buildNumber = '';

  bool _loading = true;

  @override
  void initState() {
    super.initState();

    _loadSettings();
    _loadAppInfo();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // --------------------------------------------------
  // Load settings
  // --------------------------------------------------

  Future<void> _loadSettings() async {
    final playerName = await AppPreferences.getPlayerName();

    final categories = await AppPreferences.getCategories();

    final roundDuration = await AppPreferences.getRoundDuration();

    if (!mounted) {
      return;
    }

    setState(() {
      _nameController.text = playerName;
      _categories = List<String>.from(categories);
      _roundDuration = roundDuration;
      _loading = false;
    });
  }

  Future<void> _loadAppInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();

    if (!mounted) {
      return;
    }

    setState(() {
      _appVersion = packageInfo.version;
      _buildNumber = packageInfo.buildNumber;
    });
  }

  // --------------------------------------------------
  // Player name
  // --------------------------------------------------

  Future<void> _savePlayerName() async {
    await AppPreferences.setPlayerName(_nameController.text);
  }

  // --------------------------------------------------
  // Categories
  // --------------------------------------------------

  Future<void> _addCategory() async {
    final category = await _showCategoryDialog(title: 'Add Category');

    if (category == null) {
      return;
    }

    final exists = _categories.any(
      (item) => item.toLowerCase() == category.toLowerCase(),
    );

    if (exists) {
      _showMessage('That category already exists.');
      return;
    }

    setState(() {
      _categories.add(category);
    });

    await AppPreferences.setCategories(_categories);
  }

  Future<void> _editCategory(int index) async {
    final category = await _showCategoryDialog(
      title: 'Edit Category',
      initialValue: _categories[index],
    );

    if (category == null) {
      return;
    }

    final duplicateIndex = _categories.indexWhere(
      (item) => item.toLowerCase() == category.toLowerCase(),
    );

    if (duplicateIndex != -1 && duplicateIndex != index) {
      _showMessage('That category already exists.');
      return;
    }

    setState(() {
      _categories[index] = category;
    });

    await AppPreferences.setCategories(_categories);
  }

  Future<void> _deleteCategory(int index) async {
    if (_categories.length <= 1) {
      _showMessage('At least one category is required.');
      return;
    }

    final category = _categories[index];

    final confirmed = await _showDeleteConfirmation(category);

    if (!confirmed) {
      return;
    }

    setState(() {
      _categories.removeAt(index);
    });

    await AppPreferences.setCategories(_categories);
  }

  Future<void> _resetCategories() async {
    final confirmed = await _showResetConfirmation();

    if (!confirmed) {
      return;
    }

    await AppPreferences.resetCategories();

    final defaults = await AppPreferences.getCategories();

    if (!mounted) {
      return;
    }

    setState(() {
      _categories = List<String>.from(defaults);
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }

      final item = _categories.removeAt(oldIndex);

      _categories.insert(newIndex, item);
    });

    AppPreferences.setCategories(_categories);
  }

  Future<String?> _showCategoryDialog({
    required String title,
    String initialValue = '',
  }) {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return _CategoryDialog(
          title: title,
          initialValue: initialValue,
        );
      },
    );
  }

  Future<bool> _showDeleteConfirmation(String category) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Category?'),
          content: Text('Remove "$category" from your game categories?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<bool> _showResetConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset Categories?'),
          content: const Text(
            'This will restore the default categories:\n\n'
            'Name\n'
            'Place\n'
            'Animal\n'
            'Thing',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  // --------------------------------------------------
  // Time / Round
  // --------------------------------------------------

  Future<void> _setRoundDuration(int seconds) async {
    setState(() {
      _roundDuration = seconds;
    });

    await AppPreferences.setRoundDuration(seconds);
  }

  // --------------------------------------------------
  // Helpers
  // --------------------------------------------------

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // --------------------------------------------------
  // UI
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _buildPlayerSection(),
          const SizedBox(height: 20),
          _buildGameSettingsSection(),
          const SizedBox(height: 20),
          _buildAppearanceSection(),
          const SizedBox(height: 24),
          _buildAboutSection(),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // Player section
  // --------------------------------------------------

  Widget _buildPlayerSection() {
    return _buildSection(
      title: 'Player',
      icon: Icons.person_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your name',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: 'Enter your name',
              prefixIcon: const Icon(Icons.person_outline),
              suffixIcon: IconButton(
                tooltip: 'Save',
                icon: const Icon(Icons.check_rounded),
                onPressed: _savePlayerName,
              ),
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) {
              _savePlayerName();
            },
          ),
          const SizedBox(height: 6),
          Text(
            'This name will be used when joining a game.',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // Game settings section
  // --------------------------------------------------

  Widget _buildGameSettingsSection() {
    return _buildSection(
      title: 'Game Settings',
      icon: Icons.tune_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTimeRoundSetting(),

          const SizedBox(height: 20),

          _buildCategoriesHeader(),

          const SizedBox(height: 8),

          _categories.isEmpty
              ? _buildEmptyCategories()
              : _buildCategoriesList(),
        ],
      ),
    );
  }

  Widget _buildTimeRoundSetting() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              Icons.timer_outlined,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Time / Round',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 3),
                Text(
                  'How long players have to answer each round.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value:
                  AppPreferences.roundDurationOptions.contains(_roundDuration)
                  ? _roundDuration
                  : AppPreferences.defaultRoundDuration,
              borderRadius: BorderRadius.circular(12),
              items: AppPreferences.roundDurationOptions
                  .map(
                    (seconds) => DropdownMenuItem<int>(
                      value: seconds,
                      child: Text(
                        '$seconds sec',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  _setRoundDuration(value);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesHeader() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Categories',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              SizedBox(height: 3),
              Text(
                'Drag to change the order.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: _addCategory,
          icon: const Icon(Icons.add, size: 19),
          label: const Text('Add'),
        ),
      ],
    );
  }

  Widget _buildCategoriesList() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _categories.length,
        onReorder: _onReorder,
        buildDefaultDragHandles: false,
        itemBuilder: (context, index) {
          final category = _categories[index];

          return Column(
            key: ValueKey('$category-$index'),
            children: [
              if (index > 0) const Divider(height: 1),
              ListTile(
                dense: true,
                leading: ReorderableDragStartListener(
                  index: index,
                  child: const Icon(
                    Icons.drag_indicator_rounded,
                    color: Colors.grey,
                  ),
                ),
                title: Text(
                  category,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Edit',
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () {
                        _editCategory(index);
                      },
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () {
                        _deleteCategory(index);
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyCategories() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Icon(Icons.category_outlined, size: 36, color: Colors.grey),
          const SizedBox(height: 8),
          const Text(
            'No categories',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: _resetCategories,
            child: const Text('Restore Defaults'),
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceSection() {
    return _buildSection(
      title: 'Appearance',
      icon: Icons.palette_outlined,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            Icons.dark_mode_outlined,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: const Text(
          'Dark Theme',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Use the dark royal theme throughout the app.',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Switch(
          value: ThemeController.instance.isDark,
          onChanged: (value) async {
            await ThemeController.instance.setDarkTheme(value);

            if (!mounted) {
              return;
            }

            setState(() {});
          },
        ),
      ),
    );
  }
  // --------------------------------------------------
  // About
  // --------------------------------------------------

  Widget _buildAboutSection() {
    return _buildSection(
      title: 'About',
      icon: Icons.info_outline_rounded,
      child: Column(
        children: [
          const SizedBox(height: 4),

          // App icon / logo placeholder.
          // This does not depend on an asset being
          // configured, so Settings won't break.
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(
              Icons.sports_esports_rounded,
              color: Colors.white,
              size: 38,
            ),
          ),

          const SizedBox(height: 12),

          const Text(
            'Name Place',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 3),

          Text(
            'A fun multiplayer word game',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 18),

          const Divider(height: 1),

          const SizedBox(height: 14),

          _buildAboutRow(
            icon: Icons.person_outline,
            title: 'Developed by',
            value: 'Gurmeet Singh Khalsa',
          ),

          const SizedBox(height: 13),

          _buildAboutRow(
            icon: Icons.phone_android_outlined,
            title: 'App Version',
            value: _appVersion.isEmpty ? 'Loading...' : _appVersion,
          ),

          if (_buildNumber.isNotEmpty) ...[
            const SizedBox(height: 13),
            _buildAboutRow(
              icon: Icons.build_outlined,
              title: 'Build',
              value: _buildNumber,
            ),
          ],

          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildAboutRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 19,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),

        const SizedBox(width: 12),

        Expanded(child: Text(title, style: const TextStyle(fontSize: 14))),

        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------
  // Generic section container
  // --------------------------------------------------

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 19,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            child,
          ],
        ),
      ),
    );
  }
}


class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({
    required this.title,
    this.initialValue = '',
  });

  final String title;
  final String initialValue;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = _controller.text.trim();

    if (value.isEmpty) {
      return;
    }

    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Category',
          hintText: 'Enter category name',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
