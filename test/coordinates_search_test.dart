// Issue #22: a decimal latitude/longitude pair typed or pasted into the
// search offers a "Go to" row (trufi-core#1015). The app is Arabic by
// default, so the spellings a Sana'a user pastes from an Arabic UI must
// parse too: the Arabic comma and Arabic-Indic digits (the parser
// normalises them; this pins it on the coordinates of issue #16).
import 'package:flutter_test/flutter_test.dart';
import 'package:trufi_core_search_locations/trufi_core_search_locations.dart';

void main() {
  const darSalm = ParsedCoordinates(15.28064, 44.24430);

  test('ASCII, with and without a space after the comma', () {
    expect(CoordinateParser.parse('15.28064, 44.24430'), darSalm);
    expect(CoordinateParser.parse('15.28064,44.24430'), darSalm);
  });

  test('the Arabic comma and the Arabic decimal separator', () {
    expect(CoordinateParser.parse('15.28064، 44.24430'), darSalm);
    expect(CoordinateParser.parse('15٫28064، 44٫24430'), darSalm);
  });

  test('Arabic-Indic digits, as copied from an Arabic app', () {
    expect(CoordinateParser.parse('١٥٫٢٨٠٦٤، ٤٤٫٢٤٤٣٠'), darSalm);
  });

  test('a street name with numbers is not a pair', () {
    expect(CoordinateParser.parse('شارع 45'), isNull);
    expect(CoordinateParser.parse('شارع 14'), isNull);
  });
}
