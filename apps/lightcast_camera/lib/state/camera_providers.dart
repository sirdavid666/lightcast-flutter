import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lightcast_shared/lightcast_shared.dart';

enum CameraRole { pastor, crowd }

class CameraState {
  const CameraState({
    this.role,
    this.connected = false,
    this.batteryPercent = 84,
    this.signalPercent = 92,
  });

  final CameraRole? role;
  final bool connected;
  final int batteryPercent;
  final int signalPercent;

  CameraState copyWith({
    CameraRole? role,
    bool? connected,
    int? batteryPercent,
    int? signalPercent,
  }) =>
      CameraState(
        role: role ?? this.role,
        connected: connected ?? this.connected,
        batteryPercent: batteryPercent ?? this.batteryPercent,
        signalPercent: signalPercent ?? this.signalPercent,
      );
}

final cameraProvider =
    StateNotifierProvider<CameraController, CameraState>((ref) => CameraController());

class CameraController extends StateNotifier<CameraState> {
  CameraController() : super(const CameraState());

  void selectRole(CameraRole role) => state = state.copyWith(role: role);
  void clearRole() => state = const CameraState();
  void toggleConnection() => state = state.copyWith(connected: !state.connected);

  CameraSource get source => CameraSource(
        id: state.role == CameraRole.pastor ? 'pastor' : 'crowd',
        label: state.role == CameraRole.pastor ? 'Pastor Camera' : 'Crowd Camera',
        role: state.role == CameraRole.pastor ? 'Pastor' : 'Crowd',
        status: state.connected ? 'connected' : 'offline',
        batteryPercent: state.batteryPercent,
        signalPercent: state.signalPercent,
      );
}
