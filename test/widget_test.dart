import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:gestor_vehiculos/main.dart';

void main() {
  setUpAll(() {
    // La app lee config vía dotenv; en test la cargamos vacía para que no lance
    // NotInitializedError y corra en modo sin backend (no dispara sync/realtime).
    dotenv.testLoad(fileInput: '');
  });

  testWidgets('La app construye sin crashear', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: GestorVehiculosApp()),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
