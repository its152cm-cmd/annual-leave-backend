import 'package:flutter/material.dart';
import 'package:homempage/core/theme/app_theme.dart';
import 'package:homempage/models/collaborator.dart';

class CollaboratorTile extends StatelessWidget {
  final Collaborator person;
  final bool isAlreadyAdded;
  final VoidCallback? onAddPressed;
  final bool isSearchResult;

  const CollaboratorTile({
    super.key,
    required this.person,
    this.isAlreadyAdded = false,
    this.onAddPressed,
    this.isSearchResult = false,
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrl = person.avatarUrl;
    final hasAvatar = avatarUrl != null && avatarUrl.trim().isNotEmpty;
    final ImageProvider? avatarImage = !hasAvatar
        ? null
        : avatarUrl.startsWith('assets/')
        ? AssetImage(avatarUrl)
        : NetworkImage(avatarUrl);
    final fallback = Text(person.name.isEmpty ? '?' : person.name[0]);

    if (isSearchResult) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: avatarImage,
              child: hasAvatar ? null : fallback,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    person.email,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: isAlreadyAdded ? null : onAddPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                isAlreadyAdded ? 'Added' : 'Add',
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: avatarImage,
            child: hasAvatar ? null : fallback,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppTheme.textDark,
                  ),
                ),
                Text(
                  person.email,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Added',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppTheme.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
