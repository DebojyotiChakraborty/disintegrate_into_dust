import 'package:flutter/material.dart';

import '../effects/disintegrate_effect.dart';
import '../widgets/chat_bubble.dart';

/// A simple chat message model.
class _ChatMessage {
  final String id;
  final String text;
  final bool isMe;
  bool isDeleting = false;

  _ChatMessage({required this.id, required this.text, required this.isMe});
}

/// Demo chat screen that showcases the disintegrate‑to‑dust animation.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<_ChatMessage> _messages = [
    _ChatMessage(
      id: '1',
      text: 'Hey! Have you seen the new Telegram delete animation?',
      isMe: false,
    ),
    _ChatMessage(
      id: '2',
      text: 'Yeah, it looks amazing! The message just turns to dust ✨',
      isMe: true,
    ),
    _ChatMessage(
      id: '3',
      text: 'I wonder how they built it. Must be some kind of particle system.',
      isMe: false,
    ),
    _ChatMessage(
      id: '4',
      text:
          'Probably captures the widget as an image and breaks it into fragments that drift away.',
      isMe: true,
    ),
    _ChatMessage(id: '5', text: 'That sounds like a lot of work!', isMe: false),
    _ChatMessage(
      id: '6',
      text: 'Not really — a CustomPainter with ~60 particles does the trick.',
      isMe: true,
    ),
    _ChatMessage(
      id: '7',
      text: 'Try long‑pressing any of these messages to delete them 🫠',
      isMe: false,
    ),
    _ChatMessage(id: '8', text: 'Go ahead, delete me. I dare you.', isMe: true),
  ];

  void _deleteMessage(String id) {
    setState(() {
      final msg = _messages.firstWhere((m) => m.id == id);
      msg.isDeleting = true;
    });
  }

  void _removeMessage(String id) {
    setState(() {
      _messages.removeWhere((m) => m.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dust Chat'), centerTitle: true),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final msg = _messages[index];
          return DisintegrateEffect(
            key: ValueKey(msg.id),
            trigger: msg.isDeleting,
            onComplete: () => _removeMessage(msg.id),
            child: ChatBubble(
              text: msg.text,
              isMe: msg.isMe,
              onDelete: () => _deleteMessage(msg.id),
            ),
          );
        },
      ),
    );
  }
}
