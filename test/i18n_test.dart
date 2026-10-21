import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnscloud_phoneweb/main.dart';
import 'package:mnscloud_phoneweb/src/access/access_preferences.dart';
import 'package:mnscloud_phoneweb/src/i18n/phoneweb_strings.dart';

void main() {
  tearDown(() => accessLocale.value = null);

  test('texts follow the chosen language and fill placeholders', () {
    accessLocale.value = const Locale('pt', 'BR');
    expect(tr('Accounts'), 'Contas');
    expect(tr('{name} added', {'name': 'Ramal 1001'}), 'Ramal 1001 adicionada');
    accessLocale.value = const Locale('es', 'ES');
    expect(tr('Contacts'), 'Contactos');
    accessLocale.value = const Locale('en', 'US');
    expect(tr('Contacts'), 'Contacts');
    expect(tr('Not translated yet'), 'Not translated yet');
  });

  testWidgets('the softphone redraws in the new language', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1700, 1000);
    addTearDown(tester.view.reset);
    accessLocale.value = const Locale('pt', 'BR');

    await tester.pumpWidget(const PhoneWebApp());
    expect(find.text('Contas'), findsOneWidget);
    expect(find.text('Discador'), findsOneWidget);
    expect(find.text('Mensagens'), findsOneWidget);
    expect(find.text('Agenda local'), findsNothing);

    accessLocale.value = const Locale('es', 'ES');
    WidgetsBinding.instance.rootElement?.visitChildren(_markDirty);
    await tester.pump();
    expect(find.text('Cuentas'), findsOneWidget);
    expect(find.text('Mensajes'), findsOneWidget);
  });
}

void _markDirty(Element element) {
  element.markNeedsBuild();
  element.visitChildren(_markDirty);
}
