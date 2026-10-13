import 'package:flutter_test/flutter_test.dart';
import 'package:opencanvasx/src/editor/command_palette.dart';

void main() {
  PaletteCommand c(String label, {String keywords = ''}) =>
      PaletteCommand(label, () {}, keywords: keywords);

  test('fuzzy matching prefers word starts and consecutive letters', () {
    expect(fuzzyScore('xyz', 'Group'), isNull);
    expect(fuzzyScore('', 'Group'), 0);
    expect(
      fuzzyScore('grp', 'Group'),
      greaterThan(fuzzyScore('grp', 'Bring forward page')!),
    );
    final results = searchCommands([
      c('Send backward'),
      c('Bring to front'),
      c('Delete', keywords: 'remove'),
      c('Bring forward'),
    ], 'bf');
    expect(results.first.label, 'Bring forward');
    expect(
      searchCommands([
        c('Group'),
        c('Delete', keywords: 'remove'),
      ], 'remove').single.label,
      'Delete',
    );
  });
}
