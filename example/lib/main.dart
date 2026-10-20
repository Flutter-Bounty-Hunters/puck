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
          onTap: () => debugPrint('Puck tapped'),
          puck: const ColoredBox(
            color: Colors.indigo,
            child: Icon(Icons.menu, color: Colors.white),
          ),
          child: const Center(
            child: Text(
              'Drag or fling the puck.\nTap it to trigger an action.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    ),
  );
}
