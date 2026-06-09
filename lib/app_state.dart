import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart'; 

class EMSStateEngine extends ChangeNotifier {
  final String baseUrl = "http://104.154.76.47:5050"; 
  UserProfile? currentUser;
  DateTime? activePunchInTime;
  
  List<JobBatch> batches = [];
  List<LedgerEntry> materialLedger = [];
  List<FloorTarget> targetingMatrix = [];
  Map<String, Map<String, int>> processingCounters = {}; // batchNo -> (TOP/BOTTOM) -> quantityDone
  
  bool isLoading = false;

  EMSStateEngine();

  /// Synchronizes all operational tables from the Flask database pipeline safely
  Future<void> fetchAndSyncFromBackend() async {
    isLoading = true;
    notifyListeners();
    
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/sync'));
      debugPrint("📡 Sync Response Status: ${response.statusCode}");
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        debugPrint("📡 Backend Payload Keys: ${data.keys.toList()}");
        
        // 1. Sync Batches
        final List fetchedBatches = data['batches'] ?? data['job_batches'] ?? [];
        batches = fetchedBatches.map((b) => JobBatch.fromJson(b)).toList();
        
        // 2. Sync Floor Targets Matrix
        final List fetchedTargets = data['targets'] ?? data['floor_targets'] ?? [];
        targetingMatrix = fetchedTargets.map((t) => FloorTarget.fromJson(t)).toList();
        
        // 3. Sync Inter-Department Material Ledger
        final List fetchedLedger = data['ledger'] ?? data['material_ledger'] ?? [];
        materialLedger = fetchedLedger.map((l) => LedgerEntry.fromJson(l)).toList();

        // 4. Compute Dynamic Progress Counters for Operators
        final List fetchedHourlyLogs = data['hourly_logs'] ?? data['hourly_status_logs'] ?? [];
        Map<String, Map<String, int>> newCounters = {};
        for (var log in fetchedHourlyLogs) {
          String bNo = log['batch_no'] ?? '';
          String layer = log['placement_layer'] ?? 'TOP';
          int qty = (log['qty_processed'] ?? 0) is num ? (log['qty_processed'] as num).toInt() : 0;
          
          if (!newCounters.containsKey(bNo)) {
            newCounters[bNo] = {"TOP": 0, "BOTTOM": 0};
          }
          if (newCounters[bNo]!.containsKey(layer)) {
            newCounters[bNo]![layer] = newCounters[bNo]![layer]! + qty;
          }
        }
        processingCounters = newCounters;
      }
    } catch (e) {
      debugPrint("💥 Critical State Sync Failure: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Calculates real-time running output totals for specific component configurations
  int getLayerRunningTotal(String batchNo, String layer) {
    if (processingCounters.containsKey(batchNo) && processingCounters[batchNo]!.containsKey(layer)) {
      return processingCounters[batchNo]![layer]!;
    }
    return 0;
  }

  /// Handles user access validation mapping against your server infrastructure
  Future<bool> authenticateUser(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/login'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"username": username, "password": password}),
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(response.body);
        if (body['success'] == true && body['user'] != null) {
          final u = body['user'];
          currentUser = UserProfile(
            username: u['username'] ?? '',
            role: u['role'] ?? 'operator',
            team: u['team'] ?? 'None',
            segment: u['segment'] ?? 'None',
          );
          
          // Pull fresh database profiles immediately upon successful authentication
          await fetchAndSyncFromBackend();
          return true;
        }
      }
    } catch (e) {
      debugPrint("Authentication crash: $e");
    }
    return false;
  }

  /// Manages real-time employee punch triggers
  Future<void> toggleShiftPunch(bool punchIn) async {
    if (currentUser == null) return;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/punch'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "username": currentUser!.username,
          "action": punchIn ? "PUNCH_IN" : "PUNCH_OUT"
        }),
      );
      if (response.statusCode == 200) {
        activePunchInTime = punchIn ? DateTime.now() : null;
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Failed to write attendance trace: $e");
    }
  }

  /// Commits operator yield quantities to backend databases securely
  Future<String?> logHourlyStatus(String batchNo, String layer, int qty, String notes) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/log_hourly'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "batch_no": batchNo,
          "placement_layer": layer,
          "qty_processed": qty,
          "operator_username": currentUser?.username ?? 'system',
          "comments": notes
        }),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        await fetchAndSyncFromBackend();
        return null;
      } else {
        return data['message'] ?? "Unknown pipeline error.";
      }
    } catch (e) {
      return "Network communication failure exception.";
    }
  }

  /// Administrative method to gracefully terminate an open pcb lot
  Future<void> transmitBatchCloseEvent(String batchNo) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/api/close_batch'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"batch_no": batchNo, "status": "CLOSED"}),
      );
      await fetchAndSyncFromBackend();
    } catch (e) {
      debugPrint("Failed to transmit batch close event: $e");
    }
  }

  /// Inter-Department Routing method
  Future<String?> executeLedgerTransfer(String batchNo, String fromStage, String toStage, int qty, String remarks) async {
    if (currentUser == null) return "Authorization error: Missing active operational token.";

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

  /// Secondary pipeline wrapper to resolve data pipeline mapping
  Future<String?> injectLedgerTransaction({
    required String batchNo,
    required String fromStage,
    required String toStage,
    required int qty,
    required String operator,
    required String comments,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/ledger_transfer'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "batch_no": batchNo,
          "from_stage": fromStage,
          "to_stage": toStage,
          "qty": qty,
          "operator": operator,
          "comments": comments
        }),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        await fetchAndSyncFromBackend();
        return null; 
      } else {
        return data['message'] ?? "Failed to save transaction.";
      }
    } catch (e) {
      return "Network communication failure: $e";
    }
  }
}
