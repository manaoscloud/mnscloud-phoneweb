import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mnscloud_phoneweb/main.dart';

void main() {
  testWidgets('renders the PhoneWeb account shell', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PhoneWebApp());

    expect(find.text('MNSCloud PhoneWeb'), findsOneWidget);
    expect(find.text('Accounts'), findsOneWidget);
    expect(find.text('Dialer'), findsOneWidget);
    expect(find.text('No WebRTC accounts'), findsOneWidget);
  });
}
