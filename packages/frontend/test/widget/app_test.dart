import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:biolab_labsync/app.dart';

void main() {
  testWidgets('App renders correctly', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: BioLabApp()),
    );
    await tester.pump();
    expect(find.byType(BioLabApp), findsOneWidget);
  });
}
