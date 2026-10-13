import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:homempage/core/theme/app_theme.dart ';

class GroupChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String subtitle;
  final VoidCallback onOpenMembers;
  final VoidCallback? onTitleTap;

  const GroupChatAppBar({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onOpenMembers,
    this.onTitleTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppTheme.backgroundWhite,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.textDark),
        onPressed: () {
          if (context.canPop()) {
            context.pop();
            return;
          }
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        },
      ),
      title: InkWell(
        onTap: onTitleTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                if (onTitleTap != null) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.edit_outlined, size: 15, color: AppTheme.textMuted),
                ],
              ],
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.people_outline, color: AppTheme.textDark),
          tooltip: 'View Members',
          onPressed: onOpenMembers,
        ),
      ],
    );
  }
}