import 'package:flutter_test/flutter_test.dart';
import 'package:share_up_front/app.dart';

void main() {
  testWidgets('ShareUp app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const ShareUpApp());

    // Vérifie que l'app démarre sans crash
    expect(find.byType(ShareUpApp), findsOneWidget);
  });
}
