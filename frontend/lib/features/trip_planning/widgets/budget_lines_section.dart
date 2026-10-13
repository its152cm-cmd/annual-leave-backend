import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/trip_budget_service.dart';

Color _statusColor(String s) => switch (s) {
      'booked' => const Color(0xFF1B9E4B),
      'pending' => const Color(0xFFB26A00),
      'planned' => const Color(0xFF0066FF),
      _ => AppTheme.textMuted,
    };

/// The trip's cost split into line items with a status (Estimated / Planned / Pending / Booked).
/// The host edits lines and attaches booking documents; everyone else can look.
class BudgetLinesSection extends StatefulWidget {
  const BudgetLinesSection({super.key, required this.tripId});
  final String tripId;

  @override
  State<BudgetLinesSection> createState() => _BudgetLinesSectionState();
}

class _BudgetLinesSectionState extends State<BudgetLinesSection> {
  final TripBudgetService _service = TripBudgetService();
  BudgetLinesData? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await _service.load(widget.tripId);
      if (mounted) setState(() { _data = d; _error = null; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e is ApiException ? e.message : 'Could not load the budget lines.'; _loading = false; });
    }
  }

  void _snack(String t) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  String _m(double v) => '${_data?.currency ?? 'RM'} ${v.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')}';

  Future<void> _changeStatus(BudgetLine line) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(padding: EdgeInsets.all(14), child: Text('Status', style: TextStyle(fontWeight: FontWeight.w800))),
          for (final s in budgetStatuses)
            ListTile(
              leading: Icon(s == line.status ? Icons.radio_button_checked : Icons.radio_button_off, color: _statusColor(s)),
              title: Text(statusLabel(s)),
              onTap: () => Navigator.pop(ctx, s),
            ),
        ]),
      ),
    );
    if (picked == null || picked == line.status) return;
    try {
      await _service.update(widget.tripId, line.id, {'status': picked});
      await _load();
    } catch (e) {
      _snack(e is ApiException ? e.message : 'Could not change the status.');
    }
  }

  Future<void> _addLine() async {
    final title = TextEditingController();
    final amount = TextEditingController();
    String category = 'Other Expenses';
    String status = 'planned';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Add a line'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: title, maxLength: 140, decoration: const InputDecoration(labelText: 'What is it?')),
              TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: category,
                items: [for (final c in budgetCategories) DropdownMenuItem(value: c, child: Text(c))],
                onChanged: (v) => setS(() => category = v ?? category),
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              DropdownButtonFormField<String>(
                initialValue: status,
                items: [for (final s in budgetStatuses) DropdownMenuItem(value: s, child: Text(statusLabel(s)))],
                onChanged: (v) => setS(() => status = v ?? status),
                decoration: const InputDecoration(labelText: 'Status'),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
          ],
        ),
      ),
    );
    final name = title.text.trim();
    final value = double.tryParse(amount.text.trim().replaceAll(',', '')) ?? 0;
    title.dispose();
    amount.dispose();
    if (ok != true || name.isEmpty) return;
    try {
      await _service.add(widget.tripId, category: category, title: name, amount: value, status: status);
      await _load();
    } catch (e) {
      _snack(e is ApiException ? e.message : 'Could not add the line.');
    }
  }

  void _openLine(BudgetLine line) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => _LineSheet(tripId: widget.tripId, line: line, canEdit: _data?.canEdit ?? false, service: _service),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)));
    }
    final d = _data;
    if (d == null) {
      return Padding(padding: const EdgeInsets.all(16), child: Text(_error ?? 'Could not load the budget lines.', style: const TextStyle(color: AppTheme.textMuted)));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppTheme.cardBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.borderSubtle)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Trip total ${_m(d.total)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          if (d.budget > 0)
            Text(
              d.remaining != null && d.remaining! < 0 ? 'Over your ${_m(d.budget)} budget by ${_m(-d.remaining!)}' : '${_m(d.remaining ?? 0)} left of ${_m(d.budget)}',
              style: TextStyle(fontSize: 12, color: (d.remaining ?? 0) < 0 ? const Color(0xFFD70015) : AppTheme.textMuted),
            ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (final s in budgetStatuses.reversed)
              if ((d.byStatus[s] ?? 0) > 0) _chip('${statusLabel(s)} ${_m(d.byStatus[s]!)}', _statusColor(s)),
          ]),
        ]),
      ),
      const SizedBox(height: 12),
      for (final line in d.lines) _lineRow(line, d.canEdit),
      if (d.lines.isEmpty)
        const Padding(padding: EdgeInsets.all(16), child: Text('Lines appear once the itinerary has been generated.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12))),
      if (d.canEdit)
        TextButton.icon(onPressed: _addLine, icon: const Icon(Icons.add), label: const Text('Add a line')),
      if (!d.canEdit)
        const Padding(padding: EdgeInsets.only(top: 6), child: Text('Only the host can change these lines.', style: TextStyle(color: AppTheme.textMuted, fontSize: 11))),
    ]);
  }

  Widget _chip(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
        child: Text(t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
      );

  Widget _lineRow(BudgetLine l, bool canEdit) {
    final warn = l.documents.any((x) => x.checkStatus == 'check');
    return InkWell(
      onTap: () => _openLine(l),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              Row(children: [
                Text(l.category, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                if (l.documents.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Icon(warn ? Icons.warning_amber_rounded : Icons.attach_file, size: 12, color: warn ? const Color(0xFFB26A00) : AppTheme.textMuted),
                  Text('${l.documents.length}', style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                ],
              ]),
            ]),
          ),
          Text(_m(l.amount), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          InkWell(
            onTap: canEdit ? () => _changeStatus(l) : null,
            child: _chip(statusLabel(l.status), _statusColor(l.status)),
          ),
        ]),
      ),
    );
  }
}

class _LineSheet extends StatefulWidget {
  const _LineSheet({required this.tripId, required this.line, required this.canEdit, required this.service});
  final String tripId;
  final BudgetLine line;
  final bool canEdit;
  final TripBudgetService service;

  @override
  State<_LineSheet> createState() => _LineSheetState();
}

class _LineSheetState extends State<_LineSheet> {
  late List<BudgetDoc> _docs = [...widget.line.documents];
  late final TextEditingController _amount = TextEditingController(text: widget.line.amount.round().toString());
  bool _busy = false;
  String? _msg;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  String _mimeFor(String name) {
    final e = name.toLowerCase().split('.').last;
    return switch (e) { 'pdf' => 'application/pdf', 'png' => 'image/png', 'webp' => 'image/webp', _ => 'image/jpeg' };
  }

  Future<void> _upload() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    final f = res?.files.single;
    if (f == null || f.bytes == null) return;
    setState(() { _busy = true; _msg = null; });
    try {
      final d = await widget.service.upload(widget.tripId, widget.line.id, fileName: f.name, mimeType: _mimeFor(f.name), bytes: f.bytes!);
      if (mounted) setState(() => _docs = [..._docs, d]);
    } catch (e) {
      if (mounted) setState(() => _msg = e is ApiException ? e.message : 'Upload failed.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _recheck(BudgetDoc d) async {
    setState(() { _busy = true; _msg = null; });
    try {
      final n = await widget.service.recheck(widget.tripId, widget.line.id, d.id);
      if (mounted) setState(() => _docs = [for (final x in _docs) x.id == d.id ? n : x]);
    } catch (e) {
      if (mounted) setState(() => _msg = e is ApiException ? e.message : 'Could not check.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _view(BudgetDoc d) async {
    try {
      final url = await widget.service.documentUrl(widget.tripId, widget.line.id, d.id);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) setState(() => _msg = e is ApiException ? e.message : 'Could not open the file.');
    }
  }

  Future<void> _delete(BudgetDoc d) async {
    try {
      await widget.service.removeDocument(widget.tripId, widget.line.id, d.id);
      if (mounted) setState(() => _docs = _docs.where((x) => x.id != d.id).toList());
    } catch (e) {
      if (mounted) setState(() => _msg = e is ApiException ? e.message : 'Could not delete.');
    }
  }

  Future<void> _saveAmount() async {
    final v = double.tryParse(_amount.text.trim().replaceAll(',', ''));
    if (v == null) return;
    try {
      await widget.service.update(widget.tripId, widget.line.id, {'amount': v});
      if (mounted) setState(() => _msg = 'Amount saved.');
    } catch (e) {
      if (mounted) setState(() => _msg = e is ApiException ? e.message : 'Could not save.');
    }
  }

  Future<void> _deleteLine() async {
    try {
      await widget.service.remove(widget.tripId, widget.line.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _msg = e is ApiException ? e.message : 'Could not delete.');
    }
  }

  Future<void> _book() async {
    final u = Uri.tryParse(widget.line.bookingUrl);
    if (u != null) await launchUrl(u, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.line;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: ListView(shrinkWrap: true, children: [
        Text(l.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        Text('${l.category} · ${statusLabel(l.status)}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        const SizedBox(height: 12),
        if (widget.canEdit)
          Row(children: [
            Expanded(child: TextField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount', isDense: true))),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: _saveAmount, child: const Text('Save')),
          ]),
        if (l.bookingUrl.isNotEmpty)
          Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: _book, icon: const Icon(Icons.open_in_new, size: 16), label: const Text('Open booking website'))),
        const SizedBox(height: 12),
        const Text('Booking documents', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        if (_docs.isEmpty) const Text('No documents yet.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        for (final d in _docs) _docCard(d),
        if (widget.canEdit) ...[
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: _busy ? null : _upload,
            icon: _busy ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.upload_file),
            label: Text(_busy ? 'Checking...' : 'Upload ticket or confirmation'),
          ),
          const Padding(padding: EdgeInsets.only(top: 4), child: Text('PDF, JPG, PNG or WebP up to 8 MB. The AI checks the dates against your trip.', style: TextStyle(fontSize: 10, color: AppTheme.textMuted))),
        ],
        if (_msg != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_msg!, style: const TextStyle(fontSize: 12, color: AppTheme.textDark))),
        if (widget.canEdit) TextButton.icon(onPressed: _deleteLine, icon: const Icon(Icons.delete_outline, color: Color(0xFFD70015)), label: const Text('Delete this line', style: TextStyle(color: Color(0xFFD70015)))),
      ]),
    );
  }

  Widget _docCard(BudgetDoc d) {
    final ok = d.checkStatus == 'valid';
    final color = ok ? const Color(0xFF1B9E4B) : (d.checkStatus == 'check' ? const Color(0xFFB26A00) : AppTheme.textMuted);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(ok ? Icons.verified_outlined : (d.checkStatus == 'check' ? Icons.warning_amber_rounded : Icons.help_outline), color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(d.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
          IconButton(visualDensity: VisualDensity.compact, tooltip: 'Open', icon: const Icon(Icons.open_in_new, size: 18), onPressed: () => _view(d)),
          if (widget.canEdit) IconButton(visualDensity: VisualDensity.compact, tooltip: 'Delete', icon: const Icon(Icons.close, size: 18), onPressed: () => _delete(d)),
        ]),
        Text(ok ? 'Looks valid for your trip' : (d.checkStatus == 'check' ? 'Please check' : 'Not checked yet'), style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
        for (final n in d.notes) Padding(padding: const EdgeInsets.only(top: 2), child: Text('• $n', style: const TextStyle(fontSize: 11))),
        if (d.checkStatus == 'unchecked' && widget.canEdit)
          TextButton(onPressed: _busy ? null : () => _recheck(d), child: const Text('Check again')),
      ]),
    );
  }
}
