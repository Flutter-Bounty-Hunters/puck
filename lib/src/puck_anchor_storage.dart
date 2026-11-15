import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'puck_menu.dart' show PuckEdge;

typedef SavedPuckAnchor = ({PuckEdge edge, double verticalAlignment});

/// Internal storage for opt-in menu anchors. Not part of the package API.
class PuckAnchorStorage {
  static final _anchors = <String, SavedPuckAnchor>{};
  static final _writes = <String, Future<void>>{};

  static SavedPuckAnchor? cached(String id) => _anchors[id];

  static Future<SavedPuckAnchor?> read(String id) async {
    final cached = _anchors[id];
    if (cached != null) return cached;
    try {
      final raw = await SharedPreferencesAsync().getString(_key(id));
      if (raw == null) return null;
      final data = jsonDecode(raw);
      if (data is! Map) return null;
      final edge = switch (data['edge']) {
        'left' => PuckEdge.left,
        'right' => PuckEdge.right,
        _ => null,
      };
      final alignment = data['verticalAlignment'];
      if (edge == null ||
          alignment is! num ||
          !alignment.isFinite ||
          alignment < 0 ||
          alignment > 1) {
        return null;
      }
      // A release/save that happened during the read is newer than disk data.
      return _anchors.putIfAbsent(
        id,
        () => (edge: edge, verticalAlignment: alignment.toDouble()),
      );
    } catch (error) {
      debugPrint('Puck could not restore its anchor: $error');
      return null;
    }
  }

  static void save(String id, SavedPuckAnchor anchor) {
    if (_anchors[id] == anchor) return;
    // Make navigation/remounting see the new anchor before disk I/O completes.
    _anchors[id] = anchor;
    final previous = _writes[id] ?? Future<void>.value();
    final write = previous.then((_) async {
      try {
        await SharedPreferencesAsync().setString(
          _key(id),
          jsonEncode({
            'edge': anchor.edge.name,
            'verticalAlignment': anchor.verticalAlignment,
          }),
        );
      } catch (error) {
        debugPrint('Puck could not save its anchor: $error');
      }
    });
    _writes[id] = write;
    unawaited(
      write.whenComplete(() {
        if (identical(_writes[id], write)) _writes.remove(id);
      }),
    );
  }

  static String _key(String id) => 'puck.anchor.v1.$id';

  @visibleForTesting
  static void resetCache() {
    _anchors.clear();
    _writes.clear();
  }
}
