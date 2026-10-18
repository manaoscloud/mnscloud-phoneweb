import 'phone_bridge.dart';

/// Native builds are never embedded in the App: no bridge.
PhoneBridgeTransport? createEmbeddedBridgeTransport() => null;
