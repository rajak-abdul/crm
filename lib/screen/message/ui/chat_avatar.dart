import 'package:flutter/material.dart';

/// Circular avatar that shows the contact/group image when available,
/// falling back to initials-on-color when there's no image or it fails to load.
class ChatAvatar extends StatelessWidget {
  final String? imageUrl;
  final String initials;
  final Color color;
  final double size;

  const ChatAvatar({
    super.key,
    required this.imageUrl,
    required this.initials,
    required this.color,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final hasImage = url != null && url.isNotEmpty;

    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: color,
        alignment: Alignment.center,
        child: hasImage
            ? Image.network(
                url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _Initials(text: initials, size: size),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return _Initials(text: initials, size: size);
                },
              )
            : _Initials(text: initials, size: size),
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  final String text;
  final double size;
  const _Initials({required this.text, required this.size});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: size * 0.32,
      ),
    );
  }
}
