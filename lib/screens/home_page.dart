import 'package:flutter/material.dart';
import '../services/theme_controller.dart';
import 'settings_page.dart';
import 'host_page.dart';
import 'join_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final onColor = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Name Place Multiplayer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: onColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.groups_rounded,
                        size: 72,
                        color: onColor,
                      ),
                    ),

                    const SizedBox(height: 28),

                    Text(
                      'Name Place Multiplayer',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: onColor,
                        letterSpacing: 0.5,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      'Play together on the same Wi-Fi network',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: onColor.withValues(alpha: 0.85),
                      ),
                    ),

                    const SizedBox(height: 44),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Create Game'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const HostPage()),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.search),
                        label: const Text('Find Game'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const JoinPage()),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 40),

                    Icon(
                      Icons.wifi_rounded,
                      size: 40,
                      color: onColor.withValues(alpha: 0.9),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Random Palette Color: '
                        '${ThemeController.instance.lightPalette.name}',
                        style: TextStyle(
                          fontSize: 11,
                          color: onColor.withValues(alpha: 0.7),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.shuffle_rounded),
                        iconSize: 18,
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Shuffle palette color',
                        color: onColor.withValues(alpha: 0.7),
                        onPressed: () async {
                          await ThemeController.instance.clearPreferences();
                        },
                      ),
                    ],
                  ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
