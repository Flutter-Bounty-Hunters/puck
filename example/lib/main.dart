import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:puck/puck.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as glass;

import 'layout_demo.dart' show MenuLayoutDemo;

const _demoLevels = [
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
  bool _layoutVisited = false;
  String? _selectedContact;
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  final _keyboardFocus = FocusNode(debugLabel: 'Puck keyboard toggle');

  @override
  void initState() {
    super.initState();
    _keyboardFocus.addListener(_keyboardChanged);
  }

  void _keyboardChanged() {
    if (mounted) setState(() {});
  }

  void _toggleKeyboard() {
    if (_keyboardFocus.hasFocus) {
      _keyboardFocus.unfocus();
    } else {
      _keyboardFocus.requestFocus();
    }
  }

  void _selectTab(int index) {
    _keyboardFocus.unfocus();
    setState(() {
      _tabIndex = index;
      if (index == 1) _layoutVisited = true;
    });
  }

  @override
  void dispose() {
    _keyboardFocus.removeListener(_keyboardChanged);
    _keyboardFocus.dispose();
    super.dispose();
  }

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
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
      ),
      themeMode: _darkMode || _tabIndex == 1 ? ThemeMode.dark : ThemeMode.light,
      // The standalone tab widget loads its shaders on demand. Do not add
      // initialization or shader warm-up ahead of the app's first frame.
      builder: (context, child) => glass.LiquidGlassWidgets.wrap(
        brightnessResolver: Theme.maybeBrightnessOf,
        theme: glass.GlassThemeData.ios26(
          brightness: _darkMode || _tabIndex == 1
              ? Brightness.dark
              : Brightness.light,
        ),
        child: child!,
      ),
      home: Scaffold(
        extendBody: true,
        resizeToAvoidBottomInset: false,
        body: IndexedStack(
          index: _tabIndex,
          children: [
            TickerMode(
              enabled: _tabIndex == 0,
              child: _examplePage(glassSettings, glassAppearance, iconColor),
            ),
            if (_layoutVisited)
              TickerMode(enabled: _tabIndex == 1, child: const MenuLayoutDemo())
            else
              const SizedBox.expand(),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          maintainBottomViewPadding: true,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: glass.GlassTabBar.bottom(
                selectedIndex: _tabIndex,
                onTabSelected: _selectTab,
                horizontalPadding: 12,
                verticalPadding: 12,
                tabs: const [
                  glass.GlassTab(
                    icon: Icon(Icons.bubble_chart_outlined),
                    activeIcon: Icon(Icons.bubble_chart),
                    label: 'Puck',
                  ),
                  glass.GlassTab(
                    icon: Icon(Icons.radar_outlined),
                    activeIcon: Icon(Icons.radar),
                    label: 'Layout',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _examplePage(
    LiquidGlassSettings glassSettings,
    LiquidGlassAppearance glassAppearance,
    Color iconColor,
  ) => Stack(
    fit: StackFit.expand,
    children: [
      Scaffold(
        key: const ValueKey('example-page'),
        backgroundColor: _darkMode ? const Color(0xFF111114) : Colors.white,
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          centerTitle: true,
          title: const Text(
            'PUCK',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            tooltip: _darkMode ? 'Switch to light mode' : 'Switch to dark mode',
            icon: Icon(_darkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => setState(() => _darkMode = !_darkMode),
          ),
          actions: [
            IconButton(
              tooltip: _keyboardFocus.hasFocus
                  ? 'Hide keyboard'
                  : 'Show keyboard',
              icon: _KeyboardDirectionIcon(expanded: _keyboardFocus.hasFocus),
              onPressed: _toggleKeyboard,
            ),
            IconButton(
              tooltip: _showDebugAnchors
                  ? 'Hide debug visuals'
                  : 'Show debug visuals',
              isSelected: _showDebugAnchors,
              icon: const Icon(Icons.bug_report_outlined),
              selectedIcon: const Icon(Icons.bug_report),
              onPressed: _toggleDebugAnchors,
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const Center(child: _MenuCircles()),
              Offstage(
                child: ExcludeSemantics(
                  child: TextField(
                    key: const ValueKey('keyboard-input'),
                    focusNode: _keyboardFocus,
                    textInputAction: TextInputAction.done,
                    enableInteractiveSelection: false,
                    onSubmitted: (_) => _keyboardFocus.unfocus(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      // Page-local overlays remain above their app bar and share the bottom
      // navigation's safe padding with the Layout explorer.
      SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            PuckMenu.singleLevel(
              key: const ValueKey('chat-menu'),
              id: 'demo-chat',
              layout: const PuckMenuLayout(
                initialEdge: PuckEdge.left,
                diameter: 64,
                levelRadius: 156,
                puckDiameter: 64,
              ),
              debug: PuckMenuDebug(showAnchors: _showDebugAnchors),
              puckItems: [
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
              rootPuck: const _ChatHeadRootPuck(key: ValueKey('chat-root')),
            ),
            PuckMenu.multiLevel(
              key: const ValueKey('example-menu'),
              id: 'demo-puck',
              showRopes: false,
              debug: PuckMenuDebug(
                showLevelCurves: true,
                showAnchors: _showDebugAnchors,
              ),
              puckItems: [
                for (final level in _demoLevels)
                  [
                    for (final (icon, label) in level)
                      LiquidGlass.withOwnLayer(
                        key: ValueKey(label),
                        settings: glassSettings,
                        appearance: glassAppearance,
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
              rootPuck: LiquidGlass.withOwnLayer(
                settings: glassSettings,
                appearance: glassAppearance,
                shape: const LiquidOval(),
                child: Icon(Icons.menu, color: iconColor),
              ),
              layout: const PuckMenuLayout(levelRadius: 80),
            ),
          ],
        ),
      ),
    ],
  );
}

class _MenuCircles extends StatelessWidget {
  const _MenuCircles();
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Three menu circles',
    image: true,
    child: const Icon(Icons.bubble_chart, size: 36, color: Color(0xFFD1D5DB)),
  );
}

class _KeyboardDirectionIcon extends StatelessWidget {
  const _KeyboardDirectionIcon({required this.expanded});

  final bool expanded;

  // Keep the keyboard upright in both states; only the direction changes.
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 26,
    height: 30,
    child: Stack(
      alignment: Alignment.topCenter,
      children: [
        const Icon(Icons.keyboard_outlined, size: 23),
        Positioned(
          bottom: -2,
          child: Icon(
            expanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
            size: 16,
          ),
        ),
      ],
    ),
  );
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
