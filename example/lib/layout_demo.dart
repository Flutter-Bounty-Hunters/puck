import 'package:flutter/material.dart';
import 'package:puck/puck.dart';

void main() => runApp(
  const MaterialApp(debugShowCheckedModeBanner: false, home: MenuLayoutDemo()),
);

/// A live view of the real layout solver, without menu items or item springs.
class MenuLayoutDemo extends StatefulWidget {
  const MenuLayoutDemo({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<MenuLayoutDemo> createState() => _MenuLayoutDemoState();
}

class _MenuLayoutDemoState extends State<MenuLayoutDemo> {
  final _expanded = ValueNotifier(true);
  int _reset = 0;

  @override
  void dispose() {
    _expanded.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF101722),
      colorSchemeSeed: const Color(0xFF9CAFFF),
    ),
    child: Stack(
      fit: StackFit.expand,
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Menu layout', style: TextStyle(fontSize: 17)),
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            leading: widget.onBack == null
                ? null
                : IconButton(
                    tooltip: 'Back to playground',
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back),
                  ),
            actions: [
              IconButton(
                tooltip: 'Reset layout',
                icon: const Icon(Icons.restart_alt),
                onPressed: () {
                  _expanded.value = true;
                  setState(() => _reset++);
                },
              ),
            ],
          ),
        ),
        SafeArea(
          child: PuckOverlay(
            key: ValueKey(_reset),
            layoutPreview: true,
            menuExpanded: _expanded,
            menuRadius: 80,
            menuItemDiameter: 48,
            menuTiers: [
              for (final count in [4, 7, 12])
                List.generate(count, (_) => const SizedBox()),
            ],
            puck: const DecoratedBox(
              key: ValueKey('layout-root'),
              decoration: BoxDecoration(
                color: Color(0xFF28354C),
                shape: BoxShape.circle,
                border: Border.fromBorderSide(
                  BorderSide(color: Color(0xFFCCD7EF)),
                ),
              ),
              child: Icon(Icons.open_with, color: Color(0xFFEDF2FF), size: 24),
            ),
            child: const SizedBox.expand(),
          ),
        ),
        const Positioned(
          left: 16,
          right: 16,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: IgnorePointer(
              child: Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Drag to explore · Tap to hide guides\n'
                  '4 / 7 / 12 items · 48 px bands',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    inherit: false,
                    color: Color(0xFFA6B2C8),
                    fontSize: 12,
                    height: 1.6,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
