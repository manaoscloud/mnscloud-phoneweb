import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'phone_bridge.dart';

/// `?embed=app` inside a frame of the same origin (the MNSCloud App dock).
/// Messages are accepted only from the parent window of this exact origin and
/// sent only to it.
PhoneBridgeTransport? createEmbeddedBridgeTransport() {
  if (Uri.base.queryParameters['embed'] != 'app') return null;
  final parent = web.window.parent;
  if (parent == null || parent == web.window) return null;
  return _WebBridgeTransport(parent);
}

class _WebBridgeTransport implements PhoneBridgeTransport {
  _WebBridgeTransport(this._parent) {
    _listener = ((web.MessageEvent event) {
      if (event.origin != _origin) return;
      final source = event.source;
      if (source == null || !source.strictEquals(_parent).toDart) {
        return;
      }
      final data = event.data.dartify();
      if (data is Map) _controller.add(data.cast<String, Object?>());
    }).toJS;
    web.window.addEventListener('message', _listener);
  }

  final web.Window _parent;
  final String _origin = web.window.location.origin;
  final _controller = StreamController<Map<String, Object?>>.broadcast();
  late final JSFunction _listener;

  @override
  Stream<Map<String, Object?>> get incoming => _controller.stream;

  @override
  void send(Map<String, Object?> message) {
    _parent.postMessage(message.jsify(), _origin.toJS);
  }
}
