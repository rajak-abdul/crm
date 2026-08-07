import 'package:flutter/material.dart';
import 'package:crm_app/thems/app_themes.dart' show AppColors;

class CrmHeader extends StatelessWidget {
  final String greeting;
  final String userName;
  final String? profileImage;
  final bool isOffline;
  final bool isDrawerOpen;
  final VoidCallback onMenuTap;
  final VoidCallback onNotifTap;
  final int unreadCount;
  final List<Color> gradientColors;
  final bool showBackground;
  final VoidCallback? onAvatarTap;



  const CrmHeader({
    super.key,
    this.greeting = 'Hello! Welcome back!',
    required this.userName,
    this.profileImage,
    required this.isOffline,
    required this.isDrawerOpen,
    required this.onMenuTap,
    required this.onNotifTap,
    this.unreadCount = 0,
    this.showBackground = false,
    this.gradientColors = const [
      Color(0xFF1D4ED8),
      Color(0xFF2563EB),
      Color(0xFF0EA5E9),
    ],
    this.onAvatarTap,
  });

  String get _initials {
    final parts = userName
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts[1][0]).toUpperCase();
  }

  @override
Widget build(BuildContext context) {
  final content = SafeArea(
    bottom: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _MenuButton(isOpen: isDrawerOpen, onTap: onMenuTap),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(greeting,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(userName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _NotifBell(unreadCount: unreadCount, onTap: onNotifTap),
          const SizedBox(width: 12),
         GestureDetector(
  onTap: onAvatarTap,
  child: _Avatar(
    initials: _initials,
    imageUrl: profileImage,
    isOffline: isOffline,
  ),
),
        ],
      ),
    ),
  );

  if (!showBackground) return content;

  return DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: gradientColors,
      ),
    ),
    child: content,
  );
}
}

class _MenuButton extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onTap;
  const _MenuButton({required this.isOpen, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12)),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) => RotationTransition(
                turns: anim,
                child: FadeTransition(opacity: anim, child: child)),
            child: Icon(
              isOpen ? Icons.close_rounded : Icons.menu_rounded,
              key: ValueKey(isOpen),
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      );
}

class _NotifBell extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onTap;
  const _NotifBell({required this.unreadCount, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.notifications_outlined,
                color: Colors.white, size: 22),
          ),
          if (unreadCount > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ]),
      );
}

class _Avatar extends StatelessWidget {
  final String initials;
  final String? imageUrl;
  final bool isOffline;
  const _Avatar({
    required this.initials,
    this.imageUrl,
    required this.isOffline,
  });

  @override
  Widget build(BuildContext context) => Stack(clipBehavior: Clip.none, children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(
                color: Colors.white.withOpacity(0.5), width: 1.5),
          ),
          child: ClipOval(
            child: imageUrl != null && imageUrl!.isNotEmpty
                ? Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _InitialsText(initials),
                  )
                : _InitialsText(initials),
          ),
        ),
        Positioned(
          right: 1,
          bottom: 1,
          child: Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: isOffline ? Colors.red : Colors.green,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF1D4ED8), width: 2),
            ),
          ),
        ),
      ]);
}

class _InitialsText extends StatelessWidget {
  final String text;
  const _InitialsText(this.text);
  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          text,
          style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
        ),
      );
}