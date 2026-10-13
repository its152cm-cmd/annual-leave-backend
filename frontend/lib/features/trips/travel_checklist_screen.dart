import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_client.dart';
import '../../services/checklist_service.dart';

class TravelChecklistScreen extends StatefulWidget {
  const TravelChecklistScreen({super.key, this.tripId = ''});

  final String tripId;

  @override
  State<TravelChecklistScreen> createState() => _TravelChecklistScreenState();
}

class _TravelChecklistScreenState extends State<TravelChecklistScreen> {
  final ChecklistService _service = ChecklistService();
  bool _loading = true;
  String? _error;

  // Old sample trips have no saved list, so they keep this local one.
  List<_ChecklistItem> _items = [
    _ChecklistItem('Passport', isComplete: true),
    _ChecklistItem('Flight ticket', isComplete: true, isSaved: true),
    _ChecklistItem('Travel adapter', isComplete: true),
    _ChecklistItem('Charger', isComplete: true),
    _ChecklistItem('Hotel Invoice', isPending: true),
    _ChecklistItem('Travel insurance'),
    _ChecklistItem('Toiletries'),
    _ChecklistItem('Camera'),
    _ChecklistItem('Medication'),
  ];

  bool get _saved => ChecklistService.isSavedTrip(widget.tripId);

  @override
  void initState() {
    super.initState();
    if (_saved) {
      _load();
    } else {
      _loading = false;
    }
  }

  Future<void> _load() async {
    try {
      final entries = await _service.getItems(widget.tripId);
      if (!mounted) return;
      setState(() {
        _items = entries
            .map(
              (e) => _ChecklistItem(
                e.title,
                id: e.id,
                isComplete: e.isComplete,
                isPending: e.isPending,
                isSaved: e.isSaved,
              ),
            )
            .toList();
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Couldn't load your checklist.";
      });
    }
  }

  void _showProblem(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggle(_ChecklistItem item) async {
    final next = !item.isComplete;
    setState(() => item.isComplete = next);
    if (!_saved || item.id == null) return;
    try {
      await _service.setComplete(widget.tripId, item.id!, next);
    } catch (_) {
      if (!mounted) return;
      setState(() => item.isComplete = !next); // put it back
      _showProblem("Couldn't save that change. Please try again.");
    }
  }

  int get _completedCount => _items.where((item) => item.isComplete).length;

  void _addItem() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add checklist item'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Sunglasses'),
          onSubmitted: (_) => _saveItem(dialogContext, controller.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => _saveItem(dialogContext, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  Future<void> _saveItem(BuildContext dialogContext, String value) async {
    final itemName = value.trim();
    if (itemName.isEmpty) return;
    Navigator.of(dialogContext).pop();
    if (!_saved) {
      setState(() => _items.add(_ChecklistItem(itemName)));
      return;
    }
    try {
      final entry = await _service.addItem(widget.tripId, itemName);
      if (!mounted) return;
      setState(() => _items.add(_ChecklistItem(entry.title, id: entry.id)));
    } catch (_) {
      _showProblem("Couldn't add that item. Please try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryGreen),
              )
            : _error != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _loading = true;
                          _error = null;
                        });
                        _load();
                      },
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              )
            : _showTicketDetails
            ? _buildTicketDetails(context)
            : _buildChecklist(context),
      ),
    );
  }

  bool _showTicketDetails = false;

  Widget _buildChecklist(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PageTitle(
                title: 'Travel Checklist',
                onBack: () => context.pop(),
              ),
              const SizedBox(height: 7),
              Text(
                '$_completedCount of ${_items.length} completed',
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _items.isEmpty ? 0 : _completedCount / _items.length,
                  minHeight: 5,
                  backgroundColor: const Color(0xFFF0F0F5),
                  color: AppTheme.primaryGreen,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            itemCount: _items.length,
            itemBuilder: (context, index) => _buildChecklistRow(index),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add, size: 17),
                  label: const Text('Add item'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryGreen,
                    minimumSize: const Size.fromHeight(42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  key: const ValueKey('checklist-next'),
                  onPressed: () => _openTicket(),
                  icon: const Icon(Icons.arrow_forward, size: 17),
                  label: const Text('Next: ticket'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChecklistRow(int index) {
    final item = _items[index];
    return InkWell(
      onTap: item.isSaved
          ? () => _openTicket()
          : () => _toggle(item),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 40,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F3F7),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(
              item.isComplete
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: item.isComplete
                  ? AppTheme.primaryGreen
                  : const Color(0xFFA5A5AD),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (item.isSaved)
              _ItemBadge(
                label: 'Saved',
                color: AppTheme.primaryGreen,
                onTap: () => _openTicket(),
              )
            else if (item.isPending)
              const _ItemBadge(label: 'Pending', color: Color(0xFFFF823E)),
          ],
        ),
      ),
    );
  }

  static const _ticketLabels = <String, String>{
    'airline': 'Airline',
    'flightNumber': 'Flight number',
    'fromCode': 'From (code)',
    'fromCity': 'From (city)',
    'toCode': 'To (code)',
    'toCity': 'To (city)',
    'passenger': 'Passenger',
    'bookingRef': 'Booking ref',
    'date': 'Date',
    'gate': 'Gate',
    'departure': 'Departure',
    'arrival': 'Arrival',
    'duration': 'Duration',
  };

  final Map<String, TextEditingController> _ticket = {
    for (final key in _ticketLabels.keys) key: TextEditingController(),
  };
  bool _ticketLoaded = false;
  bool _ticketSaving = false;

  @override
  void dispose() {
    for (final c in _ticket.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _openTicket() async {
    setState(() => _showTicketDetails = true);
    if (_ticketLoaded || !_saved) return;
    try {
      final data = await _service.getTicket(widget.tripId);
      if (!mounted) return;
      setState(() {
        for (final e in _ticket.entries) {
          e.value.text = data[e.key] ?? '';
        }
        _ticketLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      _showProblem("Couldn't load your ticket. You can still type it in.");
    }
  }

  bool _scanning = false;

  String _mimeFor(String name) {
    final e = name.toLowerCase().split('.').last;
    return switch (e) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }

  Future<void> _chooseScanSource() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.upload_file_rounded),
              title: const Text('Upload a PDF or photo'),
              onTap: () => Navigator.pop(sheetContext, 'file'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(sheetContext, 'camera'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    Uint8List? bytes;
    String name = 'ticket.jpg';
    try {
      if (choice == 'camera') {
        final shot = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85);
        if (shot == null) return;
        bytes = await shot.readAsBytes();
        name = shot.name.isNotEmpty ? shot.name : 'ticket.jpg';
      } else {
        final res = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
          withData: true,
        );
        final f = res?.files.single;
        if (f == null || f.bytes == null) return;
        bytes = f.bytes;
        name = f.name;
      }
    } catch (_) {
      _showProblem("Couldn't open that file. Please try again or type it in.");
      return;
    }
    if (bytes == null || !mounted) return;
    if (!_saved) {
      _showProblem('Sample trips cannot read a ticket. Open a real trip.');
      return;
    }
    setState(() => _scanning = true);
    try {
      final found = await _service.scanTicket(widget.tripId, bytes, _mimeFor(name));
      if (!mounted) return;
      setState(() {
        for (final e in found.entries) {
          _ticket[e.key]?.text = e.value;
        }
      });
      _showProblem('We filled in what we could read. Please check it, then tap Save.');
    } catch (e) {
      _showProblem(e is ApiException ? e.message : "Couldn't read the ticket. Please type it in.");
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _saveTicket() async {
    if (!_saved) {
      _showProblem('Sample trips cannot save a ticket. Open a real trip.');
      return;
    }
    setState(() => _ticketSaving = true);
    try {
      final saved = await _service.saveTicket(widget.tripId, {
        for (final e in _ticket.entries) e.key: e.value.text.trim(),
      });
      if (!mounted) return;
      setState(() {
        for (final e in _ticket.entries) {
          e.value.text = saved[e.key] ?? e.value.text;
        }
      });
      _showProblem('Ticket saved.');
    } catch (_) {
      _showProblem("Couldn't save the ticket. Please try again.");
    } finally {
      if (mounted) setState(() => _ticketSaving = false);
    }
  }

  Widget _ticketField(String key) {
    return TextField(
      controller: _ticket[key],
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: _ticketLabels[key],
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFF5F7F6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _ticketRow(String left, String right) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: _ticketField(left)),
          const SizedBox(width: 8),
          Expanded(child: _ticketField(right)),
        ],
      ),
    );
  }

  Widget _buildTicketDetails(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: _PageTitle(
            title: 'Flight ticket',
            onBack: () => setState(() => _showTicketDetails = false),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
            children: [
              const Text(
                'Type in your own ticket details, or upload / take a photo of your ticket and we will fill them in. Only you can see them.',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _scanning ? null : _chooseScanSource,
                icon: _scanning
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.document_scanner_outlined),
                label: Text(_scanning ? 'Reading your ticket...' : 'Upload or take a photo of ticket'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryGreen,
                  side: const BorderSide(color: AppTheme.primaryGreen),
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                ),
              ),
              const SizedBox(height: 12),
              _ticketRow('airline', 'flightNumber'),
              _ticketRow('fromCode', 'fromCity'),
              _ticketRow('toCode', 'toCity'),
              _ticketRow('passenger', 'bookingRef'),
              _ticketRow('date', 'gate'),
              _ticketRow('departure', 'arrival'),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ticketField('duration'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('ticket-previous'),
                  onPressed: () => setState(() => _showTicketDetails = false),
                  icon: const Icon(Icons.arrow_back, size: 17),
                  label: const Text('Previous: checklist'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryGreen,
                    minimumSize: const Size.fromHeight(42),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _ticketSaving ? null : _saveTicket,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(42),
                  ),
                  child: Text(_ticketSaving ? 'Saving...' : 'Save'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PageTitle extends StatelessWidget {
  const _PageTitle({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.chevron_left, size: 25),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 28, height: 34),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _ItemBadge extends StatelessWidget {
  const _ItemBadge({
    required this.label,
    required this.color,
    this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    return onTap == null ? badge : GestureDetector(onTap: onTap, child: badge);
  }
}

class _ChecklistItem {
  _ChecklistItem(
    this.title, {
    this.id,
    this.isComplete = false,
    this.isPending = false,
    this.isSaved = false,
  });

  final String? id;
  final String title;
  bool isComplete;
  final bool isPending;
  final bool isSaved;
}
