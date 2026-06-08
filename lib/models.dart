class UserProfile {
  final String username;
  final String role; // admin, manager, supervisor, technician
  final String team; // Production, Quality, None
  final String segment; // SMT, Through hole, None

  UserProfile({
    required this.username,
    required this.role,
    required this.team,
    required this.segment,
  });
}

class JobBatch {
  final String batchNo;
  final String jobName;
  final String clientName;
  final String projectName;
  final int initialQty;
  String status; // OPEN, CLOSED, DISPATCHED

  JobBatch({
    required this.batchNo,
    required this.jobName,
    required this.clientName,
    required this.projectName,
    required this.initialQty,
    this.status = 'OPEN',
  });

  // Maps incoming Flask tracking payloads directly to the object layer safely
  factory JobBatch.fromJson(Map<String, dynamic> json) {
    final rawQty = json['initial_qty'] ?? json['pcb_qty'] ?? 0;
    return JobBatch(
      batchNo: json['batch_no'] ?? '',
      jobName: json['job_name'] ?? '',
      clientName: json['client_name'] ?? '',
      projectName: json['project_name'] ?? '',
      initialQty: rawQty is num ? rawQty.toInt() : 0,
      status: json['status'] ?? 'OPEN',
    );
  }
}

class LedgerEntry {
  final String batchNo;
  final String fromStage;
  final String toStage;
  final int qtyTransferred;
  final DateTime timestamp;
  final String operator;
  final String comments;

  LedgerEntry({
    required this.batchNo,
    required this.fromStage,
    required this.toStage,
    required this.qtyTransferred,
    required this.timestamp,
    required this.operator,
    required this.comments,
  });

  factory LedgerEntry.fromJson(Map<String, dynamic> json) {
    final rawQty = json['qty_transferred'] ?? 0;
    return LedgerEntry(
      batchNo: json['batch_no'] ?? '',
      fromStage: json['from_stage'] ?? '',
      toStage: json['to_stage'] ?? '',
      qtyTransferred: rawQty is num ? rawQty.toInt() : 0,
      timestamp: DateTime.tryParse(json['entry_timestamp'] ?? '') ?? DateTime.now(),
      operator: json['operator_username'] ?? '',
      comments: json['comments'] ?? '',
    );
  }
}

class FloorTarget {
  final String batchNo;
  final String segment;
  final String team;
  final int targetQty;

  FloorTarget({
    required this.batchNo,
    required this.segment,
    required this.team,
    required this.targetQty,
  });

  factory FloorTarget.fromJson(Map<String, dynamic> json) {
    final rawQty = json['target_qty'] ?? 0;
    return FloorTarget(
      batchNo: json['batch_no'] ?? '',
      segment: json['segment'] ?? '',
      team: json['team'] ?? '',
      targetQty: rawQty is num ? rawQty.toInt() : 0,
    );
  }
}
