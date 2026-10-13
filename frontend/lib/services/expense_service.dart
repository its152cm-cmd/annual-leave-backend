import 'package:flutter/foundation.dart';

import '../core/api/api_client.dart';
import '../mock/mock_receipt.dart';
import '../models/group_member.dart';
import '../models/receipt.dart';
import 'account_service.dart';
import 'group_summary_service.dart';

class ExpenseMemberBalance {
  const ExpenseMemberBalance({
    required this.memberId,
    required this.name,
    required this.colorHex,
    required this.netBalance,
  });

  final String memberId;
  final String name;
  final int colorHex;
  final double netBalance;
}

class ExpenseOwedPair {
  const ExpenseOwedPair({
    required this.debtorId,
    required this.debtorName,
    required this.creditorId,
    required this.creditorName,
    required this.amount,
  });

  final String debtorId;
  final String debtorName;
  final String creditorId;
  final String creditorName;
  final double amount;
}

class ExpenseFinancialSummary {
  const ExpenseFinancialSummary({
    required this.receipts,
    required this.balances,
    required this.owedPairs,
    required this.currentUserId,
    required this.categoryTotals,
    required this.confirmedPaidAmount,
    required this.waitingToResolveAmount,
  });

  final List<Receipt> receipts;
  final List<ExpenseMemberBalance> balances;
  final List<ExpenseOwedPair> owedPairs;
  final String currentUserId;
  final Map<String, double> categoryTotals;
  final double confirmedPaidAmount;
  final double waitingToResolveAmount;
  double get totalSpent =>
      receipts.fold(0, (sum, receipt) => sum + receipt.totalAmount);
}

class ExpenseService {
  /// Set when saving a receipt took the trip near or over its budget; read once by the screen.
  static String? pendingBudgetAlert;

  static String? takeBudgetAlert() {
    final message = pendingBudgetAlert;
    pendingBudgetAlert = null;
    return message;
  }

  static final ValueNotifier<int> revision = ValueNotifier(0);
  static final Map<String, List<Receipt>> _recentReceipts = {};
  static final Map<String, Receipt> _scannedReceipts = {};
  static final Map<String, Future<void>> _loadFutures = {};
  static final Map<String, String> _memberSignatureByGroup = {};
  static final Map<String, List<GroupMember>> _savedMembers = {};

  /// Forget everything kept in memory (used when someone signs out).
  static void clearCache() {
    _recentReceipts.clear();
    _scannedReceipts.clear();
    _loadFutures.clear();
    _memberSignatureByGroup.clear();
    _savedMembers.clear();
    revision.value++;
  }

  final AccountService _accountService = AccountService();
  final GroupSummaryService _groupSummaryService = GroupSummaryService();
  final ApiClient _api = ApiClient();

  static final RegExp _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Real trips ("trip_<uuid>") keep their receipts in the backend. Old sample
  /// trips keep using the built-in sample data.
  static bool _isSavedGroup(String groupId) =>
      groupId.startsWith('trip_') &&
      _uuid.hasMatch(groupId.substring('trip_'.length));

  /// True when this chat belongs to one of the person's real trips.
  static bool isSavedGroup(String groupId) => _isSavedGroup(groupId);

  static String _tripIdOf(String groupId) => groupId.substring('trip_'.length);

  static String chatIdForTripId(String tripId) {
    if (tripId.startsWith('GROUP_')) return tripId.substring('GROUP_'.length);
    if (tripId.startsWith('group_') || tripId.startsWith('trip_')) return tripId;
    return 'trip_$tripId';
  }

  Future<List<GroupMember>> _getChatMembers(String groupId) async {
    if (_isSavedGroup(groupId)) {
      final cached = _savedMembers[groupId];
      if (cached != null) return cached;
      final r = await _api.get('/api/expenses/${_tripIdOf(groupId)}/members');
      return _savedMembers[groupId] = (r as List)
          .map((e) => GroupMember.fromJson({
                ...Map<String, dynamic>.from(e as Map),
                'leaveBalanceSummary': '',
              }))
          .toList();
    }
    final rawMembers = await _groupSummaryService.getGroupMembers(groupId);
    final currentUser = await _accountService.getCurrentUser();
    final membersById = <String, GroupMember>{};
    for (final member in rawMembers) {
      membersById.putIfAbsent(member.id, () => member);
    }
    if (membersById.isEmpty && currentUser != null) {
      membersById['user_me'] = GroupMember(
        id: 'user_me',
        name: currentUser.name,
        avatarUrl: currentUser.avatarUrl,
        isMe: true,
        leaveBalanceSummary: '',
      );
    }
    return membersById.values.toList();
  }

  Future<void> _ensureLoaded(String groupId) async {
    try {
      await (_loadFutures[groupId] ??= _load(groupId));
    } catch (_) {
      _loadFutures.remove(groupId); // try again next time
      rethrow;
    }
    final members = await _getChatMembers(groupId);
    final memberSignature = members
        .map((member) => '${member.id}\u001f${member.name}\u001f${member.avatarUrl}')
        .join('\u001e');
    if (_memberSignatureByGroup[groupId] == memberSignature) {
      return;
    }
    // saved receipts already carry the right people and shares
    final receipts = _isSavedGroup(groupId)
        ? <Receipt>[]
        : [...?_recentReceipts[groupId]];
    final scannedReceipt = _scannedReceipts[groupId];
    if (scannedReceipt != null) receipts.add(scannedReceipt);
    for (final receipt in receipts) {
      _syncReceiptMembers(receipt, members, initializeAssignments: false);
    }
    _memberSignatureByGroup[groupId] = memberSignature;
  }

  Future<List<Receipt>> _fetchSavedReceipts(String groupId) async {
    final r = await _api.get('/api/expenses/${_tripIdOf(groupId)}/receipts');
    return (r as List)
        .map((e) => Receipt.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Receipt _freshScannedReceipt(List<GroupMember> members) => _syncReceiptMembers(
    Receipt.fromJson(mockScannedReceiptData),
    members,
    initializeAssignments: true,
  );

  Future<void> _load(String groupId) async {
    _savedMembers.remove(groupId); // read the people again whenever we reload
    final members = await _getChatMembers(groupId);
    if (_isSavedGroup(groupId)) {
      _recentReceipts[groupId] = await _fetchSavedReceipts(groupId);
    } else {
      _recentReceipts[groupId] = mockRecentReceipts
          .map((data) => Receipt.fromJson(data))
          .map((receipt) => _syncReceiptMembers(receipt, members, initializeAssignments: true))
          .toList();
    }
    _scannedReceipts[groupId] = _freshScannedReceipt(members);
    _memberSignatureByGroup[groupId] = members
        .map((member) => '${member.id}\u001f${member.name}\u001f${member.avatarUrl}')
        .join('\u001e');
  }

  Receipt _syncReceiptMembers(
    Receipt receipt,
    List<GroupMember> members, {
    required bool initializeAssignments,
  }) {
    if (members.isEmpty) {
      receipt
        ..memberSplits.clear()
        ..paidByMemberId = ''
        ..paidByMemberName = ''
        ..paidByMemberAvatar = ''
        ..paidByMemberAvatarUrl = null;
      for (final item in receipt.items) {
        item.assignedMemberIds.clear();
      }
      return receipt;
    }
    final byId = {for (final member in members) member.id: member};
    final existingSplits = {for (final split in receipt.memberSplits) split.id: split};
    final payer = byId[receipt.paidByMemberId] ??
        members.where((member) => member.isMe).firstOrNull ??
        members.first;
    receipt
      ..paidByMemberId = payer.id
      ..paidByMemberName = payer.name
      ..paidByMemberAvatar = _initials(payer.name)
      ..paidByMemberAvatarUrl = payer.avatarUrl;
    final basePercentage = 100 ~/ members.length;
    final remainder = 100 % members.length;
    receipt.memberSplits
      ..clear()
      ..addAll([
        for (var index = 0; index < members.length; index++)
          _splitForMember(
            members[index],
            existingSplits[members[index].id],
            basePercentage + (index < remainder ? 1 : 0),
          ),
      ]);
    for (final item in receipt.items) {
      final priorAssignments = item.assignedMemberIds.toList();
      item.assignedMemberIds = priorAssignments
          .where(byId.containsKey)
          .toSet()
          .toList();
      if (initializeAssignments &&
          priorAssignments.isNotEmpty &&
          item.assignedMemberIds.isEmpty) {
        item.assignedMemberIds = members.map((member) => member.id).toList();
      }
    }
    return receipt;
  }

  ReceiptMemberSplit _splitForMember(
    GroupMember member,
    ReceiptMemberSplit? previous,
    int percentage,
  ) => ReceiptMemberSplit(
    id: member.id,
    name: member.name,
    colorHex: previous?.colorHex ??
        (member.isMe ? 0xFF66BB6A : 0xFF7E57C2),
    avatarUrl: member.avatarUrl,
    splitPercentage: percentage,
    settledAmount: previous?.settledAmount ?? 0,
  );

  String _initials(String name) => name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0])
      .join()
      .toUpperCase();

  Future<Receipt> getScannedReceipt({required String groupId}) async {
    await _ensureLoaded(groupId);
    return _scannedReceipts[groupId] ??=
        _freshScannedReceipt(await _getChatMembers(groupId));
  }

  /// Reads a receipt photo. Real trips use Gemini; old sample trips get the
  /// built-in sample receipt.
  Future<Receipt> scanReceiptPhoto({
    required String groupId,
    required String imageBase64,
    required String mimeType,
  }) async {
    await _ensureLoaded(groupId);
    if (!_isSavedGroup(groupId)) return getScannedReceipt(groupId: groupId);
    final r = await _api.post('/api/expenses/${_tripIdOf(groupId)}/scan', {
      'imageBase64': imageBase64,
      'mimeType': mimeType,
    });
    final members = await _getChatMembers(groupId);
    return _syncReceiptMembers(
      Receipt.fromJson(Map<String, dynamic>.from(r as Map)),
      members,
      initializeAssignments: false,
    );
  }

  Future<List<Receipt>> getRecentReceipts({required String groupId}) async {
    await _ensureLoaded(groupId);
    return List.unmodifiable(_recentReceipts[groupId]!);
  }

  Future<ExpenseFinancialSummary> getFinancialSummary({
    required String groupId,
  }) async {
    final receipts = await getRecentReceipts(groupId: groupId);
    final balances = <String, double>{};
    final names = <String, String>{};
    final colors = <String, int>{};
    final pairAmounts = <(String, String), double>{};
    final categoryTotals = <String, double>{};
    var confirmedPaidAmount = 0.0;
    var waitingToResolveAmount = 0.0;

    for (final receipt in receipts) {
      categoryTotals.update(
        receipt.type,
        (amount) => amount + receipt.totalAmount,
        ifAbsent: () => receipt.totalAmount,
      );
      waitingToResolveAmount += receipt.outstandingSplitAmount;
      final payerId = receipt.paidByMemberId;
      balances[payerId] = (balances[payerId] ?? 0) + receipt.totalAmount;
      names[payerId] = receipt.paidByMemberName;
      colors[payerId] = 0xFF66BB6A;

      for (final member in receipt.memberSplits) {
        final share = receipt.shareFor(member);
        final settled = member.settledAmount.clamp(0, share);
        if (member.id == payerId) {
          confirmedPaidAmount += share;
        } else {
          confirmedPaidAmount += settled;
        }
        balances[member.id] = (balances[member.id] ?? 0) - share + settled;
        names[member.id] = member.name;
        colors[member.id] = member.colorHex;
        balances[payerId] = (balances[payerId] ?? 0) - settled;

        if (member.id != payerId) {
          final key = (member.id, payerId);
          pairAmounts[key] =
              (pairAmounts[key] ?? 0) + (share - settled).clamp(0, share);
        }
      }
    }

    final memberBalances = balances.entries
        .map(
          (entry) => ExpenseMemberBalance(
            memberId: entry.key,
            name: names[entry.key] ?? entry.key,
            colorHex: colors[entry.key] ?? 0xFF9E9E9E,
            netBalance: entry.value,
          ),
        )
        .toList();
    final owedPairs = pairAmounts.entries
        .where((entry) => entry.value > 0.005)
        .map(
          (entry) => ExpenseOwedPair(
            debtorId: entry.key.$1,
            debtorName: names[entry.key.$1] ?? entry.key.$1,
            creditorId: entry.key.$2,
            creditorName: names[entry.key.$2] ?? entry.key.$2,
            amount: entry.value,
          ),
        )
        .toList();

    return ExpenseFinancialSummary(
      receipts: receipts,
      balances: memberBalances,
      owedPairs: owedPairs,
      currentUserId: (await _getChatMembers(groupId))
              .where((member) => member.isMe)
              .firstOrNull
              ?.id ??
          '',
      categoryTotals: Map.unmodifiable(categoryTotals),
      confirmedPaidAmount: confirmedPaidAmount,
      waitingToResolveAmount: waitingToResolveAmount,
    );
  }

  double relationshipBalance(
    ExpenseFinancialSummary summary,
    String otherMemberId,
  ) {
    var userOwes = 0.0;
    var personOwes = 0.0;
    for (final pair in summary.owedPairs) {
      if (pair.debtorId == summary.currentUserId &&
          pair.creditorId == otherMemberId) {
        userOwes += pair.amount;
      } else if (pair.debtorId == otherMemberId &&
          pair.creditorId == summary.currentUserId) {
        personOwes += pair.amount;
      }
    }
    return userOwes - personOwes;
  }

  Future<bool> confirmReceiptSplit(
    Receipt receipt, {
    required String groupId,
  }) async {
    await _ensureLoaded(groupId);
    if (_isSavedGroup(groupId)) {
      // the backend gives the saved receipt its real id
      final saved = await _api.post(
        '/api/expenses/${_tripIdOf(groupId)}/receipts',
        receipt.toJson(),
      );
      final savedMap = Map<String, dynamic>.from(saved as Map);
      final alert = savedMap['budgetAlert'];
      pendingBudgetAlert = alert is Map ? '${alert['message']}' : null;
      _recentReceipts[groupId]!.insert(0, Receipt.fromJson(savedMap));
      _scannedReceipts.remove(groupId); // the next scan starts fresh
      revision.value++;
      return true;
    }
    if (!_recentReceipts[groupId]!.any((entry) => entry.id == receipt.id)) {
      _recentReceipts[groupId]!.insert(0, receipt);
    }
    receipt.splitResolved = false;
    revision.value++;
    return true;
  }

  /// Saves who has paid back (real trips only). If saving fails the list is
  /// loaded again from the backend so the screen shows what is really saved.
  Future<void> _persist(String groupId, Iterable<Receipt> receipts) async {
    if (!_isSavedGroup(groupId)) return;
    try {
      for (final receipt in receipts) {
        await _api.patch(
          '/api/expenses/${_tripIdOf(groupId)}/receipts/${receipt.id}',
          {
            'memberSplits': [
              for (final split in receipt.memberSplits)
                {'id': split.id, 'settledAmount': split.settledAmount},
            ],
            'splitResolved': receipt.splitResolved,
          },
        );
      }
    } catch (e) {
      debugPrint('[expenses] could not save: $e');
      try {
        _recentReceipts[groupId] = await _fetchSavedReceipts(groupId);
      } catch (_) {}
    }
  }

  Future<void> settleMember(
    String receiptId,
    String memberId, {
    required String groupId,
  }) async {
    await _ensureLoaded(groupId);
    final receipt = _recentReceipts[groupId]!.firstWhere((entry) => entry.id == receiptId);
    final split = receipt.memberSplits.firstWhere((entry) => entry.id == memberId);
    split.settledAmount = receipt.shareFor(split);
    receipt.splitResolved = receipt.isSplitResolved;
    await _persist(groupId, [receipt]);
    revision.value++;
  }

  Future<void> resolveReceipt(String receiptId, {required String groupId}) async {
    await _ensureLoaded(groupId);
    final receipt = _recentReceipts[groupId]!.firstWhere((entry) => entry.id == receiptId);
    for (final split in receipt.memberSplits) {
      if (split.id != receipt.paidByMemberId) {
        split.settledAmount = receipt.shareFor(split);
      }
    }
    receipt.splitResolved = true;
    await _persist(groupId, [receipt]);
    revision.value++;
  }

  Future<void> settleBetween(
    String debtorId,
    String creditorId, {
    required String groupId,
  }) async {
    await _ensureLoaded(groupId);
    final changed = <Receipt>[];
    for (final receipt in _recentReceipts[groupId]!) {
      if (receipt.paidByMemberId != creditorId) continue;
      for (final split in receipt.memberSplits) {
        if (split.id == debtorId) split.settledAmount = receipt.shareFor(split);
      }
      receipt.splitResolved = receipt.isSplitResolved;
      changed.add(receipt);
    }
    await _persist(groupId, changed);
    revision.value++;
  }

  Future<void> settleRelationship(
    String firstMemberId,
    String secondMemberId, {
    required String groupId,
  }) async {
    await _ensureLoaded(groupId);
    final changed = <Receipt>[];
    for (final receipt in _recentReceipts[groupId]!) {
      if (receipt.paidByMemberId != firstMemberId &&
          receipt.paidByMemberId != secondMemberId) {
        continue;
      }
      for (final split in receipt.memberSplits) {
        if ((split.id == firstMemberId || split.id == secondMemberId) &&
            split.id != receipt.paidByMemberId) {
          split.settledAmount = receipt.shareFor(split);
        }
      }
      receipt.splitResolved = receipt.isSplitResolved;
      changed.add(receipt);
    }
    await _persist(groupId, changed);
    revision.value++;
  }
}
