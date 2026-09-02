import 'models.dart';

abstract interface class CameraTransport {
  Stream<CameraSource> get status;
  Future<void> connect();
  Future<void> disconnect();
}

class MockCameraTransport implements CameraTransport {
  MockCameraTransport(this.source);
  final CameraSource source;

  @override
  Stream<CameraSource> get status async* {
    yield source;
  }

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}
}

abstract interface class CameraTransportFactory {
  CameraTransport create(CameraSource source);
}
