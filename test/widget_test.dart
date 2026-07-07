// Basic smoke test for JobTrackr.
import 'package:flutter_test/flutter_test.dart';

import 'package:jobtrackr/main.dart';

void main() {
  testWidgets('App boots', (WidgetTester tester) async {
    await tester.pumpWidget(const JobTrackrApp());
    // Just ensure the title is present.
    expect(find.text('JobTrackr'), findsWidgets);
  });
}
