import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DateRangePreset { all, last7Days, thisMonth, lastMonth, thisYear, custom }

/// Single shared date filter used by both the Dashboard (SMS breakdown +
/// totals) and the History/Transactions screen, so picking a range on one
/// automatically scopes the other - there's deliberately no separate
/// "history date filter" to fall out of sync with.
class SharedDateFilter {
  const SharedDateFilter({
    this.preset = DateRangePreset.all,
    this.startDate,
    this.endDate,
  });

  final DateRangePreset preset;
  final DateTime? startDate;
  final DateTime? endDate;

  bool get isActive => preset != DateRangePreset.all;

  /// Resolves the preset into concrete bounds; custom uses
  /// [startDate]/[endDate] as-is.
  (DateTime?, DateTime?) resolveBounds() {
    final now = DateTime.now();
    switch (preset) {
      case DateRangePreset.all:
        return (null, null);
      case DateRangePreset.last7Days:
        return (now.subtract(const Duration(days: 7)), null);
      case DateRangePreset.thisMonth:
        return (DateTime(now.year, now.month, 1), null);
      case DateRangePreset.lastMonth:
        final firstOfThisMonth = DateTime(now.year, now.month, 1);
        final firstOfLastMonth = DateTime(now.year, now.month - 1, 1);
        return (firstOfLastMonth, firstOfThisMonth);
      case DateRangePreset.thisYear:
        return (DateTime(now.year, 1, 1), null);
      case DateRangePreset.custom:
        return (startDate, endDate);
    }
  }
}

final sharedDateFilterProvider =
    StateProvider<SharedDateFilter>((ref) => const SharedDateFilter());

String dateRangePresetLabel(DateRangePreset preset) => switch (preset) {
      DateRangePreset.all => 'All time',
      DateRangePreset.last7Days => 'Last 7 days',
      DateRangePreset.thisMonth => 'This month',
      DateRangePreset.lastMonth => 'Last month',
      DateRangePreset.thisYear => 'Current year',
      DateRangePreset.custom => 'Custom',
    };
