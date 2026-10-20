import 'package:flutter/material.dart';
import 'package:puck/puck.dart';

void main() => runApp(const PuckDemo());

class PuckDemo extends StatelessWidget {
  const PuckDemo({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Puck',
    theme: ThemeData(colorSchemeSeed: Colors.indigo),
    home: Scaffold(
      appBar: AppBar(title: const Text('Puck playground')),
      body: SafeArea(
        child: PuckOverlay(
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
              'Drag or fling the puck.\nTap to open or close the menu.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    ),
  );
}
