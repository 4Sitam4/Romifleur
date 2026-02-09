void main() {
  final filenames = [
    'Mega Man X',
    'Mega Man Zero',
    'Megaman Battle Network', // Hypothetical, usually it's "Mega Man" everywhere but let's assume inconsistent naming or user input
    'Super Mario Bros',
  ];

  final queries = ['Megaman', 'Mega man', 'SuperMario', 'Super Mario'];

  print('Current Search Logic Check:');

  for (var query in queries) {
    print('\nQuery: "$query"');
    final queryLower = query.toLowerCase();
    for (var filename in filenames) {
      // Current Logic
      if (filename.toLowerCase().contains(queryLower)) {
        print('  MATCH: "$filename"');
      } else {
        // print('  NO MATCH: "$filename"');
      }
    }
  }

  print('\n--------------------------------------------------\n');
  print('Proposed "Normalization" Search Logic Check:');

  for (var query in queries) {
    print('\nQuery: "$query"');

    // Normalize: lowercase + remove formatting (spaces, dashes, etc)
    // RegExp(r'[^a-z0-9]') matches anything that is NOT a lowercase letter or number
    final queryNorm = query.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

    for (var filename in filenames) {
      final filenameNorm = filename.toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]'),
        '',
      );

      if (filenameNorm.contains(queryNorm)) {
        print('  MATCH: "$filename" (Normalized: $filenameNorm vs $queryNorm)');
      }
    }
  }
}
