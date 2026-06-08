import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart'; 

class EMSStateEngine extends ChangeNotifier {
  final String baseUrl = "http://192.168.1.100:5030"; 
  UserProfile? currentUser;
  DateTime? activePunchInTime;
  
  List<JobBatch> batches = [];
  List<LedgerEntry> materialLedger = [];
  List<FloorTarget> targetingMatrix = [];
  Map<String, Map<String, int>> processingCounters = {}; // batchNo -> (TOP/BOTTOM) -> quantityDone
  
  bool isLoading = false;

  EMSStateEngine();

  /// Synchronizes all operational tables from the Flask database pipeline
  Future<void> fetchAndSyncFromBackend() async {
    isLoading = true;
    notifyListeners();
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/sync'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // 1. Sync Batches with strict integer casting
        final List fetchedBatches = data['batches'] ?? [];
        batches = fetchedBatches.map((b) {
          final rawQty = b['initial_qty'] ?? b['pcb_qty'] ?? 0;
          return JobBatch(
            batchNo: b['batch_no'] ?? '',
            jobName: b['job_name'] ?? '',
            clientName: b['client_name'] ?? '',
            projectName: b['project_name'] ?? '',
            initialQty: rawQty is num ? rawQty.toInt() : 0,
            status: b['status'] ?? 'OPEN',
          );
        }).toList();

        // 2. Sync Ledger entries with strict integer casting
        final List fetchedLedger = data['ledger'] ?? [];
        materialLedger = fetchedLedger.map((l) {
          final rawQty = l['qty_transferred'] ?? 0;
          return LedgerEntry(
            batchNo: l['batch_no'] ?? '',
            fromStage: l['from_stage'] ?? '',
            toStage: l['to_stage'] ?? '',
            qtyTransferred: rawQty is num ? rawQty.toInt() : 0,
            timestamp: DateTime.tryParse(l['entry_timestamp'] ?? '') ?? DateTime.now(),
            operator: l['operator_username'] ?? '',
            comments: l['comments'] ?? '',
          );
        }).toList();

        // 3. Sync Targeting bounds with strict integer casting
        final List fetchedTargets = data['targets'] ?? [];
        targetingMatrix = fetchedTargets.map((t) {
          final rawQty = t['target_qty'] ?? 0;
          return FloorTarget(
            batchNo: t['batch_no'] ?? '',
            segment: t['segment'] ?? '',
            team: t['team'] ?? '',
            targetQty: rawQty is num ? rawQty.toInt() : 0;
          );
        }).toList();

        // 4. Safely rebuild performance counts with deterministic integer assignment
        if (data.containsKey('hourly_logs')) {
          processingCounters.clear();
          final List hourlyLogs = data['hourly_logs'] ?? [];
          for (var log in hourlyLogs) {
            final bNo = log['batch_no'] ?? '';
            final side = log['side'] ?? 'TOP';
            final rawQty = log['qty_done'] ?? 0;
            final int qty = rawQty is num ? rawQty.toInt() : 0;
            
            if (!processingCounters.containsKey(bNo)) {
              processingCounters[bNo] = {"TOP": 0, "BOTTOM": 0};
            }
            processingCounters[bNo]![side] = (processingCounters[bNo]![side] ?? 0) + qty;
          }
        }
      }
    } catch (e) {
      debugPrint("Synchronization error pipeline down: $e");
    }
    isLoading = false;
    notifyListeners();
  }

  int getLayerRunningTotal(String batchNo, String side) {
    return processingCounters[batchNo]?[side] ?? 0;
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
        activePunchInTime = isPunchIn ? DateTime.tryParse(data['time'] ?? '') : null;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint("Punch operation tracking failure: $e");
    }
    return false;
  }

  /// Core shopfloor entry pipeline logging method
  Future<String?> logHourlyStatus(String batchNo, String side, int qty, String comments) async {
    if (!processingCounters.containsKey(batchNo)) {
      processingCounters[batchNo] = {"TOP": 0, "BOTTOM": 0};
    }
    processingCounters[batchNo]![side] = (processingCounters[batchNo]![side] ?? 0) + qty;
    notifyListeners();

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

  void commitHourlyStatus(String batchNo, String side, int amount, String comments) {
    logHourlyStatus(batchNo, side, amount, comments);
  }

  Future<void> closeBatchProcessingBlock(String batchNo) async {
    final idx = batches.indexWhere((element) => element.batchNo == batchNo);
    if (idx != -1) {
      batches[idx].status = 'CLOSED';
      notifyListeners();
    }
    try {
      await http.post(
        Uri.parse('$baseUrl/api/close_batch'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"batch_no": batchNo, "status": "CLOSED"}),
      );
      await fetchAndSyncFromBackend();
    } catch (e) {
      debugPrint("Failed to transmit batch state close event: $e");
    }
  }

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

  Future<String?> injectLedgerTransaction({
    required String batchNo,
    required String fromStage,
    required String toStage,
    required int qty,
    required String operator,
    required String remarks,
  }) async {
    return await executeLedgerTransfer(batchNo, fromStage, toStage, qty, remarks);
  }

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
