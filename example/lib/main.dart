import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:puck/puck.dart';

void main() => runApp(const PuckDemo());

const _chatContacts = [
  (name: 'Maya', asset: 'assets/avatars/maya.jpg'),
  (name: 'Liam', asset: 'assets/avatars/liam.jpg'),
  (name: 'Sofia', asset: 'assets/avatars/sofia.jpg'),
  (name: 'Noah', asset: 'assets/avatars/noah.jpg'),
];

class PuckDemo extends StatefulWidget {
  const PuckDemo({super.key});

  @override
  State<PuckDemo> createState() => _PuckDemoState();
}

class _PuckDemoState extends State<PuckDemo> {
  bool _showDebugAnchors = false;
  bool _darkMode = false;
  String? _selectedContact;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final contact in _chatContacts) {
      precacheImage(AssetImage(contact.asset), context);
    }
  }

  void _toggleDebugAnchors() {
    setState(() => _showDebugAnchors = !_showDebugAnchors);
  }

  void _showStatus(BuildContext scaffoldContext, String message) {
    debugPrint(message);
    ScaffoldMessenger.of(scaffoldContext)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

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
          child: Builder(
            builder: (scaffoldContext) => Stack(
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
                            'Drag or fling a puck.\nTap to open or close its menu.\nLong-press to toggle anchor dots.',
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 24),
                          TextField(
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                              labelText: 'Keyboard test',
                              hintText: 'Tap to open the keyboard',
                              helperText:
                                  'Drag a puck to the keyboard boundary.',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                PuckOverlay(
                  initialEdge: PuckEdge.left,
                  diameter: 64,
                  menuRadius: 156,
                  menuItemDiameter: 64,
                  showDebugAnchors: _showDebugAnchors,
                  onLongPress: _toggleDebugAnchors,
                  menuItems: [
                    for (final contact in _chatContacts)
                      _ChatHeadAvatar(
                        key: ValueKey(contact.name),
                        name: contact.name,
                        asset: contact.asset,
                        selected: _selectedContact == contact.name,
                        onTap: () {
                          setState(() => _selectedContact = contact.name);
                          _showStatus(
                            scaffoldContext,
                            'Chatting with ${contact.name}',
                          );
                        },
                      ),
                    _ChatHeadOverflowPuck(
                      key: const ValueKey('more_chats'),
                      onTap: () {
                        setState(() => _selectedContact = null);
                        _showStatus(scaffoldContext, 'More conversations');
                      },
                    ),
                  ],
                  puck: const _ChatHeadRootPuck(),
                  child: const SizedBox.expand(),
                ),
                // The menu items share a backdrop sample. The parent has its
                // own layer so its glass paints above the items and their icons.
                LiquidGlassLayer(
                  settings: glassSettings,
                  defaultAppearance: glassAppearance,
                  child: PuckOverlay(
                    showRopes: true,
                    showDebugAnchors: _showDebugAnchors,
                    onLongPress: _toggleDebugAnchors,
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
      ),
    );
  }
}

/// Opaque root puck styled after the classic Facebook Messenger chat head.
class _ChatHeadRootPuck extends StatelessWidget {
  const _ChatHeadRootPuck();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      painter: _ChatHeadRootPainter(),
      child: SizedBox.expand(),
    );
  }
}

class _ChatHeadRootPainter extends CustomPainter {
  const _ChatHeadRootPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    final bounds = Rect.fromCircle(center: center, radius: radius);

    canvas.drawOval(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF00B2FF), Color(0xFF006AFF)],
        ).createShader(bounds),
    );

    final bubbleCenter = Offset(center.dx, center.dy - radius * 0.04);
    final oval = Path()
      ..addOval(
        Rect.fromCenter(
          center: bubbleCenter,
          width: radius * 1.08,
          height: radius * 0.98,
        ),
      );
    final tail = Path()
      ..moveTo(center.dx - radius * 0.27, center.dy + radius * 0.20)
      ..lineTo(center.dx - radius * 0.27, center.dy + radius * 0.50)
      ..quadraticBezierTo(
        center.dx - radius * 0.27,
        center.dy + radius * 0.55,
        center.dx - radius * 0.21,
        center.dy + radius * 0.52,
      )
      ..lineTo(center.dx - radius * 0.05, center.dy + radius * 0.42)
      ..lineTo(center.dx - radius * 0.05, center.dy + radius * 0.20)
      ..close();
    final bubble = Path.combine(PathOperation.union, oval, tail);

    final cy = bubbleCenter.dy;
    final bolt = Path()
      ..moveTo(center.dx - radius * 0.31, cy + radius * 0.15)
      ..lineTo(center.dx - radius * 0.05, cy - radius * 0.16)
      ..lineTo(center.dx + radius * 0.08, cy - radius * 0.03)
      ..lineTo(center.dx + radius * 0.31, cy - radius * 0.16)
      ..lineTo(center.dx + radius * 0.05, cy + radius * 0.15)
      ..lineTo(center.dx - radius * 0.08, cy + radius * 0.02)
      ..close();

    canvas.drawPath(
      Path.combine(PathOperation.difference, bubble, bolt),
      Paint()..color = Colors.white,
    );

    canvas.drawCircle(
      center,
      radius - 1.75,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );
    canvas.drawCircle(
      center,
      radius - 0.4,
      Paint()
        ..color = const Color(0x2E000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(covariant _ChatHeadRootPainter oldDelegate) => false;
}

class _ChatHeadAvatar extends StatelessWidget {
  const _ChatHeadAvatar({
    super.key,
    required this.name,
    required this.asset,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String asset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ringColor = selected ? const Color(0xFF0084FF) : Colors.white;
    return ColoredBox(
      color: Colors.white,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            asset,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
          ),
          Material(
            type: MaterialType.transparency,
            child: Tooltip(
              message: 'Chat with $name',
              child: InkWell(onTap: onTap),
            ),
          ),
          IgnorePointer(
            child: CustomPaint(
              painter: _AvatarRingPainter(ringColor: ringColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// Overflow puck at the end of the chat heads arc for contacts outside recents.
class _ChatHeadOverflowPuck extends StatelessWidget {
  const _ChatHeadOverflowPuck({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: ClipOval(
        child: Material(
          color: const Color(0xFF0084FF),
          child: Tooltip(
            message: 'More conversations',
            child: InkWell(
              onTap: onTap,
              child: const Center(
                child: Icon(
                  Icons.more_horiz_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarRingPainter extends CustomPainter {
  const _AvatarRingPainter({required this.ringColor});

  final Color ringColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    canvas.drawCircle(
      center,
      radius - 1.5,
      Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0,
    );
    canvas.drawCircle(
      center,
      radius - 0.4,
      Paint()
        ..color = const Color(0x2E000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(covariant _AvatarRingPainter oldDelegate) =>
      oldDelegate.ringColor != ringColor;
}
