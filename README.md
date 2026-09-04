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

## Repository structure

```text
lightcast/
  apps/
    lightcast_director/
    lightcast_camera/
  packages/
    lightcast_shared/
  .github/workflows/build-android.yml
