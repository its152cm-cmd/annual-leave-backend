import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/chat_conversation.dart';
import '../../models/trip_invitation.dart';
import '../../services/chat_list_service.dart';

class ChatMainScreen extends StatefulWidget {
  const ChatMainScreen({super.key});

  @override
  State<ChatMainScreen> createState() => _ChatMainScreenState();
}

class _ChatMainScreenState extends State<ChatMainScreen> {
  final ChatListService _chatListService = ChatListService();

  List<ChatConversation> _conversations = [];
  List<TripInvitation> _invitations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    ChatListService.conversationsRevision.addListener(_reloadData);
    _loadData();
  }

  @override
  void dispose() {
    ChatListService.conversationsRevision.removeListener(_reloadData);
    super.dispose();
  }

  void _reloadData() {
    if (mounted) _loadData();
  }

  Future<void> _loadData() async {
    final conversations = await _chatListService.getConversations();
    final invitations = await _chatListService.getPendingInvitations();

    if (mounted) {
      setState(() {
        _conversations = conversations;
        _invitations = invitations;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleAcceptInvitation(String invitationId) async {
    final invitedChat = _invitations.firstWhere(
      (invitation) => invitation.id == invitationId,
      orElse: () => TripInvitation(
        id: invitationId,
        groupId: '',
        hostName: '',
        hostAvatar: '',
        tripTitle: '',
        destination: '',
        dates: '',
      ),
    );

    await _chatListService.acceptInvitation(invitationId);
    if (mounted) {
      setState(() {
        _invitations.removeWhere((inv) => inv.id == invitationId);

        if (invitedChat.groupId.isNotEmpty &&
            !_conversations.any(
              (chat) => chat.groupId == invitedChat.groupId,
            )) {
          _conversations.insert(
            0,
            ChatConversation(
              groupId: invitedChat.groupId,
              title: invitedChat.tripTitle,
              destination: invitedChat.destination,
              lastMessage: 'Welcome to the group chat.',
              lastMessageTime: DateTime.now(),
              unreadCount: 0,
              avatarUrl: invitedChat.hostAvatar,
              isLiveSync: true,
            ),
          );
        }
      });

      if (invitedChat.groupId.isNotEmpty) {
        context.push('/chat/${invitedChat.groupId}');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitation accepted! Group chat added.')),
      );
    }
  }

  Future<void> _handleDeclineInvitation(String invitationId) async {
    await _chatListService.declineInvitation(invitationId);
    if (mounted) {
      setState(() {
        _invitations.removeWhere((inv) => inv.id == invitationId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundWhite,
        elevation: 0,
        title: const Text(
          'Group Chats',
          style: TextStyle(
            color: AppTheme.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                children: [
                  // Pop-out Host Invitations Header
                  if (_invitations.isNotEmpty) ...[
                    ..._invitations.map((inv) => _buildInvitationBanner(inv)),
                    const SizedBox(height: 16),
                  ],

                  const Text(
                    'Active Chats',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // List of Group Conversations
                  if (_conversations.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'No group chats yet.',
                          style: TextStyle(color: AppTheme.textMuted),
                        ),
                      ),
                    )
                  else
                    ..._conversations.map(
                      (chat) => _buildConversationTile(chat),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildInvitationBanner(TripInvitation invitation) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.badgeGreenLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: invitation.hostAvatar.isNotEmpty
                    ? NetworkImage(invitation.hostAvatar)
                    : null,
                child: invitation.hostAvatar.isEmpty
                    ? const Icon(Icons.person, size: 18)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      color: AppTheme.textDark,
                      fontSize: 13,
                    ),
                    children: [
                      TextSpan(
                        text: invitation.hostName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(text: ' invited you to join '),
                      TextSpan(
                        text: invitation.tripTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${invitation.destination} • ${invitation.dates}',
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => _handleDeclineInvitation(invitation.id),
                child: const Text(
                  'Decline',
                  style: TextStyle(color: AppTheme.textMuted),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _handleAcceptInvitation(invitation.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Accept & Join',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConversationTile(ChatConversation chat) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: NetworkImage(chat.avatarUrl),
            ),
            if (chat.isLiveSync)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                chat.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppTheme.textDark,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              _formatTimestamp(chat.lastMessageTime),
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  chat.lastMessage,
                  style: TextStyle(
                    fontSize: 13,
                    color: chat.unreadCount > 0
                        ? AppTheme.textDark
                        : AppTheme.textMuted,
                    fontWeight: chat.unreadCount > 0
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (chat.unreadCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryGreen,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${chat.unreadCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        onTap: () async {
          // Navigate to the existing individual GroupChatScreen
          await context.push('/chat/${chat.groupId}');
          if (mounted) await _loadData();
        },
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
