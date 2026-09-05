# LightCast

Android-first church livestream production foundation built with Flutter.

This repository contains two APK targets and one shared Dart package:

| Target | Package ID | Output |
| --- | --- | --- |
| Director | `com.lightcast.director` | `LightCast-Director.apk` |
| Camera | `com.lightcast.camera` | `LightCast-Camera.apk` |

The Director app provides a single large Program output workflow, camera layout
presets, lyrics, scripture, ticker, logo, lower third, countdown, PIP, and
streaming controls. The Camera app lets a phone select Pastor or Crowd mode and
exposes a transport-ready camera screen.

## Camera pairing

The Director starts a WebSocket signaling server on TCP port `8080` and also
serves `GET /lightcast/health` on that port. Camera phones no longer require a
manually entered IP address: they first try the last successful Director
address, then probe the local IPv4 `/24` network in bounded batches. A
successful result is cached on the camera and reused on the next connection.
Both phones must be on the same Wi-Fi network, and the Director's signaling
server must be running.

The fallback scanner is intentionally dependency-light and works on Android
without multicast permissions. It assumes the common `/24` venue Wi-Fi
configuration because Dart's portable network-interface API does not expose
the subnet mask. Networks using a different subnet size may require the
optional diagnostic `LanCameraTransport.start(host)` escape hatch or a future
mDNS/QR pairing implementation.

## Repository structure

```text
lightcast/
  apps/
    lightcast_director/
    lightcast_camera/
  packages/
    lightcast_shared/
  .github/workflows/build-android.yml
