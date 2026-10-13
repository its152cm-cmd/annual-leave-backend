import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../models/group_member.dart';
import '../../../models/group_poll.dart';

class StickyPollsSection extends StatefulWidget {
  final List<GroupPoll> activePolls;
  final List<GroupMember> members;
  final Function(String pollId, String optionId) onVote;

  /// Host only: finish an AI poll so it leaves the top of the chat.
  final Function(String pollId)? onClose;

  const StickyPollsSection({
    super.key,
    required this.activePolls,
    required this.members,
    required this.onVote,
    this.onClose,
  });

  @override
  State<StickyPollsSection> createState() => _StickyPollsSectionState();
}

class _StickyPollsSectionState extends State<StickyPollsSection> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant StickyPollsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activePolls.length == widget.activePolls.length) return;

    // A poll that just appeared (for example one the AI started) is shown
    // first; otherwise stay on the current one.
    final oldIds = {for (final p in oldWidget.activePolls) p.id};
    final newIndex = widget.activePolls.indexWhere((p) => !oldIds.contains(p.id));
    final nextPage = widget.activePolls.isEmpty
        ? 0
        : (oldWidget.activePolls.length < widget.activePolls.length &&
              newIndex != -1)
        ? newIndex
        : _currentPage.clamp(0, widget.activePolls.length - 1).toInt();
    _currentPage = nextPage;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients && widget.activePolls.isNotEmpty) {
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Widget _buildVoterAvatars(List<String> votedUserIds) {
    final membersById = {
      for (final member in widget.members) member.id: member,
    };
    final voters = votedUserIds
        .map((id) => membersById[id])
        .whereType<GroupMember>()
        .take(5)
        .toList();
    if (voters.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 22,
      width: 14.0 * voters.length + 6.0,
      child: Stack(
        children: voters.asMap().entries.map((entry) {
          final index = entry.key;
          final member = voters[index];
          final avatarUrl = member.avatarUrl;
          final ImageProvider? avatarImage = avatarUrl == null
              ? null
              : avatarUrl.startsWith('assets/')
              ? AssetImage(avatarUrl)
              : NetworkImage(avatarUrl);

          return Positioned(
            left: index * 12.0,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: CircleAvatar(
                radius: 9,
                backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.2),
                backgroundImage: avatarImage,
                child: avatarImage == null
                    ? Text(
                        member.name.isNotEmpty ? member.name[0] : '',
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppTheme.primaryGreen,
                        ),
                      )
                    : null,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.activePolls.isEmpty) return const SizedBox.shrink();

    final currentPoll = widget.activePolls[_currentPage];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              // Many options: stop at 30% of the screen and scroll inside.
              height: currentPoll.isExpanded
                  ? (72.0 + (currentPoll.options.length * 48.0)).clamp(
                      52.0,
                      MediaQuery.of(context).size.height * 0.3,
                    )
                  : 52.0,
              child: PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                physics: const PageScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                itemCount: widget.activePolls.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  final poll = widget.activePolls[index];

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 2.0),
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () {
                            setState(() {
                              poll.isExpanded = !poll.isExpanded;
                            });
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  poll.question,
                                  maxLines: poll.isExpanded ? 3 : 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppTheme.textDark,
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  if (poll.id.startsWith('ai:'))
                                    const Padding(
                                      padding: EdgeInsets.only(right: 6),
                                      child: Icon(
                                        Icons.eco_outlined,
                                        size: 14,
                                        color: AppTheme.primaryGreen,
                                      ),
                                    ),
                                  Text(
                                    '${poll.totalVotes} votes',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    poll.isExpanded
                                        ? Icons.keyboard_arrow_up
                                        : Icons.keyboard_arrow_down,
                                    size: 18,
                                    color: AppTheme.textMuted,
                                  ),
                                  if (widget.onClose != null &&
                                      poll.id.startsWith('ai:'))
                                    InkWell(
                                      onTap: () => widget.onClose!(poll.id),
                                      child: const Padding(
                                        padding: EdgeInsets.only(left: 6),
                                        child: Icon(
                                          Icons.close,
                                          size: 16,
                                          color: AppTheme.textMuted,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        if (poll.isExpanded) ...[
                          const SizedBox(height: 10),
                          Flexible(
                            child: SingleChildScrollView(
                              child: Column(
                            children: poll.options.map((option) {
                              final hasVoted =
                                  option.votedUserIds.contains('user_me') ||
                                  widget.members.any(
                                    (m) =>
                                        m.isMe &&
                                        option.votedUserIds.contains(m.id),
                                  );

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6.0),
                                child: InkWell(
                                  onTap: () =>
                                      widget.onVote(poll.id, option.id),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: hasVoted
                                          ? AppTheme.primaryGreen.withValues(
                                              alpha: 0.12,
                                            )
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: hasVoted
                                            ? AppTheme.primaryGreen
                                            : Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          option.text,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: hasVoted
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: hasVoted
                                                ? AppTheme.primaryGreen
                                                : AppTheme.textDark,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            _buildVoterAvatars(
                                              option.votedUserIds,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${option.votedUserIds.length}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.textDark,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          if (widget.activePolls.length > 1) ...[
            const SizedBox(width: 8),
            Container(
              width: 4,
              height: currentPoll.isExpanded ? 100 : 40,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(2),
              ),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 200),
                    top:
                        (_currentPage / (widget.activePolls.length - 1)) *
                        ((currentPoll.isExpanded ? 100 : 40) - 16),
                    child: Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
