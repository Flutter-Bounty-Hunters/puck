import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:puck/puck.dart';

import 'prepared_menu_glass_layer.dart';
import 'layout_demo.dart' show MenuLayoutDemo;

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
  int _tabIndex = 0;
  int _layoutReset = 0;
  String? _selectedContact;
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

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

  void _showStatus(String message) {
    debugPrint(message);
    final messenger = _messengerKey.currentState;
    if (messenger == null) return;
    messenger
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
      tint: const Color(0x00808080),
    );
    return MaterialApp(
      title: 'Puck',
      scaffoldMessengerKey: _messengerKey,
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
      ),
      themeMode: _darkMode || _tabIndex == 1 ? ThemeMode.dark : ThemeMode.light,
      // Keep the menu above the Navigator, including its app bars and dialogs.
      builder: (context, child) => Overlay.wrap(
        child: Stack(
          fit: StackFit.expand,
          children: [
            child!,
            IndexedStack(
              index: _tabIndex,
              children: [
                TickerMode(
                  enabled: _tabIndex == 0,
                  child: SafeArea(
                    child: PuckOverlay(
                      key: const ValueKey('example-menu'),
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
                      onLongPress: _toggleDebugAnchors,
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
                                    onPressed: () =>
                                        debugPrint('$label tapped'),
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
                      child: PuckOverlay(
                        key: const ValueKey('chat-menu'),
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
                                _showStatus('Chatting with ${contact.name}');
                              },
                            ),
                          _ChatHeadOverflowPuck(
                            key: const ValueKey('more_chats'),
                            onTap: () {
                              setState(() => _selectedContact = null);
                              _showStatus('More conversations');
                            },
                          ),
                        ],
                        puck: const _ChatHeadRootPuck(
                          key: ValueKey('chat-root'),
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
                TickerMode(
                  enabled: _tabIndex == 1,
                  child: MenuLayoutDemo(
                    key: ValueKey(_layoutReset),
                    embedded: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      home: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: _tabIndex == 1 ? const Color(0xFF101722) : null,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: const Text('Puck playground'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: _tabIndex == 1
                ? null
                : IconButton(
                    tooltip: _darkMode
                        ? 'Switch to light mode'
                        : 'Switch to dark mode',
                    icon: Icon(_darkMode ? Icons.light_mode : Icons.dark_mode),
                    onPressed: () => setState(() => _darkMode = !_darkMode),
                  ),
            actions: [
              if (_tabIndex == 1)
                IconButton(
                  tooltip: 'Reset layout',
                  icon: const Icon(Icons.restart_alt),
                  onPressed: () => setState(() => _layoutReset++),
                ),
              if (_tabIndex == 0)
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
            bottom: TabBar(
              tabs: const [
                Tab(text: 'Example'),
                Tab(text: 'Layout'),
              ],
              onTap: (index) {
                FocusManager.instance.primaryFocus?.unfocus();
                setState(() => _tabIndex = index);
              },
            ),
          ),
          body: _tabIndex == 1
              ? const SizedBox.expand()
              : SafeArea(
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
                ),
        ),
      ),
    );
  }
}

/// Opaque root puck styled after the classic Facebook Messenger chat head.
class _ChatHeadRootPuck extends StatelessWidget {
  const _ChatHeadRootPuck({super.key});

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
