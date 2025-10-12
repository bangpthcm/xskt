// lib/data/models/gan_pair_info.dart
import 'dart:math';

class GanPairInfo {
  final int daysGan;
  final DateTime lastSeen;
  final List<PairWithDays> pairs;

  GanPairInfo({
    required this.daysGan,
    required this.lastSeen,
    required this.pairs,
  });

  String get pairsDisplay => pairs.map((p) => p.display).join(', ');
  
  NumberPair get randomPair => pairs.isNotEmpty ? pairs[0].pair : NumberPair('00', '00');
}

class PairWithDays {
  final NumberPair pair;
  final int daysGan;
  final DateTime lastSeen;

  PairWithDays({
    required this.pair,
    required this.daysGan,
    required this.lastSeen,
  });
  
  // ✅ Thêm getter để dễ sử dụng
  String get display => pair.display;
}

class NumberPair {
  final String first;
  final String second;

  NumberPair(this.first, this.second);

  String get display => '$first-$second';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NumberPair && 
           other.first == first && 
           other.second == second;
  }

  @override
  int get hashCode => first.hashCode ^ second.hashCode;
}