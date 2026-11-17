<div align="center">
  <h1>🔔 ntfy Flutter Plugin</h1>
  <p><strong>Push notifications made easy.</strong></p>
  <p>
    <em>A Flutter plugin to natively subscribe to <a href="https://ntfy.sh/">ntfy.sh</a> topics across Android, iOS, and the Web.</em>
  </p>
  
  [![pub package](https://img.shields.io/pub/v/ntfy.svg)](https://pub.dev/packages/ntfy)
  [![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-blue.svg)](https://pub.dev/packages/ntfy)
</div>

---

## 📱 Send & Receive Push Notifications

**[ntfy](https://ntfy.sh/)** (pronounced *notify*) is a simple HTTP-based pub-sub notification service. It allows you to send notifications to your phone or desktop via scripts from any computer, and/or using a REST API. 

With this Flutter plugin, you can subscribe to topics and instantly receive notifications, with different priorities, attachments, action buttons, tags & emojis, and even for automation. 

Alert yourself about unauthorized logins, when your show was downloaded, or when your home automation sensors detect movement in the yard. **ntfy hooks into anything and everything.**

---

## ✨ Features

* 🚀 **Multi-Platform**: Full support for **Android**, **iOS**.
* 🔋 **Native Android Foreground Service**: Keeps the connection alive even when your app is in the background or the screen is off.
* 🍎 **iOS Support**: Supports background notification reception and message handling on iOS natively.
* ⚡ **Server-Sent Events (SSE)**: Efficiently listens to incoming JSON stream notifications.
* 🔐 **Authentication Support**: Pass access tokens (`Bearer`) or basic auth credentials to private ntfy instances natively.
* 📡 **Flutter EventChannel**: Streams received messages back to your Flutter app in real-time.

---

## 🚀 Getting Started

### 1. Requesting Permissions in Flutter

Before calling the `subscribe` method, ensure you request notification permissions from the user. You can use the [`permission_handler`](https://pub.dev/packages/permission_handler) package for this:

```dart
import 'package:permission_handler/permission_handler.dart';

Future<void> requestPermissions() async {
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }
}
```

### 2. Usage

Import the plugin and subscribe to a topic. You can listen to the incoming messages using the `messages` stream.

```dart
import 'package:ntfy/ntfy.dart';

class NtfyExample {
  final _ntfyPlugin = Ntfy();
  StreamSubscription<String>? _messageSubscription;

  void startListening() async {
    // 1. Start listening to the message stream
    _messageSubscription = _ntfyPlugin.messages.listen((String messageJson) {
      print("Received new ntfy message: $messageJson");
      // Note: The message is a JSON string. You can use jsonDecode(messageJson) to parse it.
    });

    // 2. Subscribe and start listening for background notifications
    // Connects to: https://ntfy.sh/my_awesome_topic
    await _ntfyPlugin.subscribe('https://ntfy.sh', 'my_awesome_topic');
  }

  void stopListening() {
    _messageSubscription?.cancel();
    _ntfyPlugin.unsubscribe();
  }
}
```

---

## 🔐 Authentication

If you are using a self-hosted ntfy server with access control, you can pass an `auth` parameter to the `subscribe` method.

### Using an Access Token (Bearer Auth)
```dart
await _ntfyPlugin.subscribe(
  'https://ntfy.example.com', 
  'secret_topic',
  auth: 'Bearer tk_your_access_token_here',
);
```

### Using Username and Password (Basic Auth)
```dart
import 'dart:convert';

final String credentials = base64Encode(utf8.encode('username:password'));

await _ntfyPlugin.subscribe(
  'https://ntfy.example.com', 
  'secret_topic',
  auth: 'Basic $credentials',
);
```

---

## 🛠️ Platform Specific Details

### Android

Since this plugin relies on an Android Foreground Service, the plugin automatically requests the following permissions in its `AndroidManifest.xml`:
- `android.permission.INTERNET`
- `android.permission.WAKE_LOCK`
- `android.permission.FOREGROUND_SERVICE`
- `android.permission.POST_NOTIFICATIONS`

### iOS

To use notifications on iOS, you must add the **Push Notifications** capability to your project. 

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Select your `Runner` target.
3. Go to the **Signing & Capabilities** tab.
4. Click the **+ Capability** button and add **Push Notifications**.
5. *(Optional but recommended)* Add the **Background Modes** capability and check **Remote notifications** to support background updates.

The plugin natively handles streams for iOS via these standard Apple capabilities.

---

## ⚙️ How it Works

When you call `subscribe()`, the plugin intelligently uses the appropriate native implementation for each platform:
- **Android**: Starts an Android Foreground Service named `NtfyForegroundService`. This service holds a partial wake lock and opens an `HttpURLConnection` to the ntfy `/json` stream endpoint. 
- **iOS / Web**: Connects to the event stream natively or utilizes browser `EventSource` and Notification APIs.

Whenever a new JSON message is received, it is broadcasted back to the Flutter Engine over a standard `EventChannel`.

---

<div align="center">
  <sub>Built with ❤️ for the Flutter & Open Source community. Inspired by <a href="https://ntfy.sh/">ntfy.sh</a>.</sub>
</div>
