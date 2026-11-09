import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walkman/models/tape.dart';
import 'package:walkman/services/app_state.dart';
import 'package:walkman/services/collection_store.dart';
import 'package:walkman/screens/tapes_screen.dart';
import 'package:walkman/animations/tape_unbox_screen.dart';
import 'package:walkman/widgets/tape_3d.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<AppState> collection(CollectionStore store) async {
    final app = AppState(store: store);
    await app.load();
    for (final id in ['A', 'B', 'C']) {
      await app.saveTape(Tape(id: id, name: 'Fita $id', tracks: []));
    }
    return app;
  }

  test('Ordem persiste após reabrir e editar uma fita', () async {
    final store = CollectionStore(memory: true);
    final app = await collection(store);
    await app.moveTape('A', 'C');
    await app.moveTape('C', 'B');
    expect(app.tapes.map((t) => t.id), ['C', 'B', 'A']);
    final edited = app.tapes[1].copy()..name = 'Editada';
    await app.saveTape(edited);
    await app.moveTape('ausente', 'A');
    final reopened = AppState(store: store);
    await reopened.load();
    expect(reopened.tapes.map((t) => t.id), ['C', 'B', 'A']);
    expect(reopened.tapes[1].name, 'Editada');
    app.dispose();
    reopened.dispose();
  });
  testWidgets('Segurar sem arrastar abre inspeção 3D e preserva ordem',
      (tester) async {
    final app = await collection(CollectionStore(memory: true));
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(), home: Scaffold(body: TapesScreen(app: app))));
    await tester.pumpAndSettle();
    final press =
        await tester.startGesture(tester.getCenter(find.text('Fita A')));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(TapeModelView), findsOneWidget);
    await press.up();
    await tester.pump();
    expect(find.byTooltip('Fechar visualização'), findsOneWidget);
    expect(find.byType(TapeUnboxScreen), findsNothing);
    for (var i = 0; i < 30 && find.byType(Tape3D).evaluate().isEmpty; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await tester.pumpAndSettle();
    expect(find.byType(Tape3D), findsOneWidget);
    await tester.drag(find.byType(Tape3D), const Offset(70, 20));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Fechar visualização'));
    await tester.pumpAndSettle();
    expect(app.tapes.map((t) => t.id), ['A', 'B', 'C']);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });
  testWidgets('Segurar e arrastar muda a ordem sem abrir inspeção',
      (tester) async {
    final store = CollectionStore(memory: true);
    final app = await collection(store);
    await tester
        .pumpWidget(MaterialApp(home: Scaffold(body: TapesScreen(app: app))));
    await tester.pumpAndSettle();
    final target = tester.getCenter(find.text('Fita C'));
    final press =
        await tester.startGesture(tester.getCenter(find.text('Fita A')));
    await tester.pump(const Duration(milliseconds: 600));
    await press.moveTo(target);
    await tester.pump();
    await press.up();
    await tester.pumpAndSettle();
    expect(app.tapes.map((t) => t.id), ['B', 'C', 'A']);
    expect(find.byTooltip('Fechar visualização'), findsNothing);
    final reopened = AppState(store: store);
    await reopened.load();
    expect(reopened.tapes.map((t) => t.id), ['B', 'C', 'A']);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    app.dispose();
    reopened.dispose();
  });
}
