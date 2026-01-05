import 'package:flutter_test/flutter_test.dart';
import 'package:indoornavigate/indoor_navigation.dart';

void main() {
  test('route exists from N001 to N003 (maps to N101..N103)', () {
    final nav = IndoorNavigation();
    final route = nav.calculateRoute('N001', 'N003');
    expect(route, isNotNull);
    // Legacy inputs N001..N012 map to N101..N112 in this building
    expect(route!.first, 'N101');
    expect(route.last, 'N103');
  });
}
