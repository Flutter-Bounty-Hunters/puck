import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:puck/puck.dart';

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
      home: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('Puck playground'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          actions: [
            IconButton(
              tooltip: _darkMode
                  ? 'Switch to light mode'
                  : 'Switch to dark mode',
              icon: Icon(_darkMode ? Icons.light_mode : Icons.dark_mode),
              onPressed: () => setState(() => _darkMode = !_darkMode),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(24),
                  child: SizedBox(
                    width: 360,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Drag or fling the puck.\nTap to open or close the menu.\nLong-press to toggle anchor dots.',
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 24),
                        TextField(
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            labelText: 'Keyboard test',
                            hintText: 'Tap to open the keyboard',
                            helperText:
                                'Drag the puck to the keyboard boundary.',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // The menu items share a backdrop sample. The parent has its
              // own layer so its glass paints above the items and their icons.
              LiquidGlassLayer(
                settings: glassSettings,
                defaultAppearance: glassAppearance,
                child: PuckOverlay(
                  showRopes: true,
                  showDebugAnchors: _showDebugAnchors,
                  onLongPress: () =>
                      setState(() => _showDebugAnchors = !_showDebugAnchors),
                  menuItems: [
                    for (final (icon, label) in [
                      (Icons.home, 'Home'),
                      (Icons.search, 'Search'),
                      (Icons.settings, 'Settings'),
                    ])
                      LiquidGlass(
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
      ),
    );
  }
}
