import 'package:flutter_test/flutter_test.dart';
import 'package:mnscloud_phoneweb/main.dart';

void main() {
  testWidgets('renders the PhoneWeb account shell', (tester) async {
    await tester.pumpWidget(const PhoneWebApp());

    expect(find.text('MNSCloud PhoneWeb'), findsOneWidget);
    expect(find.text('Accounts'), findsOneWidget);
    expect(find.text('Dialer'), findsOneWidget);
    expect(find.text('No WebRTC accounts'), findsOneWidget);
  });
}
