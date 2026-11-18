import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:ntfy/ntfy.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _ntfyPlugin = Ntfy();
  final _topicController = TextEditingController(text: 'orange_orange');
  final _authController = TextEditingController();
  final List<String> _messages = [];
  bool _isSubscribed = false;
  StreamSubscription<String>? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await Permission.notification.request();
  }

  void _subscribe() async {
    if (_topicController.text.isEmpty) return;

    await _requestPermissions();

    String? authStr = _authController.text.isNotEmpty
        ? _authController.text
        : null;
    if (authStr != null && authStr.startsWith('tk_')) {
      authStr = 'Bearer $authStr';
    }

    try {
      await _ntfyPlugin.subscribe(
        'https://ntfy.sh',
        _topicController.text,
        auth: authStr,
      );
      setState(() {
        _isSubscribed = true;
      });

      _messageSubscription = _ntfyPlugin.messages.listen((String message) {
        setState(() {
          _messages.insert(0, message);
        });
      });
    } on PlatformException catch (e) {
      debugPrint("Failed to subscribe: '${e.message}'.");
    }
  }

  void _unsubscribe() async {
    try {
      await _ntfyPlugin.unsubscribe();
      _messageSubscription?.cancel();
      setState(() {
        _isSubscribed = false;
      });
    } on PlatformException catch (e) {
      debugPrint("Failed to unsubscribe: '${e.message}'.");
    }
  }

  @override
  void dispose() {
    _topicController.dispose();
    _authController.dispose();
    _messageSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Ntfy Plugin Example')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _topicController,
                decoration: const InputDecoration(
                  labelText: 'Topic',
                  border: OutlineInputBorder(),
                  hintText: 'Enter topic to subscribe (e.g. my_test_topic)',
                ),
                enabled: !_isSubscribed,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _authController,

                decoration: const InputDecoration(
                  labelText: 'Authentication (Optional)',
                  border: OutlineInputBorder(),
                  hintText: 'e.g. Basic dGVzd...',
                ),
                enabled: !_isSubscribed,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: _isSubscribed ? null : _subscribe,
                    child: const Text('Subscribe'),
                  ),
                  ElevatedButton(
                    onPressed: _isSubscribed ? _unsubscribe : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Unsubscribe'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Status: ${_isSubscribed ? "Subscribed" : "Unsubscribed"}',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const Divider(),
              const Text(
                'Incoming Messages:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(_messages[index]),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
