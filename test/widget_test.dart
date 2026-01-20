import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestor_vehiculos/main.dart';

void main() {
  testWidgets('App should build', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: GestorVehiculosApp(),
      ),
    );
    
    // Verificar que la app se construye correctamente
    expect(find.text('Gestor de'), findsOneWidget);
  });
}
