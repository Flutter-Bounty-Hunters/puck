import 'package:flutter/material.dart';
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
        child: PuckOverlay(
          showDebugAnchors: _showDebugAnchors,
          onLongPress: () =>
              setState(() => _showDebugAnchors = !_showDebugAnchors),
          menuItems: [
            for (final icon in [Icons.home, Icons.search, Icons.settings])
              Material(
                color: Colors.indigo,
                child: IconButton(
                  onPressed: () => debugPrint('$icon tapped'),
                  icon: Icon(icon, color: Colors.white),
                ),
              ),
          ],
          puck: const ColoredBox(
            color: Colors.indigo,
            child: Icon(Icons.menu, color: Colors.white),
          ),
          child: const Center(
            child: Text(
              'Drag or fling the puck.\nTap to open or close the menu.\nLong-press to toggle anchor dots.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    ),
  );
}
