part of 'puck_menu.dart';

/// The menu's animation state, independently of dragging and docking.
enum PuckMenuStatus { collapsed, expanding, expanded, collapsing }

/// Receives lifecycle callbacks from a [PuckMenuController].
///
/// The controller's state is updated before each callback. Expansion completes
/// when all item springs arrive; collapse completes when all items are hidden
/// beneath the root. Interrupted transitions do not report completion.
abstract interface class PuckMenuListener {
  void onExpanding(PuckMenuController controller);
  void onExpanded(PuckMenuController controller);
  void onCollapsing(PuckMenuController controller);
  void onCollapsed(PuckMenuController controller);
  void onDragStarted(PuckMenuController controller);

  /// Called on release or cancellation of an actual drag, never on a tap.
  void onDragReleased(PuckMenuController controller);

  /// Called when the root finishes docking, independently of item animation.
  void onSettled(PuckMenuController controller);
}

/// Opens and closes one [PuckMenu] and reports its lifecycle to listeners.
///
/// Commands issued before attachment are retained. Repeated requests for the
/// current destination do nothing. A controller can attach to only one overlay
/// at a time. Its owner is responsible for disposing it.
class PuckMenuController {
  final _listeners = <PuckMenuListener>[];
  Object? _owner;
  ValueChanged<bool>? _request;
  bool _requestedExpanded = false;
  bool _disposed = false;
  PuckMenuStatus _status = PuckMenuStatus.collapsed;
  bool _isDragging = false;
  bool _isSettled = true;

  PuckMenuStatus get status => _status;
  bool get isAttached => _owner != null;
  bool get isDragging => _isDragging;
  bool get isSettled => _isSettled;

  void addListener(PuckMenuListener listener) {
    _checkNotDisposed();
    if (!_listeners.contains(listener)) _listeners.add(listener);
  }

  void removeListener(PuckMenuListener listener) => _listeners.remove(listener);
  void open() => _command(true);
  void close() => _command(false);

  void _checkNotDisposed() {
    if (_disposed) throw StateError('PuckMenuController has been disposed.');
  }

  void _command(bool expanded) {
    _checkNotDisposed();
    _requestedExpanded = expanded;
    _request?.call(expanded);
  }

  void _attach(Object owner, ValueChanged<bool> request) {
    _checkNotDisposed();
    if (_owner != null && !identical(_owner, owner)) {
      throw StateError('A PuckMenuController can control only one menu.');
    }
    _owner = owner;
    _request = request;
  }

  void _detach(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    _request = null;
  }

  void _notify(void Function(PuckMenuListener) callback) {
    if (_disposed || _owner == null) return;
    for (final listener in List<PuckMenuListener>.of(_listeners)) {
      if (!_listeners.contains(listener)) continue;
      try {
        callback(listener);
      } catch (error, stack) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'puck',
            context: ErrorDescription('while notifying a PuckMenuListener'),
          ),
        );
      }
    }
  }

  void _expanding() {
    _requestedExpanded = true;
    _status = PuckMenuStatus.expanding;
    _notify((listener) => listener.onExpanding(this));
  }

  void _expanded() {
    _status = PuckMenuStatus.expanded;
    _notify((listener) => listener.onExpanded(this));
  }

  void _collapsing() {
    _requestedExpanded = false;
    _status = PuckMenuStatus.collapsing;
    _notify((listener) => listener.onCollapsing(this));
  }

  void _collapsed() {
    _status = PuckMenuStatus.collapsed;
    _notify((listener) => listener.onCollapsed(this));
  }

  void _dragStarted() {
    _isDragging = true;
    _isSettled = false;
    _notify((listener) => listener.onDragStarted(this));
  }

  void _dragReleased() {
    _isDragging = false;
    _notify((listener) => listener.onDragReleased(this));
  }

  void _settled() {
    _isDragging = false;
    _isSettled = true;
    _notify((listener) => listener.onSettled(this));
  }

  void dispose() {
    _disposed = true;
    _owner = null;
    _request = null;
    _listeners.clear();
  }
}
