import 'package:flutter_test/flutter_test.dart';
import 'package:biolab_labsync/app.dart';

void main() {
  testWidgets('App renders correctly', (tester) async {
    await tester.pumpWidget(const BioLabApp());
    expect(find.text('BioLab LABSYNC Enterprise'), findsOneWidget);
  });
}
