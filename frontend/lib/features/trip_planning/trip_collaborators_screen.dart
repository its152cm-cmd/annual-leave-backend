import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/collaborator.dart';
import '../../models/trip.dart';
import '../../services/chat_list_service.dart';
import '../../services/collaborator_service.dart';
import '../../services/trip_service.dart';
import 'widgets/collaborator_search_bar.dart';
import 'widgets/collaborator_title.dart';
import 'widgets/trip_style_selector.dart';

class TripCollaboratorsScreen extends StatefulWidget {
  const TripCollaboratorsScreen({
    super.key,
    this.startWithNoMembers = false,
    this.returnSelectedMembers = false,
    this.existingCollaboratorIds = const {},
    this.initialCollaborators = const [],
    this.screenTitle = 'Create your trip',
    this.tripDraft,
  });

  final bool startWithNoMembers;
  final bool returnSelectedMembers;
  final Set<String> existingCollaboratorIds;
  final List<Collaborator> initialCollaborators;
  final String screenTitle;
  final Trip? tripDraft;

  @override
  State<TripCollaboratorsScreen> createState() =>
      _TripCollaboratorsScreenState();
}

class _TripCollaboratorsScreenState extends State<TripCollaboratorsScreen> {
  final CollaboratorService _collaboratorService = CollaboratorService();
  final TextEditingController _searchController = TextEditingController();

  List<Collaborator> _addedCollaborators = [];
  List<Collaborator> _recent = []; // people travelled with before: shown as suggestions, never added by themselves
  List<Collaborator> _searchResults = [];
  bool _isLoading = true;
  bool _isSearching = false;
  bool _isSoloSelected = false;
  bool _isCreatingGroup = false;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    if (widget.startWithNoMembers) {
      setState(() {
        _addedCollaborators = widget.initialCollaborators
            .map((collaborator) => collaborator.copyWith(isAdded: true))
            .toList();
        _isLoading = false;
      });
      return;
    }
    final list = await _collaboratorService.getCollaborators();
    if (!mounted) return;
    setState(() {
      _addedCollaborators = [];
      _recent = list;
      _isLoading = false;
    });
  }

  void _onSearchChanged(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    setState(() => _isSearching = true);
    final results = await _collaboratorService.searchCollaborators(query);
    if (!mounted) return;
    setState(() => _searchResults = results);
  }

  void _addCollaborator(Collaborator person) {
    if (!_addedCollaborators.any((c) => c.id == person.id) &&
        !widget.existingCollaboratorIds.contains(person.id)) {
      setState(() {
        _addedCollaborators.add(person.copyWith(isAdded: true));
        _searchController.clear();
        _isSearching = false;
        _searchResults = [];
      });
    }
  }

  void _navigateToNext({bool planFirst = false}) {
    if (widget.returnSelectedMembers) {
      Navigator.of(context).pop(_addedCollaborators);
      return;
    }
    // "Plan first" goes straight into the group chat as well; the host can
    // add people there later.
    if (widget.tripDraft != null) {
      _createGroupAndOpenChat();
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    if (context.canPop()) {
      context.pop();
    }
  }

  /// Group trips start in the group chat: the trip and chat are created now,
  /// everyone gets invited, and the itinerary is planned later from the chat.
  Future<void> _createGroupAndOpenChat() async {
    if (_isCreatingGroup) return;
    setState(() => _isCreatingGroup = true);
    try {
      final tripService = TripService();
      final draft = widget.tripDraft!.copyWith(
        travellerCount: _addedCollaborators.length + 1,
        collaborators: _addedCollaborators,
        generatedFromGroupChat: true,
      );
      final saved = await tripService.saveDraft(draft);
      await tripService.createGroupChat(
        saved.id,
        _addedCollaborators.map((c) => c.id).toList(),
      );
      ChatListService.conversationsRevision.value++;
      if (!mounted) return;
      context.go('/chat/trip_${saved.id}');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Couldn't create the group chat: $error")),
      );
    } finally {
      if (mounted) setState(() => _isCreatingGroup = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.textDark),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          widget.screenTitle,
          style: const TextStyle(
            color: AppTheme.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 8.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!widget.returnSelectedMembers) ...[
                    TripStyleSelector(
                      isSoloSelected: _isSoloSelected,
                      showTitle: false,
                      onSelectSolo: () {
                        setState(() => _isSoloSelected = true);
                        Navigator.of(context).maybePop();
                      },
                      onSelectGroup: () {
                        setState(() => _isSoloSelected = false);
                      },
                    ),
                    const SizedBox(height: 20),
                  ],

                  const Text(
                    'Collaborators',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 12),

                  CollaboratorSearchBar(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                  ),
                  const SizedBox(height: 16),

                  if (_isSearching) ...[
                    const Text(
                      'Search Results',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_searchResults.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'No users found',
                          style: TextStyle(color: AppTheme.textMuted),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final person = _searchResults[index];
                          return CollaboratorTile(
                            person: person,
                            isAlreadyAdded:
                                _addedCollaborators.any(
                                  (c) => c.id == person.id,
                                ) ||
                                widget.existingCollaboratorIds.contains(
                                  person.id,
                                ),
                            isSearchResult: true,
                            onAddPressed: () => _addCollaborator(person),
                          );
                        },
                      ),
                    const SizedBox(height: 16),
                  ],

                  if (!_isSearching &&
                      !_isLoading &&
                      _recent.any(
                        (p) =>
                            !_addedCollaborators.any((c) => c.id == p.id) &&
                            !widget.existingCollaboratorIds.contains(p.id),
                      )) ...[
                    const Text(
                      'Travelled with before',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final person in _recent.where(
                      (p) =>
                          !_addedCollaborators.any((c) => c.id == p.id) &&
                          !widget.existingCollaboratorIds.contains(p.id),
                    ))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: CollaboratorTile(
                          person: person,
                          isAlreadyAdded: false,
                          isSearchResult: true,
                          onAddPressed: () => _addCollaborator(person),
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],

                  Text(
                    widget.startWithNoMembers
                        ? 'Selected collaborators'
                        : 'Added collaborators',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_addedCollaborators.isNotEmpty)
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _addedCollaborators.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        return CollaboratorTile(
                          person: _addedCollaborators[index],
                        );
                      },
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        'Search for people to add to this trip.',
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                    ),

                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isCreatingGroup ? null : _navigateToNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: Text(
                        widget.returnSelectedMembers
                            ? 'Add members'
                            : _isCreatingGroup
                            ? 'Creating group...'
                            : widget.tripDraft != null
                            ? 'Create group chat'
                            : 'Next',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (!widget.returnSelectedMembers)
                    Center(
                      child: GestureDetector(
                        onTap: () => _navigateToNext(planFirst: true),
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              fontSize: 15,
                              color: AppTheme.textMuted,
                            ),
                            children: [
                              TextSpan(text: 'Planning this yourself? '),
                              TextSpan(
                                text: 'Plan first →',
                                style: TextStyle(
                                  color: AppTheme.primaryGreen,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 90),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
