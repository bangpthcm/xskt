// lib/data/models/number_detail.dart

class NumberDetail {
  final String number;
  final Map<String, MienDetail> mienDetails;

  NumberDetail({
    required this.number,
    required this.mienDetails,
  });
}

class MienDetail {
  final String mien;
  final int daysGan;
  final DateTime lastSeenDate;
  final String lastSeenDateStr;

  MienDetail({
    required this.mien,
    required this.daysGan,
    required this.lastSeenDate,
    required this.lastSeenDateStr,
  });
}