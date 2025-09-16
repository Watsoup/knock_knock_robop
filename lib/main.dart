import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  await dotenv.load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Knock Knock Robopoly',
      home: const KnockKnockPage(),
    );
  }
}

class KnockKnockPage extends StatefulWidget {
  const KnockKnockPage({super.key});

  @override
  State<KnockKnockPage> createState() => _KnockKnockPageState();
}

class WebhookCooldown {
  bool onCooldown;
  double progress;
  Timer? timer;

  WebhookCooldown({this.onCooldown = false, this.progress = 1.0, this.timer});
}

class _KnockKnockPageState extends State<KnockKnockPage> {
  bool _tapped = false;
  final AudioPlayer _audioPlayer = AudioPlayer();

  final Map<String, WebhookCooldown> webhooks = {
    'main': WebhookCooldown(),
    'eyes': WebhookCooldown(),
    'come': WebhookCooldown(),
  };

  static const Duration cooldownDuration = Duration(minutes: 15);

  Future<void> _callWebhook(WebhookCooldown webhook, String content) async {
    if (webhook.onCooldown) return;

    setState(() {
      webhook.onCooldown = true;
      webhook.progress = 1.0;
    });

    final String webhookUrl = const String.fromEnvironment('WEBHOOK_URL');

    try {
      final _ = await http.post(
        Uri.parse(webhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: '{"content": "$content"}',
      );
    } catch (e) {
      print('Webhook error: $e');
    }

    _startWebhookCooldownTimer(webhook);
  }

  void _startWebhookCooldownTimer(WebhookCooldown webhook) {
    webhook.timer?.cancel();
    final int totalSeconds = cooldownDuration.inSeconds;
    int elapsed = 0;

    webhook.timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      elapsed++;
      setState(() {
        webhook.progress = 1.0 - (elapsed / totalSeconds);
        if (webhook.progress < 0) webhook.progress = 0;
      });
      if (elapsed >= totalSeconds) {
        timer.cancel();
        setState(() {
          webhook.onCooldown = false;
          webhook.progress = 1.0;
        });
      }
    });
  }

  Future<void> _onImageTap() async {
    setState(() {
      _tapped = true;
    });

    _audioPlayer.play(AssetSource('sounds/knocking.mp3'));

    if (!webhooks['main']!.onCooldown) {
      _callWebhook(
        webhooks['main']!,
        "Knock Knock! Someone's at the door, is anybody able to go get them ?",
      );
    }

    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _tapped = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    for (var webhook in webhooks.values) {
      webhook.timer?.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color.fromARGB(255, 198, 186, 235), Colors.red],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Knock Knock, Robop\'',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _onImageTap,
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width,
                            child: Image.asset(
                              _tapped
                                  ? 'assets/images/knocking.png'
                                  : 'assets/images/not_knocking.png',
                              fit: BoxFit.fitWidth,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        CooldownProgressBar(
                          onCooldown: webhooks['main']!.onCooldown,
                          progress: webhooks['main']!.progress,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () => _callWebhook(
                              webhooks['eyes']!,
                              "👀",
                            ),
                            child: const Text(
                              "👀",
                              style: TextStyle(fontSize: 64),
                            ),
                          ),
                          const SizedBox(height: 10),
                          CooldownProgressBar(
                            onCooldown: webhooks['eyes']!.onCooldown,
                            progress: webhooks['eyes']!.progress,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () =>
                                _callWebhook(webhooks['come']!, "Coming! 🏃"),
                            child: const Text(
                              "🏃",
                              style: TextStyle(fontSize: 64),
                            ),
                          ),
                          const SizedBox(height: 10),
                          CooldownProgressBar(
                            onCooldown: webhooks['come']!.onCooldown,
                            progress: webhooks['come']!.progress,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CooldownProgressBar extends StatelessWidget {
  final bool onCooldown;
  final double progress;
  const CooldownProgressBar({
    super.key,
    required this.onCooldown,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: LinearProgressIndicator(
        value: onCooldown ? progress : 1.0,
        backgroundColor: Colors.white,
        valueColor: AlwaysStoppedAnimation<Color>(
          onCooldown ? Colors.orange : Colors.green,
        ),
        minHeight: 10,
      ),
    );
  }
}
