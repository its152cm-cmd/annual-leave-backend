import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../models/collaborator.dart';
import '../../models/chat_message.dart';
import '../../models/account_profile.dart';
import '../../models/group_member.dart';
import '../../models/group_poll.dart';
import '../../models/group_trip_summary.dart';
import '../../services/account_service.dart';
import '../../services/chat_list_service.dart';
import '../../services/expense_service.dart';
import '../../services/group_chat_service.dart';
import '../../services/group_summary_service.dart';
import '../../services/trip_service.dart';
import '../chat/trip_summary_screen.dart';
import 'widgets/chat_app_bar.dart';
import 'widgets/chat_input_field.dart';
import 'widgets/chat_message_bubble.dart';
import 'widgets/chat_summary_card.dart';
import 'widgets/group_members_drawer.dart';
import 'widgets/sticky_polls_section.dart';
import 'widgets/create_poll_modal.dart';
import 'widgets/upload_media_modal.dart';
import 'receipt_scanner_screen.dart';
import '../trip_planning/trip_collaborators_screen.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;

  const GroupChatScreen({super.key, required this.groupId});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final GroupChatService _chatService = GroupChatService();
  final AccountService _accountService = AccountService();
  final GroupSummaryService _summaryService = GroupSummaryService();

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessage> _messages = [];
  List<GroupPoll> _activePolls = [];
  List<GroupMember> _groupMembers = [];
  AccountProfile? _currentUserProfile;
  GroupTripSummary? _tripSummary;

  bool _isLoading = true;
  bool _isSending = false;
  bool _showSummaryCard = true;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    TripService.tripListRevision.addListener(_refreshTripSummary);
    _loadChatData();
    // Shared favourites and votes from other members show up on their own.
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      if (!mounted || _isLoading) return;
      final polls = await _chatService.getActivePolls(widget.groupId);
      if (!mounted) return;
      // New messages from other members.
      final latest = await _chatService.getChatMessages(widget.groupId);
      if (!mounted) return;
      final known = {for (final m in _messages) m.id};
      final fresh = latest.where((m) => !known.contains(m.id)).toList();
      if (fresh.isNotEmpty) {
        setState(() => _messages.addAll(fresh));
        _scrollToBottom();
        _markMessagesReadAfterRender();
      }
      final expanded = {for (final p in _activePolls) p.id: p.isExpanded};
      for (final p in polls) {
        p.isExpanded = expanded[p.id] ?? false;
      }
      setState(() => _activePolls = polls);
      // Someone may have accepted the invitation or renamed the chat.
      if (await _summaryService.syncMembers(widget.groupId)) {
        final members = await _summaryService.getGroupMembers(widget.groupId);
        final summary = await _summaryService.getTripSummary(widget.groupId);
        if (!mounted) return;
        setState(() {
          _groupMembers = members;
          _tripSummary = summary;
        });
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    TripService.tripListRevision.removeListener(_refreshTripSummary);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshTripSummary() async {
    final summary = await _summaryService.getTripSummary(widget.groupId);
    if (mounted) setState(() => _tripSummary = summary);
  }

  Future<void> _loadChatData() async {
    await _summaryService.syncMembers(widget.groupId);
    final messages = await _chatService.getChatMessages(widget.groupId);
    final currentUser = await _accountService.getCurrentUser();
    final polls = await _chatService.getActivePolls(widget.groupId);
    final summary = await _summaryService.getTripSummary(widget.groupId);
    final members = await _summaryService.getGroupMembers(widget.groupId);

    if (mounted) {
      setState(() {
        _messages = messages;
        _currentUserProfile = currentUser;
        _activePolls = polls;
        _tripSummary = summary;
        _groupMembers = members;
        _isLoading = false;
      });
      _scrollToBottom();
      _markMessagesReadAfterRender();
    }
  }

  void _markMessagesReadAfterRender() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _messages.isEmpty) return;
      final readerId = _currentUserProfile?.userId.trim();
      if (readerId == null || readerId.isEmpty) return;
      _chatService.markMessagesRead(
        groupId: widget.groupId,
        readerId: readerId,
        throughMessageId: _messages.last.id,
      );
    });
  }

  Future<void> _refreshGroupMembers() async {
    await _summaryService.syncMembers(widget.groupId);
    final members = await _summaryService.getGroupMembers(widget.groupId);
    if (!mounted) return;
    setState(() => _groupMembers = members);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    _messageController.clear();
    setState(() => _isSending = true);

    final ChatMessage newMessage;
    try {
      newMessage = await _chatService.sendMessage(
        groupId: widget.groupId,
        senderId: 'user_me',
        senderName: 'You',
        senderAvatar: _currentUserProfile?.avatarUrl,
        text: text,
      );
    } catch (_) {
      if (mounted) {
        _messageController.text = text; // give the text back to try again
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't send. Check your connection.")),
        );
      }
      return;
    }

    if (mounted) {
      setState(() {
        _messages.add(newMessage);
        _isSending = false;
      });
      _scrollToBottom();
      _markMessagesReadAfterRender();
    }
  }

  bool _isAskingAi = false;

  Future<void> _handleAskAi(String promptText) async {
    if (_isAskingAi) return;
    _isAskingAi = true;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('AI is thinking...'),
        duration: Duration(seconds: 20),
      ),
    );
    try {
      final aiMessage = await _chatService.triggerAiResponse(
        widget.groupId,
        promptText,
      );
      messenger.hideCurrentSnackBar();
      if (mounted) {
        setState(() {
          if (!_messages.any((m) => m.id == aiMessage.id)) {
            _messages.add(aiMessage);
          }
        });
        _scrollToBottom();
        _markMessagesReadAfterRender();
      }
    } catch (e) {
      messenger.hideCurrentSnackBar();
      final text = '$e';
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            text.contains('overloaded') || text.contains('busy')
                ? 'The AI is busy right now. Try again in a moment.'
                : text.contains('already answering')
                ? 'The AI is already answering. Please wait a moment.'
                : "The AI couldn't answer. Try again.",
          ),
        ),
      );
    } finally {
      _isAskingAi = false;
    }
  }

  Future<void> _handleVote(String pollId, String optionId) async {
    final updatedPoll = await _chatService.votePoll(
      groupId: widget.groupId,
      pollId: pollId,
      optionId: optionId,
      userId: 'user_me',
    );

    if (mounted) {
      setState(() {
        final index = _activePolls.indexWhere((p) => p.id == pollId);
        if (index != -1) {
          if (updatedPoll.options.isEmpty) {
            _activePolls.removeAt(index);
          } else {
            updatedPoll.isExpanded = _activePolls[index].isExpanded;
            _activePolls[index] = updatedPoll;
          }
        }
      });
    }
  }

  Future<void> _handleClosePoll(String pollId) async {
    try {
      await _chatService.closePoll(widget.groupId, pollId);
      if (mounted) {
        setState(() => _activePolls.removeWhere((p) => p.id == pollId));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't close the poll. Try again.")),
        );
      }
    }
  }

  Future<void> _addGroupMembers() async {
    _scaffoldKey.currentState?.closeEndDrawer();
    final existingMemberIds = {
      ..._groupMembers.map((member) => member.id),
      ...?GroupSummaryService.pendingByGroup[widget.groupId]?.map((m) => m.id),
    };
    final selectedMembers = await Navigator.of(context)
        .push<List<Collaborator>>(
          MaterialPageRoute<List<Collaborator>>(
            builder: (_) => TripCollaboratorsScreen(
              startWithNoMembers: true,
              returnSelectedMembers: true,
              existingCollaboratorIds: existingMemberIds,
              screenTitle: 'Add trip members',
            ),
          ),
        );
    if (!mounted || selectedMembers == null || selectedMembers.isEmpty) return;

    if (ExpenseService.isSavedGroup(widget.groupId)) {
      // Real group: send the invitations. They join the list after they accept.
      try {
        await TripService().createGroupChat(
          widget.groupId.substring('trip_'.length),
          selectedMembers.map((m) => m.id).toList(),
        );
        await _summaryService.syncMembers(widget.groupId);
        _tellUser(
          selectedMembers.length == 1
              ? 'Invitation sent to ${selectedMembers.first.name}. They will appear here once they accept.'
              : 'Invitations sent. They will appear here once they accept.',
        );
      } catch (e) {
        _tellUser(e is ApiException ? e.message : "Couldn't send the invitations. Try again.");
      }
    } else {
      final newMembers = selectedMembers
          .where((c) => !_groupMembers.any((member) => member.id == c.id))
          .map(
            (c) => GroupMember(
              id: c.id,
              name: c.name,
              avatarUrl: c.avatarUrl,
              leaveBalanceSummary: '12 Days Available',
            ),
          )
          .toList();
      for (final member in newMembers) {
        await _chatService.addGroupMember(widget.groupId, member);
      }
    }
    final updatedMembers = await _chatService.getGroupMembers(widget.groupId);
    final updatedSummary = await _summaryService.getTripSummary(widget.groupId);
    if (!mounted) return;

    setState(() {
      _groupMembers = updatedMembers;
      _tripSummary = updatedSummary;
    });
  }

  Future<void> _renameChat() async {
    final controller = TextEditingController(text: _tripSummary?.title ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Group name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'e.g. Japan 2026 crew'),
          onSubmitted: (v) => Navigator.pop(dialogContext, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final trimmed = (name ?? '').trim();
    if (trimmed.isEmpty || !mounted || trimmed == _tripSummary?.title) return;
    try {
      await _summaryService.renameGroup(widget.groupId, trimmed);
      final summary = await _summaryService.getTripSummary(widget.groupId);
      ChatListService.conversationsRevision.value++;
      if (mounted) setState(() => _tripSummary = summary);
    } catch (e) {
      _tellUser(e is ApiException ? e.message : "Couldn't rename the chat. Try again.");
    }
  }

  Future<void> _removeGroupMember(GroupMember member) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove trip member?'),
        content: Text('Remove ${member.name} from this trip?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (shouldRemove != true || !mounted) return;

    final requesterId = _groupMembers
        .where((groupMember) => groupMember.isMe)
        .firstOrNull
        ?.id;
    if (requesterId == null) return;

    final removed = await _chatService.removeGroupMember(
      groupId: widget.groupId,
      requesterId: requesterId,
      memberId: member.id,
    );
    if (!removed || !mounted) return;

    final members = await _chatService.getGroupMembers(widget.groupId);
    final summary = await _summaryService.getTripSummary(widget.groupId);
    final polls = await _chatService.getActivePolls(widget.groupId);
    if (!mounted) return;
    setState(() {
      _groupMembers = members;
      _tripSummary = summary;
      _activePolls = polls;
    });
  }

  Future<void> _navigateToTripSummary() async {
    final summary = _tripSummary;
    if (summary?.isTripComplete ?? false) {
      final upcomingTrip = (await TripService().getTrips())
          .where(
            (trip) =>
                trip.id == summary!.itineraryId &&
                trip.status.trim().toLowerCase() == 'upcoming',
          )
          .firstOrNull;
      if (!mounted) return;
      if (upcomingTrip == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upcoming itinerary is unavailable.')),
        );
        return;
      }
      context.push('/trips/${upcomingTrip.id}', extra: upcomingTrip);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TripSummaryScreen(groupId: widget.groupId),
      ),
    );
  }

  static const int _maxAttachmentBytes = 10 * 1024 * 1024;
  final ImagePicker _imagePicker = ImagePicker();

  void _tellUser(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _isUploading = false;

  String _mimeFor(String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    const types = {
      'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png', 'webp': 'image/webp',
      'gif': 'image/gif', 'pdf': 'application/pdf', 'txt': 'text/plain',
      'doc': 'application/msword', 'csv': 'text/csv',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    };
    return types[ext] ?? 'application/octet-stream';
  }

  Future<void> _addAttachmentMessage({
    required MessageType type,
    required String name,
    required Uint8List bytes,
    String mimeType = '',
  }) async {
    if (_isUploading) return;
    setState(() => _isUploading = true);
    _tellUser('Sending $name...');
    try {
      final message = await _chatService.sendAttachment(
        groupId: widget.groupId,
        senderId: 'user_me',
        senderName: 'You',
        senderAvatar: _currentUserProfile?.avatarUrl,
        type: type,
        name: name,
        mimeType: mimeType,
        bytes: bytes,
      );
      if (!mounted) return;
      setState(() => _messages.add(message));
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _scrollToBottom();
      _markMessagesReadAfterRender();
    } catch (e) {
      _tellUser(e is ApiException ? e.message : "Couldn't send that. Check your connection.");
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _openMediaUpload() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const UploadMediaModal(),
    );
    if (source == null || !mounted) return;

    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1800,
        imageQuality: 85,
      );
      if (picked == null) return; // cancelled
      final bytes = await picked.readAsBytes();
      if (bytes.length > _maxAttachmentBytes) {
        _tellUser('That photo is too large (10 MB max).');
        return;
      }
      await _addAttachmentMessage(
        type: MessageType.image,
        name: picked.name,
        bytes: bytes,
        mimeType: picked.mimeType ?? _mimeFor(picked.name),
      );
    } catch (_) {
      _tellUser("Couldn't open the photo picker.");
    }
  }

  Future<void> _openFileUpload() async {
    try {
      final result = await FilePicker.platform.pickFiles(withData: true);
      final file = result?.files.firstOrNull;
      if (file == null) return; // cancelled
      final bytes = file.bytes;
      if (bytes == null) {
        _tellUser("Couldn't read that file.");
        return;
      }
      if (bytes.length > _maxAttachmentBytes) {
        _tellUser('That file is too large (10 MB max).');
        return;
      }
      await _addAttachmentMessage(
        type: MessageType.file,
        name: file.name,
        bytes: bytes,
        mimeType: _mimeFor(file.name),
      );
    } catch (_) {
      _tellUser("Couldn't open the file picker.");
    }
  }

  Future<void> _openCreatePoll() async {
    final createdPoll = await showModalBottomSheet<GroupPoll>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreatePollModal(),
    );

    if (createdPoll == null || !mounted) return;
    await _chatService.addPoll(widget.groupId, createdPoll);
    final updatedPolls = await _chatService.getActivePolls(widget.groupId);
    if (!mounted) return;

    setState(() => _activePolls = updatedPolls);
    _scrollToBottom();
  }

  void _navigateToExpenses() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReceiptScannerScreen(groupId: widget.groupId),
      ),
    );
  }

  List<_ChatTimelineItem> _buildTimelineItems() {
    final messages = List<ChatMessage>.of(_messages)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final items = <_ChatTimelineItem>[];
    DateTime? previousDate;

    for (final message in messages) {
      final localTimestamp = message.timestamp.toLocal();
      final messageDate = DateTime(
        localTimestamp.year,
        localTimestamp.month,
        localTimestamp.day,
      );
      if (previousDate == null || !_isSameDate(previousDate, messageDate)) {
        items.add(_ChatTimelineItem.date(messageDate));
        previousDate = messageDate;
      }
      items.add(_ChatTimelineItem.message(message));
    }
    return items;
  }

  bool _isSameDate(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  String _formatDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (_isSameDate(date, today)) return 'Today';
    if (_isSameDate(date, yesterday)) return 'Yesterday';

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final title = _tripSummary?.title ?? 'Group Chat';
    final subtitle = '${_groupMembers.length} Friends Live Sync';
    final timelineItems = _buildTimelineItems();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.backgroundWhite,
      appBar: GroupChatAppBar(
        title: title,
        subtitle: subtitle,
        onOpenMembers: () => _scaffoldKey.currentState?.openEndDrawer(),
        onTitleTap: _renameChat,
      ),
      endDrawer: GroupMembersDrawer(
        groupId: widget.groupId,
        members: _groupMembers,
        pendingMembers: GroupSummaryService.pendingByGroup[widget.groupId] ?? const [],
        onAddMemberPressed: _addGroupMembers,
        onRemoveMember: _removeGroupMember,
        onMemberUpdated: _refreshGroupMembers,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity != null &&
                    details.primaryVelocity! < -300) {
                  _scaffoldKey.currentState?.openEndDrawer();
                }
              },
              child: SafeArea(
                child: Column(
                  children: [
                    if (_tripSummary != null)
                      ChatSummaryCard(
                        tripSummary: _tripSummary!,
                        isExpanded: _showSummaryCard,
                        onTapCard: _navigateToTripSummary,
                        onToggleSummary: () {
                          setState(() {
                            _showSummaryCard = !_showSummaryCard;
                          });
                        },
                      ),

                    if (_activePolls.isNotEmpty)
                      StickyPollsSection(
                        activePolls: _activePolls,
                        members: _groupMembers,
                        onVote: _handleVote,
                        onClose:
                            _groupMembers.any(
                              (m) => m.isMe && m.role == 'Host',
                            )
                            ? _handleClosePoll
                            : null,
                      ),

                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16.0),
                        itemCount: timelineItems.length,
                        itemBuilder: (context, index) {
                          final item = timelineItems[index];
                          if (item.date != null) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Center(
                                child: Text(
                                  _formatDateLabel(item.date!),
                                  style: const TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            );
                          }
                          return ChatMessageBubble(
                            message: item.message!,
                            currentUserProfile: _currentUserProfile,
                            onAskAi: _handleAskAi,
                          );
                        },
                      ),
                    ),

                    ChatInputField(
                      controller: _messageController,
                      onSend: _handleSendMessage,
                      onMediaTap: _openMediaUpload,
                      onFileTap: _openFileUpload,
                      onPollTap: _openCreatePoll,
                      onExpensesTap: _navigateToExpenses,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _ChatTimelineItem {
  const _ChatTimelineItem.date(this.date) : message = null;
  const _ChatTimelineItem.message(this.message) : date = null;

  final DateTime? date;
  final ChatMessage? message;
}
