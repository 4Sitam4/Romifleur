import 'package:romifleur/models/game_metadata.dart';

abstract class MetadataProvider {
  String get name;
  Future<GameMetadata?> search(String gameName, String consoleKey);
}
