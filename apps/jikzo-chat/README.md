# JIKZO Chat

Flutter Android messaging-app prototype.

## Current screens
- Premium dark chat home
- Searchable sample conversation list
- Story/status-style contact bubbles
- Local demo conversation screen and message composer
- Bottom navigation shell

## Current limitations
This is a UI prototype. Conversations are sample data and messages only exist in the current screen session. No real accounts, network messaging, push notifications, media upload, end-to-end encryption or calling are implemented yet.

## Build
From this directory:
```sh
flutter pub get
flutter run
flutter build apk --release
```

The repository-level GitHub Actions workflow builds this app in the cloud.
