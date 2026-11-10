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

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Puck',
    theme: ThemeData(colorSchemeSeed: Colors.indigo),
    home: Scaffold(
      appBar: AppBar(title: const Text('Puck playground')),
      body: SafeArea(
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
                          helperText: 'Drag the puck to the keyboard boundary.',
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
              settings: LiquidGlassSettings.ios27Regular(
                brightness: Brightness.light,
                tintAmount: 0.7,
              ),
              defaultAppearance:
                  const LiquidGlassAppearance.ios27RegularLight(),
              child: PuckOverlay(
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
                          icon: Icon(icon, color: const Color(0xFF172554)),
                        ),
                      ),
                    ),
                ],
                puck: LiquidGlass.withOwnLayer(
                  settings: LiquidGlassSettings.ios27Regular(
                    brightness: Brightness.light,
                    tintAmount: 0.7,
                  ),
                  appearance: const LiquidGlassAppearance.ios27RegularLight(),
                  shape: const LiquidOval(),
                  child: const Icon(Icons.menu, color: Color(0xFF172554)),
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
