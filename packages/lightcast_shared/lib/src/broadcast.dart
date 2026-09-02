abstract interface class BroadcastEngine {
  Stream<String> get status;
  Future<void> configure(String streamKey);
  Future<void> start();
  Future<void> stop();
}

class MockBroadcastEngine implements BroadcastEngine {
  String _status = 'STANDBY';

  @override
  Stream<String> get status async* {
    yield _status;
  }

  @override
  Future<void> configure(String streamKey) async {}

  @override
  Future<void> start() async {
    _status = 'LIVE';
  }

  @override
  Future<void> stop() async {
    _status = 'STANDBY';
  }
}

class NativeBroadcastEngine implements BroadcastEngine {
  @override
  Stream<String> get status => const Stream<String>.empty();

  @override
  Future<void> configure(String streamKey) async {
    throw UnimplementedError('Connect this to a native RTMPS plugin.');
  }

  @override
  Future<void> start() async {
    throw UnimplementedError('Connect this to a native RTMPS plugin.');
  }

  @override
  Future<void> stop() async {}
}
