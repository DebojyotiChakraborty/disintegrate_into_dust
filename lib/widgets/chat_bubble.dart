import 'package:flutter/material.dart';

/// A styled chat‑message bubble.
///
/// [isMe] controls alignment (right for the current user, left otherwise).
class ChatBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final VoidCallback? onDelete;

  const ChatBubble({
    super.key,
    required this.text,
    this.isMe = false,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showDeleteDialog(context),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72,
          ),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isMe
                ? colorScheme.primary
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 16),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: isMe ? colorScheme.onPrimary : colorScheme.onSurface,
              fontSize: 15,
              height: 1.35,
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    if (onDelete == null) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete message'),
        content: const Text('This message will disintegrate into dust.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete!();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
