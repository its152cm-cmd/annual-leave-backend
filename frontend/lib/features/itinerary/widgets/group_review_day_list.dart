import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/itinerary.dart';
import '../../../services/itinerary_review_service.dart';
import '../../../services/route_service.dart';
import 'itinerary_daycards.dart';

/// One day of the itinerary for people who cannot edit it: they can agree or
/// disagree with each stop, comment on it, or ask the group to vote on it.
class GroupReviewDayList extends StatefulWidget {
  final String tripId;
  final List<ItineraryDetailItem> items;
  final ItineraryReview review;
  final VoidCallback onChanged;
  final Map<String, TransferLeg> legs;
  final void Function(ItineraryDetailItem item)? onOpen;

  const GroupReviewDayList({
    super.key,
    required this.tripId,
    required this.items,
    required this.review,
    required this.onChanged,
    this.legs = const {},
    this.onOpen,
  });

  @override
  State<GroupReviewDayList> createState() => _GroupReviewDayListState();
}

class _GroupReviewDayListState extends State<GroupReviewDayList> {
  final ItineraryReviewService _service = ItineraryReviewService();
  late Map<String, ItemReaction> _local;

  @override
  void initState() {
    super.initState();
    _local = Map.of(widget.review.items);
  }

  @override
  void didUpdateWidget(covariant GroupReviewDayList old) {
    super.didUpdateWidget(old);
    _local = Map.of(widget.review.items);
  }

  ItemReaction _reaction(String id) => _local[id] ?? const ItemReaction();

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _vote(ItineraryDetailItem item, String vote) async {
    final me = widget.review.me;
    final r = _reaction(item.id);
    final agree = [...r.agree]..remove(me);
    final disagree = [...r.disagree]..remove(me);
    final already = (vote == 'agree' ? r.agree : r.disagree).contains(me);
    if (!already) (vote == 'agree' ? agree : disagree).add(me);
    setState(() => _local[item.id] = ItemReaction(agree: agree, disagree: disagree, comments: r.comments));
    try {
      await _service.vote(widget.tripId, item.id, vote);
      widget.onChanged();
    } catch (e) {
      setState(() => _local[item.id] = r);
      _snack(e is ApiException ? e.message : 'Could not save your vote.');
    }
  }

  Future<void> _ask(ItineraryDetailItem item) async {
    try {
      await _service.askGroup(widget.tripId, item.id);
      _snack('Poll pinned in the group chat.');
    } catch (e) {
      _snack(e is ApiException ? e.message : 'Could not start the poll.');
    }
  }

  void _openComments(ItineraryDetailItem item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CommentsSheet(tripId: widget.tripId, item: item, service: _service),
    ).then((_) => widget.onChanged());
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const Center(child: Text('Nothing planned for this day.', style: TextStyle(color: AppTheme.textMuted)));
    }
    final me = widget.review.me;
    final total = widget.review.memberNames.length;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: widget.items.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppTheme.badgeGreenLight, borderRadius: BorderRadius.circular(12)),
            child: const Row(children: [
              Icon(Icons.visibility_outlined, size: 18, color: AppTheme.primaryGreen),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'View only. Tell the host what you think: agree, comment, or ask the group to vote.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textDark),
                ),
              ),
            ]),
          );
        }
        final item = widget.items[i - 1];
        final r = _reaction(item.id);
        final iAgree = r.agree.contains(me);
        final iDisagree = r.disagree.contains(me);
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              [item.timeStart, item.timeEnd].where((t) => t.isNotEmpty).join(' - '),
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onOpen == null ? null : () => widget.onOpen!(item),
              child: Row(children: [
                Expanded(
                  child: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
                ),
                if (widget.onOpen != null)
                  const Icon(Icons.info_outline, size: 16, color: AppTheme.textMuted),
              ]),
            ),
            if (item.subtitle.isNotEmpty)
              Text(item.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            if (widget.legs[item.id] != null)
              TransferLegChip(leg: widget.legs[item.id]!),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              _chip(Icons.thumb_up_alt_outlined, '${r.agree.length}', iAgree, AppTheme.primaryGreen, () => _vote(item, 'agree')),
              _chip(Icons.thumb_down_alt_outlined, '${r.disagree.length}', iDisagree, const Color(0xFFFF3B30), () => _vote(item, 'disagree')),
              _chip(Icons.chat_bubble_outline, '${r.comments}', false, AppTheme.primaryBlue, () => _openComments(item)),
              _chip(Icons.how_to_vote_outlined, 'Ask group', false, AppTheme.textDark, () => _ask(item)),
            ]),
            if (total > 1 && (r.agree.isNotEmpty || r.disagree.isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${r.agree.length + r.disagree.length} of $total have reacted',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ),
          ]),
        );
      },
    );
  }

  Widget _chip(IconData icon, String label, bool active, Color color, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.15) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? color : AppTheme.borderSubtle),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: active ? color : AppTheme.textMuted),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? color : AppTheme.textDark)),
        ]),
      ),
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  final String tripId;
  final ItineraryDetailItem item;
  final ItineraryReviewService service;
  const _CommentsSheet({required this.tripId, required this.item, required this.service});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _input = TextEditingController();
  List<ReviewComment>? _comments;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final c = await widget.service.comments(widget.tripId, widget.item.id);
      if (mounted) setState(() => _comments = c);
    } catch (e) {
      if (mounted) setState(() { _comments = []; _error = e is ApiException ? e.message : 'Could not load comments.'; });
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() { _sending = true; _error = null; });
    try {
      final c = await widget.service.addComment(widget.tripId, widget.item.id, text);
      _input.clear();
      if (mounted) setState(() => _comments = [...?_comments, c]);
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : 'Could not send.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(ReviewComment c) async {
    try {
      await widget.service.deleteComment(widget.tripId, c.id);
      if (mounted) setState(() => _comments = _comments?.where((x) => x.id != c.id).toList());
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : 'Could not delete.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
          const SizedBox(height: 10),
          Flexible(
            child: _comments == null
                ? const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)))
                : _comments!.isEmpty
                    ? const Padding(padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text('No comments yet. Be the first.', style: TextStyle(color: AppTheme.textMuted)))
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          for (final c in _comments!)
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(c.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                              subtitle: Text(c.text, style: const TextStyle(fontSize: 14, color: AppTheme.textDark)),
                              trailing: c.canDelete
                                  ? IconButton(icon: const Icon(Icons.delete_outline, size: 18), onPressed: () => _delete(c))
                                  : null,
                            ),
                        ],
                      ),
          ),
          if (_error != null)
            Padding(padding: const EdgeInsets.only(top: 4), child: Text(_error!, style: const TextStyle(color: Color(0xFFFF3B30), fontSize: 12))),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _input,
                maxLength: 500,
                minLines: 1,
                maxLines: 3,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Add a comment...',
                  counterText: '',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _sending ? null : _send,
              style: IconButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
              icon: const Icon(Icons.send, size: 18, color: Colors.white),
            ),
          ]),
        ]),
      ),
    );
  }
}
