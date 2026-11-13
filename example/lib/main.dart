import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:puck/puck.dart';

import 'prepared_menu_glass_layer.dart';

const _demoTiers = [
  [
    (Icons.home, 'Home'),
    (Icons.search, 'Search'),
    (Icons.favorite, 'Favorites'),
    (Icons.explore, 'Explore'),
  ],
  [
    (Icons.bookmark, 'Bookmarks'),
    (Icons.share, 'Share'),
    (Icons.download, 'Downloads'),
    (Icons.history, 'History'),
    (Icons.folder, 'Files'),
    (Icons.photo, 'Photos'),
    (Icons.link, 'Links'),
  ],
  [
    (Icons.settings, 'Settings'),
    (Icons.person, 'Profile'),
    (Icons.help_outline, 'Help'),
    (Icons.info_outline, 'About'),
    (Icons.notifications, 'Notifications'),
    (Icons.calendar_today, 'Calendar'),
    (Icons.mail_outline, 'Messages'),
    (Icons.edit_note, 'Notes'),
    (Icons.task_alt, 'Tasks'),
    (Icons.map_outlined, 'Maps'),
    (Icons.music_note, 'Music'),
    (Icons.videocam_outlined, 'Videos'),
  ],
];

void main() => runApp(const PuckDemo());

class PuckDemo extends StatefulWidget {
  const PuckDemo({super.key});

  @override
  State<PuckDemo> createState() => _PuckDemoState();
}

class _PuckDemoState extends State<PuckDemo> {
  bool _showDebugAnchors = false;
  bool _darkMode = false;
  @override
  Widget build(BuildContext context) {
    final brightness = _darkMode ? Brightness.dark : Brightness.light;
    final iconColor = _darkMode
        ? const Color(0xFFE8EDFF)
        : const Color(0xFF172554);
    final glassSettings = LiquidGlassSettings.ios27Regular(
      brightness: brightness,
      tintAmount: 0.7,
    );
    final glassAppearance = LiquidGlassAppearance.ios27Regular(
      brightness: brightness,
    );
    return MaterialApp(
      title: 'Puck',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
      ),
      themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
      // Keep the menu above the Navigator, including its app bars and dialogs.
      builder: (context, child) => Overlay.wrap(
        child: Stack(
          fit: StackFit.expand,
          children: [
            child!,
            SafeArea(
              child: PuckOverlay(
                maintainMenuState: true,
                menuTierBuilder: (context, tier, child) =>
                    PreparedMenuGlassLayer(
                      settings: glassSettings,
                      appearance: glassAppearance,
                      itemCount: _demoTiers[tier].length,
                      radius: 80.0 + 80 * tier + 4 * tier * (tier + 1),
                      child: child,
                    ),
                showRopes: false,
                showTierCurves: true,
                menuRadius: 80,
                showDebugAnchors: _showDebugAnchors,
                onLongPress: () =>
                    setState(() => _showDebugAnchors = !_showDebugAnchors),
                menuTiers: [
                  for (final tier in _demoTiers)
                    [
                      for (final (icon, label) in tier)
                        LiquidGlass(
                          key: ValueKey(label),
                          shape: const LiquidOval(),
                          child: Material(
                            type: MaterialType.transparency,
                            child: IconButton(
                              tooltip: label,
                              onPressed: () => debugPrint('$label tapped'),
                              icon: Icon(icon, color: iconColor),
                            ),
                          ),
                        ),
                    ],
                ],
                puck: LiquidGlass.withOwnLayer(
                  settings: glassSettings,
                  appearance: glassAppearance,
                  shape: const LiquidOval(),
                  child: Icon(Icons.menu, color: iconColor),
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
      home: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('Puck playground'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            tooltip: _darkMode ? 'Switch to light mode' : 'Switch to dark mode',
            icon: Icon(_darkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => setState(() => _darkMode = !_darkMode),
          ),
          actions: [
            IconButton(
              tooltip: _showDebugAnchors
                  ? 'Hide debug visuals'
                  : 'Show debug visuals',
              isSelected: _showDebugAnchors,
              icon: const Icon(Icons.bug_report_outlined),
              selectedIcon: const Icon(Icons.bug_report),
              onPressed: () =>
                  setState(() => _showDebugAnchors = !_showDebugAnchors),
            ),
          ],
        ),
        body: SafeArea(
          child: const Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Drag or fling the puck.\nTap to open or close three menu tiers.\nLong-press to toggle arcs, end-cap lines, and anchor dots.',
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 24),
                    TextField(
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'Keyboard test',
                        hintText: 'Tap to open the keyboard',
                        helperText: 'Drag the puck to the keyboard boundary.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
