import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A light at a measured, absolute logical screen position.
@immutable
class PuckLightSource {
  const PuckLightSource(this.position, this.intensity, this.color);

  final Offset position;
  final double intensity;
  final Color color;
}

/// Resolves one logical source even when the tab bar paints duplicate content.
class PuckLightAnchorHandle {
  PuckLightAnchorHandle({required this.intensity, this.color = Colors.white});

  final double intensity;
  final Color color;
  final _anchors = <_RenderPuckLightAnchor>{};

  PuckLightSource? get source {
    for (final anchor in _anchors) {
      if (!anchor.attached || !anchor.hasSize) {
        continue;
      }
      RenderBox target = anchor;
      if (anchor.wholeContent) {
        // The tab's content column contains its icon and label, rather than
        // the enclosing glass pill or its larger touch target.
        RenderObject? ancestor = anchor.parent;
        while (ancestor != null) {
          if (ancestor is RenderFlex && ancestor.direction == Axis.vertical) {
            target = ancestor;
            break;
          }
          ancestor = ancestor.parent;
        }
      }
      if (!target.hasSize || target.size.isEmpty) {
        continue;
      }
      final bounds = MatrixUtils.transformRect(
        target.getTransformTo(null),
        Offset.zero & target.size,
      );
      if (!bounds.center.dx.isFinite || !bounds.center.dy.isFinite) {
        continue;
      }
      return PuckLightSource(bounds.center, intensity, color);
    }
    return null;
  }
}

class PuckLightAnchor extends SingleChildRenderObjectWidget {
  const PuckLightAnchor({
    super.key,
    required this.handle,
    this.wholeContent = false,
    required super.child,
  });

  final PuckLightAnchorHandle handle;
  final bool wholeContent;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPuckLightAnchor(handle, wholeContent);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderPuckLightAnchor).configure(handle, wholeContent);
  }
}

class _RenderPuckLightAnchor extends RenderProxyBox {
  _RenderPuckLightAnchor(this.handle, this.wholeContent);

  PuckLightAnchorHandle handle;
  bool wholeContent;

  void configure(PuckLightAnchorHandle value, bool content) {
    if (handle != value) {
      handle._anchors.remove(this);
      handle = value;
      if (attached) {
        handle._anchors.add(this);
      }
    }
    wholeContent = content;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    handle._anchors.add(this);
  }

  @override
  void detach() {
    handle._anchors.remove(this);
    super.detach();
  }
}
