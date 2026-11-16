![Puck](https://gist.githubusercontent.com/matthew-carroll/404783cc39137527233a0b2c9d256040/raw/6f0fc1921fa44a40b5a74a43c3b476ad3b9b3a88/puck-banner.png)

<h1 align="center">Puck</h1>

<p align="center">
  A Floating Menu for Flutter
</p>

<p align="center">
  <a href="https://pub.dev/packages/puck"><img src="https://img.shields.io/pub/v/puck" alt="Pub Version"></a>
  <a href="https://github.com/Flutter-Bounty-Hunters/puck/actions/workflows/ci.yaml"><img src="https://github.com/Flutter-Bounty-Hunters/puck/actions/workflows/ci.yaml/badge.svg" alt="CI"></a>
  <a href="https://pub.dev/packages/puck/score"><img src="https://img.shields.io/pub/points/puck" alt="Pub Points"></a>
  <a href="https://pub.dev/packages/puck"><img src="https://img.shields.io/pub/likes/puck" alt="Pub Likes"></a>
  <a href="https://pub.dev/packages/puck"><img src="https://img.shields.io/pub/dm/puck" alt="Pub Downloads"></a>
  <a href="https://github.com/Flutter-Bounty-Hunters/puck/blob/main/LICENSE"><img src="https://img.shields.io/github/license/Flutter-Bounty-Hunters/puck" alt="License"></a>
</p>

---

<img align="left" src="https://github.com/user-attachments/assets/deecb815-043f-48f9-b5d0-c2ea6f6f3766" width="320" hspace="32" alt="Puck demo" />

### A Menu Where You Need It!
 * Anchor to the left or right edge of the screen.
 * Drag around your obstacles.
 * Expand your menu when needed.
 * Menu layout optimizes for available space.
 * Menu avoids the keyboard when up, and moves back when down.
 * Use a menu for quick theme checks, layout debugging, etc.

<br clear="all" />
<br />

Put your app's actions within reach with a floating menu people can move.
Tap to reveal actions, drag the puck to a comfortable spot, and release it to
spring back to the nearest screen edge.

- **One level or several.** Start with a few actions or spread them across multiple levels.
- **Adapts to the space.** Menu arcs adjust around screen edges, safe areas, and the keyboard.
- **Your widgets, your style.** Build the root and items from icons, photos, glass, or any Flutter widgets.
- **Spring animation.** Items fan out and return beneath the root, with staggered motion across levels.
- **Remembers its place.** Give a menu an `id` to restore its last docked position, even after an app restart.

## Add a floating menu

Place Puck above your page and supply the widgets for your actions:

```dart
import 'package:puck/puck.dart';

Stack(
  children: [
    yourPageContent,
    Positioned.fill(
      child: SafeArea(
        child: PuckMenu.singleLevel(
          rootPuck: yourMenuButton,
          puckItems: [searchButton, favoritesButton, shareButton],
        ),
      ),
    ),
  ],
)
```
