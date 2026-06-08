import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart'; // Re-importing shared core application data structures

class EMSStateEngine extends ChangeNotifier {
  final String baseUrl = "http://192.168.1.100:5030"; // Your Flask backend server IP address
  UserProfile? currentUser;
  String? activePunchInTime;
  
  // Exposing state containers to satisfy screen getters
  List<JobBatch> batches = [];
  List<LedgerEntry> materialLedger = [];
  List<FloorTarget> targetingMatrix = [];
  Map<String, Map<String, int>> processingCounters = {}; // batchNo -> (TOP/BOTTOM) -> quantityDone
  
  bool isLoading = false;

  EMSStateEngine() {
    // Optional local fallbacks can be initialized here if needed
  }

  /// Synchronizes all operational tables from the Flask database pipeline
  Future<void> fetchAndSyncFromBackend() async {
    isLoading = true;
    notifyListeners();
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/sync'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // 1. Sync Batches
        final List fetchedBatches = data['batches'] ?? [];
        batches = fetchedBatches.map((b) => JobBatch(
          batchNo: b['batch_no'] ?? '',
          jobName: b['job_name'] ?? '',
          clientName: b['client_name'] ?? '',
          projectName: b['project_name'] ?? '',
          initialQty: b['initial_qty'] ?? b['pcb_qty'] ?? 0,
          status: b['status'] ?? 'OPEN',
        )).toList();

        // 2. Sync Ledger entries (Resolves ledger_transfer.dart compile error)
        final List fetchedLedger = data['ledger'] ?? [];
        materialLedger = fetchedLedger.map((l) => LedgerEntry(
          batchNo: l['batch_no'] ?? '',
          fromStage: l['from_stage'] ?? '',
          toStage: l['to_stage'] ?? '',
          qtyTransferred: l['qty_transferred'] ?? 0,
          timestamp: DateTime.tryParse(l['entry_timestamp'] ?? '') ?? DateTime.now(),
          operator: l['operator_username'] ?? '',
          comments: l['comments'] ?? '',
        )).toList();

        // 3. Sync Targeting bounds (Resolves analytics.dart compile error)
        final List fetchedTargets = data['targets'] ?? [];
        targetingMatrix = fetchedTargets.map((t) => FloorTarget(
          batchNo: t['batch_no'] ?? '',
          segment: t['segment'] ?? '',
          team: t['team'] ?? '',
          targetQty: t['target_qty'] ?? 0,
        )).toList();

        // 4. Update local tracking counters to prevent interface calculation drops
        _recalculateLocalProcessingCounters();
      }
    } catch (e) {
      debugPrint("Synchronization error pipeline down: $e");
    }
    isLoading = false;
    notifyListeners();
  }

  /// Internal utility to populate quantities for balance metrics on the shopfloor
  void _recalculateLocalProcessingCounters() {
    processingCounters.clear();
    for (var entry in materialLedger) {
      final bNo = entry.batchNo;
      if (!processingCounters.containsKey(bNo)) {
        processingCounters[bNo] = {"TOP": 0, "BOTTOM": 0};
      }
      // Increment top layer defaults as a safety fallback tracking method
      processingCounters[bNo]!["TOP"] = (processingCounters[bNo]!["TOP"] ?? 0) + entry.qtyTransferred;
    }
  }

  Future<bool> authenticateUser(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/login'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"username": username, "password": password}),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final u = data['user'];
        currentUser = UserProfile(
          username: u['username'],
          role: u['role'],
          team: u['team'] ?? 'None',
          segment: u['segment'] ?? 'None',
        );
        await fetchAndSyncFromBackend();
        return true;
      }
    } catch (e) {
      debugPrint("Authentication system network failure: $e");
    }
    return false;
  }

  Future<bool> toggleShiftPunch(bool isPunchIn) async {
    if (currentUser == null) return false;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/punch'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "username": currentUser!.username,
          "action": isPunchIn ? "in" : "out"
        }),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        activePunchInTime = isPunchIn ? data['time'] : null;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint("Punch operation tracking failure: $e");
    }
    return false;
  }

  /// Core shopfloor entry pipeline method
  Future<String?> logHourlyStatus(String batchNo, String side, int qty, String comments) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/log_hourly'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "username": currentUser!.username,
          "batch_no": batchNo,
          "side": side,
          "qty": qty,
          "comments": comments,
          "team": currentUser!.team,
          "segment": currentUser!.segment
        }),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        await fetchAndSyncFromBackend();
        return null;
      } else {
        return data['message'] ?? "Validation failure on shopfloor log entry.";
      }
    } catch (e) {
      return "Network connection issue reporting status data.";
    }
  }

  /// Backward-compatible synchronous wrapper mapping to original execution_floor.dart requirements
  void commitHourlyStatus(String batchNo, String side, int qty) {
    logHourlyStatus(batchNo, side, qty, "Automated Shopfloor Terminal entry");
  }

  /// Triggers inter-department routing operations
  Future<String?> executeLedgerTransfer(String batchNo, String fromStage, String toStage, int qty, String remarks) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/ledger_transfer'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "batch_no": batchNo,
          "from_stage": fromStage,
          "to_stage": toStage,
          "qty": qty,
          "operator": currentUser!.username,
          "comments": remarks
        }),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        await fetchAndSyncFromBackend();
        return null;
      } else {
        return data['message'] ?? "Failed to authorize data transfer handshake transaction.";
      }
    } catch (e) {
      return "Network structural communication failure.";
    }
  }

  /// Handles pending outbound dispatch state updates (Resolves analytics.dart compile error)
  Future<void> dispatchBillingClearance(String batchNo) async {
    final idx = batches.indexWhere((element) => element.batchNo == batchNo);
    if (idx != -1) {
      batches[idx].status = 'DISPATCHED';
      notifyListeners();
    }
    try {
      await http.post(
        Uri.parse('$baseUrl/api/dispatch'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"batch_no": batchNo, "status": "DISPATCHED"}),
      );
      await fetchAndSyncFromBackend();
    } catch (e) {
      debugPrint("Failed to transmit dispatch event: $e");
    }
  }

  /// Registers fresh floor production parameters inside database tables (Resolves analytics.dart compile error)
  Future<void> provisionNewTarget(String batchNo, String segment, String team, int targetQty) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/api/provision_target'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "batch_no": batchNo,
          "segment": segment,
          "team": team,
          "target_qty": targetQty
        }),
      );
      await fetchAndSyncFromBackend();
    } catch (e) {
      debugPrint("Failed to register target parameter: $e");
      // Fallback local addition to avoid system execution lag if offline
      targetingMatrix.add(FloorTarget(batchNo: batchNo, segment: segment, team: team, targetQty: targetQty));
      notifyListeners();
    }
  }

  void clearSession() {
    currentUser = null;
    activePunchInTime = null;
    batches.clear();
    materialLedger.clear();
    targetingMatrix.clear();
    processingCounters.clear();
    notifyListeners();
  }
}
