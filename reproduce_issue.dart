void main() {
  final regions = ['Europe', 'USA', 'Japan', 'World'];

  final filenames = [
    'Grand Theft Auto - San Andreas (Japan) (Rockstar Classics)',
    'Grand Theft Auto - San Andreas (USA) (v3.00)',
    'Grand Theft Auto - San Andreas (Europe, Australia) (En,Fr,De,Es,It) (v1.03)',
    'Grand Theft Auto - San Andreas (Germany) (En,De) (v1.00)',
  ];

  print('Testing Region Filtering Logic...');

  // Simulate "All Regions Selected" - WITH FIX LOGIC
  final activeRegions = ['Europe', 'USA', 'Japan', 'World'];
  print('\nActive Regions: $activeRegions (Testing Fix Logic)');

  for (var filename in filenames) {
    bool regionMatch = false;
    for (var r in activeRegions) {
      // Logic: (Region) OR (Region, OR , Region, OR , Region)
      if (filename.contains('($r)') ||
          filename.contains('($r,') ||
          filename.contains(', $r,') ||
          filename.contains(', $r)') ||
          // Also check without space just in case
          filename.contains(',$r,') ||
          filename.contains(',$r)')) {
        regionMatch = true;
        break;
      }
    }
    print('"$filename" match? $regionMatch');
  }

  // Simulate "Only Europe Selected" - WITH FIX LOGIC
  final activeRegionsEurope = ['Europe'];
  print('\nActive Regions: $activeRegionsEurope (Testing Fix Logic)');

  for (var filename in filenames) {
    bool regionMatch = false;
    for (var r in activeRegionsEurope) {
      if (filename.contains('($r)') ||
          filename.contains('($r,') ||
          filename.contains(', $r,') ||
          filename.contains(', $r)') ||
          filename.contains(',$r,') ||
          filename.contains(',$r)')) {
        regionMatch = true;
        break;
      }
    }
    print('"$filename" match? $regionMatch');
  }
}
