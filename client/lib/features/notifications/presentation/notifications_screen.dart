import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/notifications_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _service = NotificationsService();
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _service.list();
      setState(() {
        _notifications = (data['notifications'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    await _service.markAllRead();
    _load();
  }

  Future<void> _markRead(Map<String, dynamic> n) async {
    if (n['isRead'] as bool? ?? false) return;
    await _service.markRead(
      n['id'] as String,
      n['type'] as String,
      n['referenceId'] as String,
    );
    setState(() => n['isRead'] = true);
  }

  void _onTap(Map<String, dynamic> n) {
    _markRead(n);
    final type = n['type'] as String;
    final refId = n['referenceId'] as String;
    if (type == 'event') context.push('/events/$refId');
    if (type == 'article') context.push('/education/$refId');
  }

  @override
  Widget build(BuildContext context) {
    final unread = _notifications.where((n) => !(n['isRead'] as bool? ?? false)).length;

    return Scaffold(
      backgroundColor: context.colorBgPrimary,
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text(
                'Marcar todo',
                style: TextStyle(color: AppColors.accentPrimary, fontSize: 13),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentPrimary))
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_none_rounded,
                          size: 52, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      Text('Sin notificaciones',
                          style: TextStyle(
                              color: context.colorTextSecondary, fontSize: 15)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.accentPrimary,
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _notifications.length,
                    separatorBuilder: (ctx, i) =>
                        Divider(height: 1, color: ctx.colorBorder),
                    itemBuilder: (_, i) =>
                        _NotifTile(notif: _notifications[i], onTap: _onTap),
                  ),
                ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  const _NotifTile({required this.notif, required this.onTap});
  final Map<String, dynamic> notif;
  final void Function(Map<String, dynamic>) onTap;

  IconData _icon(String type, String? subtype) {
    switch (type) {
      case 'event': return Icons.event_rounded;
      case 'article': return Icons.menu_book_rounded;
      case 'system':
        switch (subtype) {
          case 'patch': return Icons.build_circle_outlined;
          case 'feature': return Icons.new_releases_outlined;
          case 'reminder': return Icons.alarm_rounded;
          default: return Icons.campaign_outlined;
        }
      default: return Icons.notifications_outlined;
    }
  }

  Color _color(String type) {
    switch (type) {
      case 'event': return const Color(0xFFFFB347);
      case 'article': return const Color(0xFF8B5CF6);
      default: return AppColors.accentPrimary;
    }
  }

  String _timeAgo(String? createdAt) {
    if (createdAt == null) return '';
    final dt = DateTime.tryParse(createdAt);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    return 'hace ${diff.inDays} días';
  }

  @override
  Widget build(BuildContext context) {
    final isRead = notif['isRead'] as bool? ?? false;
    final type = notif['type'] as String? ?? 'system';
    final subtype = notif['subtype'] as String?;
    final color = _color(type);

    return InkWell(
      onTap: () => onTap(notif),
      child: Container(
        color: isRead ? Colors.transparent : AppColors.accentPrimary.withAlpha(12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_icon(type, subtype), color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notif['title'] as String? ?? '',
                          style: TextStyle(
                            color: context.colorTextPrimary,
                            fontSize: 14,
                            fontWeight:
                                isRead ? FontWeight.normal : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.accentPrimary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notif['body'] as String? ?? '',
                    style: TextStyle(
                        color: context.colorTextSecondary, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _timeAgo(notif['createdAt'] as String?),
                    style: TextStyle(
                        color: context.colorTextMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
