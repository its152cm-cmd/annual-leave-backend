class ReceiptItem {
  final String id;
  String title;
  double price;
  int quantity;
  List<String> assignedMemberIds;

  ReceiptItem({
    required this.id,
    required this.title,
    required this.price,
    this.quantity = 1,
    required this.assignedMemberIds,
  });

  factory ReceiptItem.fromJson(Map<String, dynamic> json) {
    return ReceiptItem(
      id: json['id'] as String,
      title: json['title'] as String,
      price: (json['price'] as num).toDouble(),
      quantity: json['quantity'] as int? ?? 1,
      assignedMemberIds: (json['assignedMemberIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'price': price,
      'quantity': quantity,
      'assignedMemberIds': assignedMemberIds,
    };
  }
}

class Receipt {
  final String id;
  final String merchantName;
  String type;
  final String timestamp;
  final int peopleCount;
  final List<ReceiptItem> items;
  final List<ReceiptMemberSplit> memberSplits; // Dynamic list from backend/service
  String paidByMemberId;
  String paidByMemberName;
  String paidByMemberAvatar;
  String? paidByMemberAvatarUrl;
  bool splitResolved;

  Receipt({
    required this.id,
    required this.merchantName,
    String type = 'Other Expenses',
    required this.timestamp,
    required this.peopleCount,
    required this.items,
    required this.memberSplits,
    String? paidByMemberId,
    required this.paidByMemberName,
    required this.paidByMemberAvatar,
    this.paidByMemberAvatarUrl,
    bool? splitResolved,
    }) : type = _canonicalType(type),
      paidByMemberId = paidByMemberId ?? paidByMemberAvatar,
       splitResolved = splitResolved ??
           timestamp.toLowerCase().contains('settled');

  double get totalAmount =>
      items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));

  factory Receipt.fromJson(Map<String, dynamic> json) {
    return Receipt(
      id: json['id'] as String,
      merchantName: json['merchantName'] as String,
      type: _parseType(
        json['type'] as String?,
        json['merchantName'] as String? ?? '',
        json['items'] as List<dynamic>? ?? const [],
      ),
      timestamp: json['timestamp'] as String,
      peopleCount: json['peopleCount'] as int? ?? 3,
      items: (json['items'] as List<dynamic>)
          .map((e) => ReceiptItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      memberSplits: (json['memberSplits'] as List<dynamic>?)
              ?.map((e) => ReceiptMemberSplit.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
          paidByMemberId: json['paidByMemberId'] as String?,
      paidByMemberName: json['paidByMemberName'] as String? ?? 'Alex Ramses',
      paidByMemberAvatar: json['paidByMemberAvatar'] as String? ?? 'AR',
      paidByMemberAvatarUrl: json['paidByMemberAvatarUrl'] as String?,
          splitResolved: json['splitResolved'] as bool?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'merchantName': merchantName,
    'type': type,
    'timestamp': timestamp,
    'peopleCount': peopleCount,
    'items': items.map((item) => item.toJson()).toList(),
    'memberSplits': memberSplits
        .map(
          (member) => {
            ...member.toJson(),
            'splitPercentage': sharePercentages[member.id] ?? member.splitPercentage,
          },
        )
        .toList(),
    'paidByMemberId': paidByMemberId,
    'paidByMemberName': paidByMemberName,
    'paidByMemberAvatar': paidByMemberAvatar,
    'paidByMemberAvatarUrl': paidByMemberAvatarUrl,
    'splitResolved': splitResolved,
  };

  static String _parseType(
    String? type,
    String merchantName,
    List<dynamic> rawItems,
  ) {
    if (type != null &&
        const {
          'transport',
          'accommodation',
          'food',
          'activities',
          'activity',
          'other expenses',
          'other',
        }.contains(type.trim().toLowerCase())) {
      return _canonicalType(type);
    }

    final description = [
      merchantName,
      for (final rawItem in rawItems)
        if (rawItem is Map<String, dynamic>) rawItem['title']?.toString() ?? '',
    ].join(' ').toLowerCase();
    if (RegExp(r'train|rail|shinkansen|bus|taxi|flight|transport|transit')
        .hasMatch(description)) {
      return 'Transport';
    }
    if (RegExp(r'hotel|accommodation|hostel|inn|stay|resort')
        .hasMatch(description)) {
      return 'Accommodation';
    }
    if (RegExp(r'food|restaurant|ramen|cafe|sushi|dinner|lunch|breakfast|meal|nori')
        .hasMatch(description)) {
      return 'Food';
    }
    if (RegExp(r'tour|museum|activity|attraction|experience|admission')
        .hasMatch(description)) {
      return 'Activities';
    }
    return 'Other Expenses';
  }

  static String _canonicalType(String type) => switch (
    type.trim().toLowerCase()
  ) {
    'transport' => 'Transport',
    'accommodation' => 'Accommodation',
    'food' => 'Food',
    'activities' || 'activity' => 'Activities',
    'other expenses' || 'other' => 'Other Expenses',
    _ => 'Other Expenses',
  };

      double shareFor(ReceiptMemberSplit member) {
        final hasItemAssignments = items.any(
          (item) => item.assignedMemberIds.isNotEmpty,
        );
        if (!hasItemAssignments) {
          return totalAmount * member.splitPercentage / 100;
        }

        final amount = items.fold<double>(0, (sum, item) {
          if (!item.assignedMemberIds.contains(member.id)) return sum;
          return sum + item.price * item.quantity / item.assignedMemberIds.length;
        });
        return amount;
      }

      /// Each person's percentage of the bill, always matching the amount they
      /// owe (so it follows who shares which item) and always adding up to 100.
      Map<String, int> get sharePercentages {
        final hasItemAssignments = items.any(
          (item) => item.assignedMemberIds.isNotEmpty,
        );
        if (!hasItemAssignments) {
          return {for (final m in memberSplits) m.id: m.splitPercentage};
        }
        final shares = {for (final m in memberSplits) m.id: shareFor(m)};
        final total = shares.values.fold<double>(0, (a, b) => a + b);
        if (total <= 0) {
          return {for (final m in memberSplits) m.id: m.splitPercentage};
        }
        final exact = {for (final e in shares.entries) e.key: e.value / total * 100};
        final result = {for (final e in exact.entries) e.key: e.value.floor()};
        var left = 100 - result.values.fold<int>(0, (a, b) => a + b);
        final byRemainder = exact.keys.toList()
          ..sort((a, b) => (exact[b]! - result[b]!).compareTo(exact[a]! - result[a]!));
        for (final id in byRemainder) {
          if (left <= 0) break;
          result[id] = result[id]! + 1;
          left--;
        }
        return result;
      }

      double get outstandingSplitAmount => memberSplits.fold<double>(
        0,
        (sum, member) => member.id == paidByMemberId
          ? sum
          : sum + (shareFor(member) - member.settledAmount).clamp(0, double.infinity),
      );

      bool get isSplitResolved => outstandingSplitAmount <= 0.005;
}

class ReceiptMemberSplit {
  final String id;
  final String name;
  final int colorHex;
  String? avatarUrl;
  int splitPercentage;
  double settledAmount;

  ReceiptMemberSplit({
    required this.id,
    required this.name,
    required this.colorHex,
    this.avatarUrl,
    required this.splitPercentage,
    this.settledAmount = 0,
  });

  factory ReceiptMemberSplit.fromJson(Map<String, dynamic> json) {
    return ReceiptMemberSplit(
      id: json['id'] as String,
      name: json['name'] as String,
      colorHex: json['colorHex'] as int? ?? 0xFF66BB6A,
      avatarUrl: json['avatarUrl'] as String?,
      splitPercentage: json['splitPercentage'] as int? ?? 33,
      settledAmount: (json['settledAmount'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'colorHex': colorHex,
        'avatarUrl': avatarUrl,
        'splitPercentage': splitPercentage,
        'settledAmount': settledAmount,
      };
}
