import 'package:flutter/material.dart';
import 'package:homempage/core/theme/app_theme.dart ';

import '../../../models/group_member.dart';
import 'member_list_tile.dart';

class GroupMembersDrawer extends StatefulWidget {
  final List<GroupMember> members;
  final List<GroupMember> pendingMembers;
  final VoidCallback? onAddMemberPressed;
  final ValueChanged<GroupMember>? onRemoveMember;
  final VoidCallback? onMemberUpdated;
  final String groupId;

  const GroupMembersDrawer({
    super.key,
    required this.members,
    this.pendingMembers = const [],
    this.onAddMemberPressed,
    this.onRemoveMember,
    this.onMemberUpdated,
    this.groupId = '',
  });

  @override
  State<GroupMembersDrawer> createState() => _GroupMembersDrawerState();
}

class _GroupMembersDrawerState extends State<GroupMembersDrawer> {
  String? _expandedMemberId;

  @override
  Widget build(BuildContext context) {
    final isHost = widget.members.any(
      (member) => member.isMe && member.role == 'Host',
    );

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drawer Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 16.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Trip Members',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textDark,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryGreen,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 22,
                      ),
                      onPressed: widget.onAddMemberPressed,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Members List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: widget.members.length +
                    (widget.pendingMembers.isEmpty ? 0 : widget.pendingMembers.length + 1),
                itemBuilder: (context, index) {
                  if (index >= widget.members.length) {
                    final slot = index - widget.members.length;
                    if (slot == 0) {
                      return const Padding(
                        padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
                        child: Text(
                          'WAITING FOR THEM TO ACCEPT',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textMuted,
                            letterSpacing: 0.5,
                          ),
                        ),
                      );
                    }
                    final pending = widget.pendingMembers[slot - 1];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.surfaceSecondary,
                        backgroundImage: (pending.avatarUrl ?? '').isEmpty
                            ? null
                            : NetworkImage(pending.avatarUrl!),
                        child: (pending.avatarUrl ?? '').isEmpty
                            ? const Icon(Icons.person_outline, color: AppTheme.textMuted)
                            : null,
                      ),
                      title: Text(
                        pending.name,
                        style: const TextStyle(color: AppTheme.textMuted),
                      ),
                      subtitle: const Text('Invitation sent', style: TextStyle(fontSize: 12)),
                      trailing: isHost
                          ? IconButton(
                              tooltip: 'Cancel invitation',
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () => widget.onRemoveMember?.call(pending),
                            )
                          : null,
                    );
                  }
                  final member = widget.members[index];
                  final isExpanded = _expandedMemberId == member.id;

                  return MemberListTile(
                    member: member,
                    groupId: widget.groupId,
                    isExpanded: isExpanded,
                    onRemoveMember: isHost && !member.isMe
                        ? () => widget.onRemoveMember?.call(member)
                        : null,
                    onMemberUpdated: widget.onMemberUpdated,
                    onToggleExpand: () {
                      setState(() {
                        _expandedMemberId = isExpanded ? null : member.id;
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
