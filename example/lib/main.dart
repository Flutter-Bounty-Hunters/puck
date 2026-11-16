import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:puck/puck.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as glass;

import 'layout_demo.dart' show MenuLayoutDemo;
import 'performance_monitor_menu.dart';
import 'menu_root_puck.dart';

const _devMenuColor = Color(0xFFB6FF00);

const _massiveMenuColor = Color(0xFFFF8500);

const _levelColors = [Color(0xFF2563EB), Color(0xFF008577), Color(0xFF7C3AED)];

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

const _themeSwatches = [
  (name: 'Red', color: Color(0xFFF04452)),
  (name: 'Orange', color: Color(0xFFFF8A34)),
  (name: 'Yellow', color: Color(0xFFF4C542)),
  (name: 'Green', color: Color(0xFF32B879)),
  (name: 'Blue', color: Color(0xFF3485FF)),
  (name: 'Violet', color: Color(0xFF9364F5)),
  (name: 'Pink', color: Color(0xFFEC5BA7)),
];

enum _DemoMenu { messenger, art, massive, performance, dev }

class PuckDemo extends StatefulWidget {
  const PuckDemo({super.key});
  @override
  State<PuckDemo> createState() => _PuckDemoState();
}

class _PuckDemoState extends State<PuckDemo>
    with SingleTickerProviderStateMixin
    implements PuckMenuListener {
  final _menuOrder = _DemoMenu.values.toList();
  final _menuControllers = {
    for (final menu in _DemoMenu.values) menu: PuckMenuController(),
  };
  bool _showDebugAnchors = false;
  bool _showMessenger = false;
  bool _showArtMenu = false;
  bool _showMassiveMenu = false;
  bool _showPerformanceMenu = false;
  bool _showDevMenu = false;
  bool _demonstratingMessenger = false;
  Timer? _messengerDemoTimer;
  bool _demoActivatedMessenger = false;
  late final AnimationController _messengerDemo = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..addListener(_animateMessengerDemo);
  Color? _themeColor;
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
    for (final controller in _menuControllers.values) {
      controller.addListener(this);
    }
    _messengerDemoTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || _tabIndex != 0) return;
      setState(() => _demonstratingMessenger = true);
      _messengerDemo.forward();
      _messengerDemoTimer = null;
    });
  }

  void _animateMessengerDemo() {
    if (!_demonstratingMessenger) return;
    setState(() {
      // Activation happens on release, after the approach, pause, and press.
      if (!_demoActivatedMessenger && _messengerDemo.value >= 1030 / 1500) {
        _demoActivatedMessenger = true;
        _showMessenger = true;
        _raiseMenu(_DemoMenu.messenger);
      }
      if (_messengerDemo.isCompleted) _demonstratingMessenger = false;
    });
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
    _cancelMessengerDemo();
    _keyboardFocus.unfocus();
    setState(() {
      _tabIndex = index;
      if (index == 1) _layoutVisited = true;
    });
  }

  @override
  void dispose() {
    _messengerDemoTimer?.cancel();
    _messengerDemo.dispose();
    for (final controller in _menuControllers.values) {
      controller.removeListener(this);
      controller.dispose();
    }
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

  void _cancelMessengerDemo() {
    _messengerDemoTimer?.cancel();
    _messengerDemoTimer = null;
    _messengerDemo.stop();
    _demonstratingMessenger = false;
  }

  void _toggleMessengerMenu() {
    _cancelMessengerDemo();
    setState(() {
      _showMessenger = !_showMessenger;
      if (_showMessenger) _raiseMenu(_DemoMenu.messenger);
    });
  }

  void _toggleArtMenu() {
    _cancelMessengerDemo();
    setState(() {
      _showArtMenu = !_showArtMenu;
      if (_showArtMenu) _raiseMenu(_DemoMenu.art);
    });
  }

  void _toggleMassiveMenu() {
    _cancelMessengerDemo();
    setState(() {
      _showMassiveMenu = !_showMassiveMenu;
      if (_showMassiveMenu) _raiseMenu(_DemoMenu.massive);
    });
  }

  void _togglePerformanceMenu() {
    _cancelMessengerDemo();
    setState(() {
      _showPerformanceMenu = !_showPerformanceMenu;
      if (_showPerformanceMenu) _raiseMenu(_DemoMenu.performance);
    });
  }

  void _toggleDevMenu() {
    _cancelMessengerDemo();
    setState(() {
      _showDevMenu = !_showDevMenu;
      if (_showDevMenu) _raiseMenu(_DemoMenu.dev);
    });
  }

  void _raiseMenu(_DemoMenu menu) {
    _menuOrder
      ..remove(menu)
      ..add(menu);
  }

  List<Widget> _orderedMenus(List<Widget> menus) => [
    for (final menu in _menuOrder) menus[menu.index],
  ];

  @override
  void onExpanding(PuckMenuController controller) {
    final menu = _menuControllers.entries
        .singleWhere((e) => e.value == controller)
        .key;
    if (_menuOrder.last != menu) setState(() => _raiseMenu(menu));
  }

  @override
  void onExpanded(PuckMenuController controller) {}
  @override
  void onCollapsing(PuckMenuController controller) {}
  @override
  void onCollapsed(PuckMenuController controller) {}
  @override
  void onDragStarted(PuckMenuController controller) {}
  @override
  void onDragReleased(PuckMenuController controller) {}
  @override
  void onSettled(PuckMenuController controller) {}

  ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _themeColor ?? Colors.black,
      brightness: brightness,
      dynamicSchemeVariant: _themeColor == null
          ? DynamicSchemeVariant.monochrome
          : DynamicSchemeVariant.tonalSpot,
    );
    final base = brightness == Brightness.dark
        ? const Color(0xFF111114)
        : Colors.white;
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: _themeColor == null
          ? base
          : Color.alphaBlend(_themeColor!.withValues(alpha: 0.10), base),
    );
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
    final pageTheme = _theme(brightness);
    final iconColor = _themeColor == null
        ? pageTheme.colorScheme.onSurface
        : pageTheme.colorScheme.primary;
    final glassSettings = LiquidGlassSettings.ios27Regular(
      brightness: brightness,
      tintAmount: 0.7,
    );
    final glassAppearance = LiquidGlassAppearance.ios27Regular(
      brightness: brightness,
      tint: _themeColor?.withValues(alpha: 0.28) ?? const Color(0x00808080),
    );
    return MaterialApp(
      title: 'Puck',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
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
        backgroundColor: _theme(_darkMode ? Brightness.dark : Brightness.light)
            .scaffoldBackgroundColor,
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          centerTitle: true,
          foregroundColor: iconColor,
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
              Center(
                child: _MenuToggles(
                  messengerVisible: _showMessenger,
                  messengerDemoProgress: _demonstratingMessenger
                      ? _messengerDemo.value
                      : null,
                  artMenuVisible: _showArtMenu,
                  massiveMenuVisible: _showMassiveMenu,
                  performanceMenuVisible: _showPerformanceMenu,
                  devMenuVisible: _showDevMenu,
                  onToggleDevMenu: _toggleDevMenu,
                  onTogglePerformanceMenu: _togglePerformanceMenu,
                  onToggleMassiveMenu: _toggleMassiveMenu,
                  activeRingColor: _themeColor ?? const Color(0xFFD1D5DB),
                  onToggleArtMenu: _toggleArtMenu,
                  onToggleMessenger: _toggleMessengerMenu,
                ),
              ),
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
          key: const ValueKey('puck-menu-overlays'),
          children: _orderedMenus([
            PuckMenu.singleLevel(
              visible: _showMessenger,
              key: const ValueKey('chat-menu'),
              controller: _menuControllers[_DemoMenu.messenger],
              id: 'demo-chat-right-column-v2',
              layout: const PuckMenuLayout(
                initialEdge: PuckEdge.right,
                initialVerticalAlignment: 0.25,
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
            PuckMenu.singleLevel(
              key: const ValueKey('art-menu'),
              controller: _menuControllers[_DemoMenu.art],
              id: 'demo-art-right-column-v2',
              visible: _showArtMenu,
              layout: const PuckMenuLayout(
                initialEdge: PuckEdge.right,
                initialVerticalAlignment: 0.40,
                levelRadius: 128,
                puckDiameter: 48,
              ),
              debug: PuckMenuDebug(showAnchors: _showDebugAnchors),
              rootPuck: const MenuRootPuck(
                key: ValueKey('art-root'),
                child: _ArtSpectrumSurface(
                  child: Icon(Icons.palette, color: Colors.white, size: 30),
                ),
              ),
              itemLayerBuilder: (context, child) => LiquidGlassLayer(
                settings: glassSettings,
                defaultAppearance: glassAppearance,
                child: child,
              ),
              puckItems: [
                LiquidGlass(
                  key: const ValueKey('art-brightness'),
                  appearance: glassAppearance,
                  shape: const LiquidOval(),
                  child: Material(
                    type: MaterialType.transparency,
                    child: IconButton(
                      tooltip: _darkMode
                          ? 'Art: switch to light mode'
                          : 'Art: switch to dark mode',
                      onPressed: () => setState(() => _darkMode = !_darkMode),
                      icon: Icon(
                        _darkMode ? Icons.light_mode : Icons.dark_mode,
                        color: iconColor,
                      ),
                    ),
                  ),
                ),
                for (final swatch in _themeSwatches)
                  _GlassThemeSwatch(
                    key: ValueKey('theme-${swatch.name}'),
                    name: swatch.name,
                    color: swatch.color,
                    selected: _themeColor == swatch.color,
                    brightness: _darkMode ? Brightness.dark : Brightness.light,
                    onTap: () => setState(() {
                      _themeColor = _themeColor == swatch.color
                          ? null
                          : swatch.color;
                    }),
                  ),
              ],
            ),
            PuckMenu.multiLevel(
              key: const ValueKey('example-menu'),
              controller: _menuControllers[_DemoMenu.massive],
              visible: _showMassiveMenu,
              id: 'demo-puck-right-column-v2',
              showRopes: false,
              debug: PuckMenuDebug(
                showLevelCurves: true,
                showAnchors: _showDebugAnchors,
              ),
              puckItems: [
                for (final (index, level) in _demoLevels.indexed)
                  [
                    for (final (icon, label) in level)
                      Material(
                        key: ValueKey(label),
                        color: _levelColors[index],
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: label,
                          onPressed: () => debugPrint('$label tapped'),
                          icon: Icon(icon, color: Colors.white),
                        ),
                      ),
                  ],
              ],
              rootPuck: const MenuRootPuck(
                key: ValueKey('massive-root'),
                child: Material(
                  color: _massiveMenuColor,
                  shape: CircleBorder(),
                  child: Icon(Icons.menu, color: Colors.white),
                ),
              ),
              layout: const PuckMenuLayout(
                initialEdge: PuckEdge.right,
                initialVerticalAlignment: 0.55,
                levelRadius: 80,
              ),
            ),
            PerformanceMonitorMenu(
              key: const ValueKey('performance-menu-container'),
              controller: _menuControllers[_DemoMenu.performance],
              visible: _showPerformanceMenu,
              active: _tabIndex == 0,
              showDebugAnchors: _showDebugAnchors,
            ),
            PuckMenu.singleLevel(
              key: const ValueKey('dev-menu'),
              controller: _menuControllers[_DemoMenu.dev],
              id: 'demo-dev-right-column-v2',
              visible: _showDevMenu,
              layout: const PuckMenuLayout(
                initialEdge: PuckEdge.right,
                initialVerticalAlignment: 0.85,
                levelRadius: 104,
                puckDiameter: 56,
              ),
              debug: PuckMenuDebug(showAnchors: _showDebugAnchors),
              rootPuck: const MenuRootPuck(
                key: ValueKey('dev-root'),
                child: Material(
                  color: _devMenuColor,
                  shape: CircleBorder(),
                  child: Icon(
                    Icons.code_rounded,
                    color: Color(0xFF142000),
                    size: 30,
                  ),
                ),
              ),
              puckItems: [
                _DevControlPuck(
                  key: const ValueKey('dev-brightness'),
                  keepGreen: true,
                  tooltip: _darkMode
                      ? 'Dev: switch to light mode'
                      : 'Dev: switch to dark mode',
                  selected: _darkMode,
                  onPressed: () => setState(() => _darkMode = !_darkMode),
                  icon: Icon(_darkMode ? Icons.light_mode : Icons.dark_mode),
                ),
                _DevControlPuck(
                  key: const ValueKey('dev-keyboard'),
                  tooltip: _keyboardFocus.hasFocus
                      ? 'Dev: hide keyboard'
                      : 'Dev: show keyboard',
                  selected: _keyboardFocus.hasFocus,
                  onPressed: _toggleKeyboard,
                  icon: _KeyboardDirectionIcon(
                    expanded: _keyboardFocus.hasFocus,
                  ),
                ),
                _DevControlPuck(
                  key: const ValueKey('dev-layout-guides'),
                  tooltip: _showDebugAnchors
                      ? 'Dev: hide layout guides'
                      : 'Dev: show layout guides',
                  selected: _showDebugAnchors,
                  onPressed: _toggleDebugAnchors,
                  icon: Icon(
                    _showDebugAnchors
                        ? Icons.bug_report
                        : Icons.bug_report_outlined,
                  ),
                ),
              ],
            ),
          ]),
        ),
      ),
    ],
  );
}

class _DevControlPuck extends StatelessWidget {
  const _DevControlPuck({
    super.key,
    required this.tooltip,
    required this.selected,
    required this.onPressed,
    required this.icon,
    this.keepGreen = false,
  });

  final String tooltip;
  final bool selected;
  final VoidCallback onPressed;
  final Widget icon;
  final bool keepGreen;

  @override
  Widget build(BuildContext context) => Material(
    color: _devMenuColor,
    shape: const CircleBorder(),
    child: IconButton(
      tooltip: tooltip,
      isSelected: selected,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: selected && !keepGreen
            ? const Color(0xFF142000)
            : Colors.transparent,
        foregroundColor: selected && !keepGreen
            ? _devMenuColor
            : const Color(0xFF142000),
        shape: const CircleBorder(),
      ),
      icon: icon,
    ),
  );
}

class _GlassThemeSwatch extends StatelessWidget {
  const _GlassThemeSwatch({
    super.key,
    required this.name,
    required this.color,
    required this.selected,
    required this.brightness,
    required this.onTap,
  });

  final String name;
  final Color color;
  final bool selected;
  final Brightness brightness;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => LiquidGlass(
    appearance: LiquidGlassAppearance.ios27Regular(
      brightness: brightness,
      tint: color.withValues(alpha: selected ? 0.85 : 0.28),
    ),
    shape: const LiquidOval(),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? Colors.white : Colors.transparent,
          width: 2,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: IconButton(
          tooltip: '$name theme',
          isSelected: selected,
          onPressed: onTap,
          icon: Icon(Icons.circle, color: color, size: 16),
          selectedIcon: const Icon(Icons.check_rounded, color: Colors.white),
        ),
      ),
    ),
  );
}

class _MenuToggles extends StatefulWidget {
  const _MenuToggles({
    required this.messengerVisible,
    required this.messengerDemoProgress,
    required this.onToggleMessenger,
    required this.artMenuVisible,
    required this.onToggleArtMenu,
    required this.activeRingColor,
    required this.massiveMenuVisible,
    required this.onToggleMassiveMenu,
    required this.performanceMenuVisible,
    required this.onTogglePerformanceMenu,
    required this.devMenuVisible,
    required this.onToggleDevMenu,
  });

  final bool messengerVisible;
  final double? messengerDemoProgress;
  final VoidCallback onToggleMessenger;
  final bool artMenuVisible;
  final VoidCallback onToggleArtMenu;
  final Color activeRingColor;
  final bool massiveMenuVisible;
  final VoidCallback onToggleMassiveMenu;
  final bool performanceMenuVisible;
  final VoidCallback onTogglePerformanceMenu;
  final bool devMenuVisible;
  final VoidCallback onToggleDevMenu;

  @override
  State<_MenuToggles> createState() => _MenuTogglesState();
}

class _MenuTogglesState extends State<_MenuToggles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _entrance,
    builder: (context, _) => _buildButtons(context),
  );

  Widget _buildButtons(BuildContext context) {
    const diameter = 56.0;
    const radius = 88.0;
    const extent = radius * 2 + diameter;
    return SizedBox.square(
      dimension: extent,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          const _MenuCircles(),
          for (var index = 0; index < 5; index++)
            Positioned(
              left:
                  radius +
                  radius * math.cos(-math.pi / 2 + index * 2 * math.pi / 5),
              top:
                  radius +
                  radius * math.sin(-math.pi / 2 + index * 2 * math.pi / 5),
              width: diameter,
              height: diameter,
              child: _MenuButtonEntrance(
                progress: ((_entrance.value * 1100 - 120 - index * 140) / 360)
                    .clamp(0.0, 1.0),
                child: index == 0
                    ? _MenuActivationButton(
                        key: const ValueKey('messenger-menu-toggle'),
                        active: widget.messengerVisible,
                        activeRingColor: widget.activeRingColor,
                        simulatedTapProgress: widget.messengerDemoProgress,
                        neutralInactive: false,
                        tooltip: widget.messengerVisible
                            ? 'Hide messenger menu'
                            : 'Show messenger menu',
                        accent: const Color(0xFF0084FF),
                        onPressed: widget.onToggleMessenger,
                        iconBuilder: (color) => CustomPaint(
                          painter: _ChatHeadRootPainter(
                            flat: true,
                            iconColor: color,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      )
                    : index == 1
                    ? _MenuActivationButton(
                        key: const ValueKey('art-menu-toggle'),
                        active: widget.artMenuVisible,
                        activeRingColor: widget.activeRingColor,
                        tooltip: widget.artMenuVisible
                            ? 'Hide art menu'
                            : 'Show art menu',
                        accent: const Color(0xFFFF28D0),
                        spectrum: true,
                        onPressed: widget.onToggleArtMenu,
                        iconBuilder: (color) => Icon(
                          widget.artMenuVisible
                              ? Icons.palette
                              : Icons.palette_outlined,
                          color: color,
                        ),
                      )
                    : index == 2
                    ? _MenuActivationButton(
                        key: const ValueKey('massive-menu-toggle'),
                        active: widget.massiveMenuVisible,
                        activeRingColor: widget.activeRingColor,
                        tooltip: widget.massiveMenuVisible
                            ? 'Hide massive menu'
                            : 'Show massive menu',
                        accent: _massiveMenuColor,
                        onPressed: widget.onToggleMassiveMenu,
                        iconBuilder: (color) =>
                            Icon(Icons.account_tree_rounded, color: color),
                      )
                    : index == 3
                    ? _MenuActivationButton(
                        key: const ValueKey('performance-menu-toggle'),
                        active: widget.performanceMenuVisible,
                        activeRingColor: widget.activeRingColor,
                        tooltip: widget.performanceMenuVisible
                            ? 'Hide performance menu'
                            : 'Show performance menu',
                        accent: performancePuckColor,
                        onPressed: widget.onTogglePerformanceMenu,
                        iconBuilder: (color) =>
                            Icon(Icons.speed_rounded, color: color),
                      )
                    : _MenuActivationButton(
                        key: const ValueKey('dev-menu-toggle'),
                        active: widget.devMenuVisible,
                        activeRingColor: widget.activeRingColor,
                        tooltip: widget.devMenuVisible
                            ? 'Hide dev menu'
                            : 'Show dev menu',
                        accent: _devMenuColor,
                        onPressed: widget.onToggleDevMenu,
                        iconBuilder: (color) =>
                            Icon(Icons.code_rounded, color: color),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MenuButtonEntrance extends StatelessWidget {
  const _MenuButtonEntrance({required this.progress, required this.child});

  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (progress == 0) return Offstage(child: child);
    return IgnorePointer(
      ignoring: progress < 1,
      child: Transform.scale(
        scale: Curves.easeOutBack.transform(progress),
        child: child,
      ),
    );
  }
}

class _ArtSpectrumSurface extends StatelessWidget {
  const _ArtSpectrumSurface({required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return ClipOval(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFF39CC),
                  Color(0xFF973CFF),
                  Color(0xFF4062FF),
                ],
              ),
            ),
          ),
          for (final (center, color) in const [
            (Alignment(-0.65, 0.85), Color(0xFF23EEFF)),
            (Alignment(0.8, 0.8), Color(0xFF7040FF)),
            (Alignment(0.85, -0.65), Color(0xFFFFB943)),
            (Alignment(-0.35, -0.85), Color(0xFFFF28D0)),
          ])
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: center,
                  radius: 0.9,
                  colors: [color, color, color.withValues(alpha: 0)],
                  stops: const [0, 0.35, 1],
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}

class _MenuActivationButton extends StatefulWidget {
  const _MenuActivationButton({
    super.key,
    required this.active,
    required this.activeRingColor,
    required this.tooltip,
    required this.accent,
    required this.onPressed,
    required this.iconBuilder,
    this.spectrum = false,
    this.neutralInactive = true,
    this.simulatedTapProgress,
  });

  final bool active;
  final Color activeRingColor;
  final String tooltip;
  final Color accent;
  final VoidCallback onPressed;
  final Widget Function(Color) iconBuilder;
  final bool spectrum;
  final bool neutralInactive;
  final double? simulatedTapProgress;

  @override
  State<_MenuActivationButton> createState() => _MenuActivationButtonState();
}

class _MenuActivationButtonState extends State<_MenuActivationButton> {
  final _states = WidgetStatesController();
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _states.addListener(_updatePressed);
  }

  void _updatePressed() {
    final pressed = _states.value.contains(WidgetState.pressed);
    if (pressed != _pressed) setState(() => _pressed = pressed);
  }

  @override
  void dispose() {
    _states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final demoTime = (widget.simulatedTapProgress ?? 0) * 1500;
    final simulatedPress = demoTime >= 820 && demoTime < 1030;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = widget.active
        ? Colors.white
        : widget.neutralInactive
        ? (dark ? const Color(0xFFD1D5DB) : performancePuckColor)
        : widget.accent;
    final background = widget.spectrum && widget.active
        ? Colors.transparent
        : widget.active
        ? widget.accent
        : dark
        ? const Color(0xFF29292E)
        : const Color(0xFFE5E7EB);
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(begin: foreground, end: foreground),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      builder: (context, iconColor, _) => TweenAnimationBuilder<Color?>(
        tween: ColorTween(begin: background, end: background),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        builder: (context, fillColor, _) => _buildSurface(
          iconColor ?? foreground,
          fillColor ?? background,
          simulatedPress,
        ),
      ),
    );
  }

  Widget _buildSurface(
    Color foreground,
    Color background,
    bool simulatedPress,
  ) {
    return Semantics(
      toggled: widget.active,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          if (widget.active)
            Positioned(
              left: -6,
              right: -6,
              top: -6,
              bottom: -6,
              child: IgnorePointer(
                child: DecoratedBox(
                  key: const ValueKey('active-menu-ring'),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: widget.activeRingColor, width: 2),
                  ),
                ),
              ),
            ),
          AnimatedScale(
            scale: _pressed || simulatedPress ? 0.88 : 1,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
            child: _ArtSpectrumSurface(
              enabled: widget.spectrum && widget.active,
              child: IconButton(
                tooltip: widget.tooltip,
                isSelected: widget.active,
                statesController: _states,
                onPressed: widget.onPressed,
                padding: EdgeInsets.zero,
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.pressed) ||
                        simulatedPress) {
                      return Color.alphaBlend(
                        foreground.withValues(alpha: 0.24),
                        background,
                      );
                    }
                    return background;
                  }),
                  foregroundColor: WidgetStatePropertyAll(foreground),
                  overlayColor: const WidgetStatePropertyAll(
                    Colors.transparent,
                  ),
                  shape: const WidgetStatePropertyAll(CircleBorder()),
                  side: const WidgetStatePropertyAll(BorderSide.none),
                ),
                icon: widget.iconBuilder(foreground),
              ),
            ),
          ),
          if (widget.simulatedTapProgress case final progress?)
            _SimulatedMenuTap(progress: progress),
        ],
      ),
    );
  }
}

class _SimulatedMenuTap extends StatelessWidget {
  const _SimulatedMenuTap({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final time = progress * 1500;
    final Offset offset;
    if (time < 320) {
      offset = Offset.lerp(
        const Offset(84, -64),
        const Offset(10, -8),
        Curves.easeOutCubic.transform(time / 320),
      )!;
    } else if (time < 600) {
      offset = Offset.lerp(
        const Offset(10, -8),
        Offset.zero,
        Curves.easeOutQuad.transform((time - 320) / 280),
      )!;
    } else {
      offset = Offset.zero;
    }
    final pressed = time >= 820 && time < 1030;
    final opacity = time < 1200 ? 1.0 : (1500 - time) / 300;
    return Positioned(
      left: 10 + offset.dx,
      top: 22 + offset.dy,
      width: 36,
      height: 36,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: Opacity(
            key: const ValueKey('messenger-tap-demo'),
            opacity: opacity.clamp(0.0, 1.0),
            child: AnimatedScale(
              scale: pressed ? 0.82 : 1,
              alignment: Alignment.topCenter,
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOutBack,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Color(0x33000000), blurRadius: 8),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(5),
                  child: Icon(Icons.touch_app, size: 26, color: Colors.black),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuCircles extends StatelessWidget {
  const _MenuCircles();
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Three menu circles',
    image: true,
    child: Icon(
      Icons.bubble_chart,
      size: 36,
      color: Theme.of(context).colorScheme.primary,
    ),
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
    return const MenuRootPuck(
      child: CustomPaint(
        painter: _ChatHeadRootPainter(),
        child: SizedBox.expand(),
      ),
    );
  }
}

class _ChatHeadRootPainter extends CustomPainter {
  const _ChatHeadRootPainter({
    this.flat = false,
    this.iconColor = Colors.white,
  });

  final bool flat;
  final Color iconColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    final bounds = Rect.fromCircle(center: center, radius: radius);

    if (!flat) {
      canvas.drawOval(
        bounds,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF00B2FF), Color(0xFF006AFF)],
          ).createShader(bounds),
      );
    }

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
      Paint()..color = iconColor,
    );
  }

  @override
  bool shouldRepaint(covariant _ChatHeadRootPainter oldDelegate) =>
      oldDelegate.flat != flat || oldDelegate.iconColor != iconColor;
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
