// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:litly_mobile/main.dart';

void main() {
  testWidgets('O ecrã de login carrega com sucesso', (WidgetTester tester) async {
    // 1. Carregar a tua aplicação principal (agora LitlyApp)
    await tester.pumpWidget(const LitlyApp());

    // 2. Verificar se o texto "LITLY" aparece no ecrã (que está no LoginScreen)
    expect(find.text('LITLY'), findsOneWidget);

    // 3. Verificar se os campos de texto do login existem
    expect(find.byType(TextField), findsWidgets);
  });
}
