import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/receipt.dart';
import '../../services/expense_service.dart';

class ScannedReceiptScreen extends StatefulWidget {
  final String groupId;
  final Receipt? initialReceipt;
  final bool confirmedReceipt;

  const ScannedReceiptScreen({
    super.key,
    required this.groupId,
    this.initialReceipt,
    this.confirmedReceipt = false,
  });

  @override
  State<ScannedReceiptScreen> createState() => _ScannedReceiptScreenState();
}

class _ScannedReceiptScreenState extends State<ScannedReceiptScreen> {
  final ExpenseService _expenseService = ExpenseService();
  Receipt? _receipt;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReceipt();
  }

  Future<void> _loadReceipt() async {
    final receipt =
        widget.initialReceipt ?? await _expenseService.getScannedReceipt(
          groupId: widget.groupId,
        );
    if (mounted) {
      setState(() {
        _receipt = receipt;
        _isLoading = false;
      });
    }
  }

  Widget _editButton(ReceiptItem item) {
    if (widget.confirmedReceipt) return const SizedBox(width: 4);
    return InkWell(
      onTap: () => _editItem(item),
      borderRadius: BorderRadius.circular(12),
      child: const Padding(
        padding: EdgeInsets.all(6),
        child: Icon(Icons.edit_outlined, size: 16, color: AppTheme.textMuted),
      ),
    );
  }

  /// Fix a name, price or quantity the scan got wrong, or remove a line.
  /// [existing] null = add a new line.
  Future<void> _editItem(ReceiptItem? existing) async {
    final receipt = _receipt;
    if (receipt == null) return;
    final isNew = existing == null;
    final nameController = TextEditingController(text: existing?.title ?? '');
    final priceController = TextEditingController(
      text: existing == null ? '' : existing.price.toStringAsFixed(2),
    );
    final quantityController = TextEditingController(
      text: '${existing?.quantity ?? 1}',
    );
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isNew ? 'Add item' : 'Edit item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Price per unit (RM)',
                ),
              ),
              TextField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity'),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
            ],
          ),
          actions: [
            if (!isNew && receipt.items.length > 1)
              TextButton(
                onPressed: () {
                  setState(() => receipt.items.remove(existing));
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final name = nameController.text.trim();
                final price = double.tryParse(
                  priceController.text.trim().replaceAll(',', '.'),
                );
                final quantity = int.tryParse(quantityController.text.trim());
                if (name.isEmpty || name.length > 120) {
                  setDialogState(() => error = 'Enter a name (up to 120 characters).');
                } else if (price == null || price < 0 || price > 1000000) {
                  setDialogState(() => error = 'Enter a valid price.');
                } else if (quantity == null || quantity < 1 || quantity > 99) {
                  setDialogState(() => error = 'Quantity must be 1 to 99.');
                } else {
                  setState(() {
                    if (existing == null) {
                      // a new line is shared by everyone until you change it
                      receipt.items.add(
                        ReceiptItem(
                          id: 'item_${DateTime.now().microsecondsSinceEpoch}',
                          title: name,
                          price: double.parse(price.toStringAsFixed(2)),
                          quantity: quantity,
                          assignedMemberIds: [
                            for (final member in receipt.memberSplits) member.id,
                          ],
                        ),
                      );
                    } else {
                      existing
                        ..title = name
                        ..price = double.parse(price.toStringAsFixed(2))
                        ..quantity = quantity;
                    }
                  });
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    priceController.dispose();
    quantityController.dispose();
  }

  void _toggleMemberForItem(ReceiptItem item, String memberId) {
    setState(() {
      if (item.assignedMemberIds.contains(memberId)) {
        if (item.assignedMemberIds.length > 1) {
          item.assignedMemberIds.remove(memberId);
        }
      } else {
        item.assignedMemberIds.add(memberId);
      }
    });
  }

  void _confirmSplit() async {
    if (_receipt != null) {
      await _expenseService.confirmReceiptSplit(
        _receipt!,
        groupId: widget.groupId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense split confirmed and posted!')),
        );
        final alert = ExpenseService.takeBudgetAlert();
        if (alert != null) {
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              icon: const Icon(Icons.warning_amber_rounded, color: Color(0xFFD70015), size: 32),
              title: const Text('Budget alert'),
              content: Text(alert),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
            ),
          );
        }
        if (mounted) Navigator.pop(context);
      }
    }
  }

  Future<void> _resolveSplit() async {
    final receipt = _receipt;
    if (receipt == null) return;
    await _expenseService.resolveReceipt(
      receipt.id,
      groupId: widget.groupId,
    );
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Receipt split settled.')),
    );
  }

  Widget _memberAvatar({
    required String? avatarUrl,
    required String fallbackName,
    required Color backgroundColor,
    required Color foregroundColor,
    required double radius,
  }) {
    final hasAvatar = avatarUrl != null && avatarUrl.trim().isNotEmpty;
    final ImageProvider? image = !hasAvatar
        ? null
        : avatarUrl.startsWith('assets/')
        ? AssetImage(avatarUrl)
        : NetworkImage(avatarUrl);
    final initials = fallbackName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0])
        .join()
        .toUpperCase();

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      backgroundImage: image,
      child: hasAvatar
          ? null
          : Text(
              initials,
              style: TextStyle(
                color: foregroundColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
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
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.confirmedReceipt ? 'Receipt details' : 'Back',
          style: TextStyle(
            color: AppTheme.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  children: [
                    // 1. Merchant Header & Receipt Items Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _receipt!.merchantName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.textDark,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _receipt!.timestamp,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.receipt_long,
                                  color: AppTheme.primaryGreen,
                                  size: 22,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),

                          // Line Items
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _receipt!.items.length,
                            separatorBuilder: (_, _) => const Divider(height: 20),
                            itemBuilder: (context, index) {
                              final item = _receipt!.items[index];
                              final itemTotal = item.price * item.quantity;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                item.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: AppTheme.textDark,
                                                ),
                                              ),
                                            ),
                                            _editButton(item),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Text(
                                            'RM ${itemTotal.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                              color: AppTheme.textDark,
                                            ),
                                          ),
                                          _editButton(item),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${item.quantity} × RM ${item.price.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  // Member Avatar Toggles driven by receipt.memberSplits
                                  Row(
                                    children: [
                                      const Icon(Icons.people_outline,
                                          size: 18, color: AppTheme.textMuted),
                                      const SizedBox(width: 10),
                                      ..._receipt!.memberSplits.map((m) {
                                        final isAssigned =
                                            item.assignedMemberIds.contains(m.id);
                                        final memberColor = Color(m.colorHex);

                                        return GestureDetector(
                                          onTap: widget.confirmedReceipt
                                              ? null
                                              : () =>
                                                    _toggleMemberForItem(item, m.id),
                                          child: Container(
                                            margin: const EdgeInsets.only(right: 8),
                                            width: 32,
                                            height: 32,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: isAssigned
                                                  ? memberColor
                                                  : Colors.white,
                                              border: Border.all(
                                                color: isAssigned
                                                    ? Colors.transparent
                                                    : Colors.grey.shade300,
                                              ),
                                            ),
                                            child: _memberAvatar(
                                              avatarUrl: m.avatarUrl,
                                              fallbackName: m.name,
                                              backgroundColor: isAssigned
                                                  ? memberColor
                                                  : Colors.white,
                                              foregroundColor: isAssigned
                                                  ? Colors.white
                                                  : AppTheme.textMuted,
                                              radius: 14,
                                            ),
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                          if (!widget.confirmedReceipt) ...[
                            const Divider(height: 20),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () => _editItem(null),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add item'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.primaryGreen,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Category (a remark for the budget; the person chooses)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'What is this expense for?',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textDark),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Used as a remark and counted against that part of the trip budget.',
                            style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              for (final c in const [
                                ('Food', 'Food'),
                                ('Hotel', 'Accommodation'),
                                ('Tickets', 'Activities'),
                                ('Transport', 'Transport'),
                                ('Other', 'Other Expenses'),
                              ])
                                ChoiceChip(
                                  label: Text(c.$1),
                                  selected: _receipt!.type == c.$2,
                                  showCheckmark: false,
                                  selectedColor: AppTheme.primaryGreen,
                                  backgroundColor: Colors.grey.shade100,
                                  side: BorderSide.none,
                                  labelStyle: TextStyle(
                                    color: _receipt!.type == c.$2 ? Colors.white : AppTheme.textDark,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                  onSelected: widget.confirmedReceipt
                                      ? null
                                      : (_) => setState(() => _receipt!.type = c.$2),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Total & Percentage Split Breakdown Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'TOTAL',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textMuted,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                'RM ${_receipt!.totalAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.textDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Dynamic Percentage Splits
                          ..._receipt!.memberSplits.map((m) {
                            final percent =
                                _receipt!.sharePercentages[m.id] ??
                                m.splitPercentage;
                            final memberColor = Color(m.colorHex);
                            final calculatedAmount = _receipt!.shareFor(m);
                            final isSettled = m.id == _receipt!.paidByMemberId ||
                              m.settledAmount >= calculatedAmount - 0.005;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: memberColor,
                                    child: _memberAvatar(
                                      avatarUrl: m.avatarUrl,
                                      fallbackName: m.name,
                                      backgroundColor: memberColor,
                                      foregroundColor: Colors.white,
                                      radius: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.cardBackground,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          '$percent',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        const Text('%',
                                            style: TextStyle(color: AppTheme.textMuted)),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'RM ${calculatedAmount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: AppTheme.textDark,
                                    ),
                                  ),
                                  if (widget.confirmedReceipt) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      isSettled ? 'Settled' : 'Pending',
                                      style: TextStyle(
                                        color: isSettled
                                            ? AppTheme.primaryGreen
                                            : const Color(0xFFE34D4D),
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. "Paid By" Container
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Paid by',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Row(
                            children: [
                              _memberAvatar(
                                avatarUrl: _receipt!.paidByMemberAvatarUrl,
                                fallbackName: _receipt!.paidByMemberName,
                                backgroundColor: const Color(0xFF66BB6A),
                                foregroundColor: Colors.white,
                                radius: 16,
                              ),
                              SizedBox(width: 8),
                              Text(
                                _receipt!.paidByMemberName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textDark,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (widget.confirmedReceipt && !_receipt!.isSplitResolved)
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryGreen,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: _resolveSplit,
                          child: const Text(
                            'Resolve Split',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    else if (widget.confirmedReceipt)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Split settled',
                          style: TextStyle(
                            color: AppTheme.primaryGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryGreen,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: _confirmSplit,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Confirm split',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ],
                        ),
                      ),
                      ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}

class ConfirmedReceiptDetailScreen extends StatelessWidget {
  const ConfirmedReceiptDetailScreen({
    super.key,
    required this.groupId,
    required this.receipt,
  });

  final String groupId;
  final Receipt receipt;

  @override
  Widget build(BuildContext context) => ScannedReceiptScreen(
    groupId: groupId,
    initialReceipt: receipt,
    confirmedReceipt: true,
  );
}
