import 'package:flutter/material.dart';

import '../services/app_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _nameController;
  int _roundDuration = AppPreferences.defaultRoundDuration;
  List<String> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController();

    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final name = await AppPreferences.getPlayerName();
    final categories = await AppPreferences.getCategories();
    final roundDuration = await AppPreferences.getRoundDuration();

    if (!mounted) {
      return;
    }

    setState(() {
      _nameController.text = name;
      _categories = categories;
      _roundDuration = roundDuration;
      _loading = false;
    });
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();

    await AppPreferences.setPlayerName(name);

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

  Future<void> _saveCategories() async {
    await AppPreferences.setCategories(_categories);
  }

  Future<void> _addCategory() async {
    final category = await _showCategoryDialog(title: 'Add Category');

    if (category == null) {
      return;
    }

    setState(() {
      _categories.add(category);
    });

    await _saveCategories();
  }

  Future<void> _editCategory(int index) async {
    final category = await _showCategoryDialog(
      title: 'Edit Category',
      initialValue: _categories[index],
      editingIndex: index,
    );

    if (category == null) {
      return;
    }

    setState(() {
      _categories[index] = category;
    });

    await _saveCategories();
  }

  Future<void> _deleteCategory(int index) async {
    if (_categories.length == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need at least one category.')),
      );

      return;
    }

    final category = _categories[index];

    final confirmed = await showDialog<bool>(
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
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('DELETE'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _categories.removeAt(index);
    });

    await _saveCategories();
  }

  Future<void> _resetCategories() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset Categories?'),
          content: const Text(
            'This will restore Name, Place, Animal and Thing.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('RESET'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await AppPreferences.resetCategories();

    if (!mounted) {
      return;
    }

    setState(() {
      _categories = List<String>.from(AppPreferences.defaultCategories);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Categories reset'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<String?> _showCategoryDialog({
    required String title,
    String initialValue = '',
    int? editingIndex,
  }) async {
    final controller = TextEditingController(text: initialValue);

    String? error;

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(title),
              content: TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                maxLength: 30,
                decoration: InputDecoration(
                  labelText: 'Category',
                  hintText: 'e.g. Food',
                  prefixIcon: const Icon(Icons.category_outlined),
                  errorText: error,
                ),
                onChanged: (_) {
                  if (error != null) {
                    setDialogState(() {
                      error = null;
                    });
                  }
                },
                onSubmitted: (_) {
                  final value = controller.text.trim();

                  if (_validateCategory(value, editingIndex)) {
                    Navigator.pop(context, value);
                  } else {
                    setDialogState(() {
                      error = _categoryError(value, editingIndex);
                    });
                  }
                },
              ),
            );
          },
        );
      },
    );

    return result;
  }

  bool _validateCategory(String value, int? editingIndex) {
    if (value.isEmpty) {
      return false;
    }

    final normalized = value.toLowerCase();

    for (var i = 0; i < _categories.length; i++) {
      if (i == editingIndex) {
        continue;
      }

      if (_categories[i].trim().toLowerCase() == normalized) {
        return false;
      }
    }

    return true;
  }

  String _categoryError(String value, int? editingIndex) {
    if (value.isEmpty) {
      return 'Enter a category name';
    }

    final normalized = value.toLowerCase();

    for (var i = 0; i < _categories.length; i++) {
      if (i == editingIndex) {
        continue;
      }

      if (_categories[i].trim().toLowerCase() == normalized) {
        return 'This category already exists';
      }
    }

    return 'Invalid category';
  }

  Future<void> _reorderCategories(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final category = _categories.removeAt(oldIndex);

    _categories.insert(newIndex, category);

    setState(() {});

    await _saveCategories();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            tooltip: 'Save Name',
            icon: const Icon(Icons.check),
            onPressed: _saveName,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _buildPlayerSection(),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.timer_outlined),
                    title: const Text('Time / Round'),
                    subtitle: Text('$_roundDuration seconds'),
                    trailing: DropdownButton<int>(
                      value:
                          AppPreferences.roundDurationOptions.contains(
                            _roundDuration,
                          )
                          ? _roundDuration
                          : AppPreferences.defaultRoundDuration,
                      underline: const SizedBox(),
                      items: AppPreferences.roundDurationOptions
                          .map(
                            (seconds) => DropdownMenuItem<int>(
                              value: seconds,
                              child: Text('$seconds sec'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) async {
                        if (value == null) {
                          return;
                        }

                        setState(() {
                          _roundDuration = value;
                        });

                        await AppPreferences.setRoundDuration(value);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                _buildCategoriesSection(),
              ],
            ),
    );
  }

  Widget _buildPlayerSection() {
    return _buildSectionCard(
      icon: Icons.person_outline,
      title: 'Player',
      subtitle: 'Your name shown to other players',
      child: TextField(
        controller: _nameController,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Name',
          hintText: 'Enter your name',
          prefixIcon: Icon(Icons.person_outline),
          border: OutlineInputBorder(),
        ),
        onSubmitted: (_) => _saveName(),
      ),
    );
  }

  Widget _buildCategoriesSection() {
    return _buildSectionCard(
      icon: Icons.category_outlined,
      title: 'Game Categories',
      subtitle: 'Choose and arrange the categories used in each round.',
      trailing: IconButton(
        tooltip: 'Reset to defaults',
        icon: const Icon(Icons.restart_alt),
        onPressed: _resetCategories,
      ),
      child: Column(
        children: [
          const SizedBox(height: 4),

          if (_categories.isEmpty)
            _buildEmptyCategories()
          else
            _buildCategoryList(),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addCategory,
              icon: const Icon(Icons.add),
              label: const Text('ADD CATEGORY'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList() {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _categories.length,
      onReorder: _reorderCategories,
      buildDefaultDragHandles: false,
      itemBuilder: (context, index) {
        final category = _categories[index];

        return Container(
          key: ValueKey('$category-$index'),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: ReorderableDragStartListener(
              index: index,
              child: const Icon(Icons.drag_indicator),
            ),
            title: Text(
              category,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text('Category ${index + 1}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _editCategory(index),
                ),
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteCategory(index),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyCategories() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: const Column(
        children: [
          Icon(Icons.category_outlined, size: 40),
          SizedBox(height: 8),
          Text('No categories', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text(
            'Add at least one category to play.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
    Widget? trailing,
  }) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
