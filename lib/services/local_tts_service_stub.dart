// Stub classes for web compatibility
class FlutterSoundPlayer {
  Future<void> openPlayer() async {}
  Future<void> closePlayer() async {}
  Future<void> startPlayer({String? fromURI, dynamic codec}) async {}
  Future<void> stopPlayer() async {}
}

class Codec {
  static const mp3 = 'mp3';
  static const pcm16WAV = 'wav';
}

class Directory {
  final String path;
  Directory(this.path);

  Future<bool> exists() async => false;
  Future<void> create({bool recursive = false}) async {}
  Future<void> delete({bool recursive = false}) async {}
  Stream<dynamic> list() => Stream.empty();
}

class File {
  final String path;
  File(this.path);

  Future<bool> exists() async => false;
  Future<void> writeAsBytes(List<int> bytes) async {}
  Future<int> length() async => 0;
}

Future<Directory> getApplicationDocumentsDirectory() async {
  return Directory('/');
}
