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
  List<dynamic> rawHourlyLogs = []; // Preserved to display logs in Analytics UI
  
  bool isLoading = false;

  EMSStateEngine();

  /// Safely extracts the cumulative processed quantity for a specific batch and layer side
  int getLayerRunningTotal(String batchNo, String layer) {
    if (processingCounters.containsKey(batchNo)) {
      final layerMap = processingCounters[batchNo];
      if (layerMap != null && layerMap.containsKey(layer)) {
        return layerMap[layer] ?? 0;
      }
    }
    return 0;
  }

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
        
        // 1. Sync Ledger History
        final List fetchedLedger = data['ledger'] ?? [];
        materialLedger = fetchedLedger.map((l) => LedgerEntry.fromJson(l)).toList();

        // 2. Sync Floor Targets Matrix
        final List fetchedTargets = data['targets'] ?? data['floor_targets'] ?? [];
        targetingMatrix = fetchedTargets.map((t) => FloorTarget.fromJson(t)).toList();

        // 3. Clear and compile Hourly processing counters
        processingCounters.clear();
        rawHourlyLogs = data['hourly_logs'] ?? [];
        for (var log in rawHourlyLogs) {
          String bNo = log['batch_no']?.toString() ?? '';
          String side = log['side']?.toString() ?? 'TOP';
          int done = int.tryParse(log['qty_done']?.toString() ?? '0') ?? 0;
          
          processingCounters.putIfAbsent(bNo, () => {'TOP': 0, 'BOTTOM': 0});
          processingCounters[bNo]![side] = (processingCounters[bNo]![side] ?? 0) + done;
        }

        // 4. SECURE ROLE-BASED BATCH AND DYNAMIC INVENTORY CALCULATIONS
        final List fetchedBatches = data['batches'] ?? data['job_batches'] ?? [];
        List<JobBatch> processedList = [];

        final String role = (currentUser?.role ?? 'operator').trim().toLowerCase();
        final String currentSegment = currentUser?.segment ?? 'None';

        for (var b in fetchedBatches) {
          JobBatch batchObj = JobBatch.fromJson(b);
          
          // RULE: Closed batches are hidden completely from Operators & Supervisors everywhere
          if (batchObj.status == 'CLOSED' && (role != 'admin' && role != 'manager')) {
            continue; 
          }

          // Management Rule: Admins and Managers see all batches with their uninhibited full quantities
          if (role == 'admin' || role == 'manager') {
            processedList.add(batchObj);
            continue;
          }

          // Operator/Supervisor Logic: Calculate current localized slice based on ledger movements
          int dynamicAllocatedQty = 0;

          // SMT serves as the initial landing stage, starting with the total kit capacity
          if (currentSegment == 'SMT') {
            dynamicAllocatedQty = batchObj.initialQty;
          }

          // Scan the ledger chain to deduce current dynamic balance inside this account's segment
          for (var entry in materialLedger) {
            if (entry.batchNo == batchObj.batchNo) {
              if (entry.toStage == currentSegment) {
                dynamicAllocatedQty += entry.qtyTransferred;
              }
              if (entry.fromStage == currentSegment) {
                dynamicAllocatedQty -= entry.qtyTransferred;
              }
            }
          }

          // Structural Visibility Cap: Only expose the batch to the user if their current location slice > 0
          if (dynamicAllocatedQty > 0) {
            processedList.add(JobBatch(
              batchNo: batchObj.batchNo,
              jobName: batchObj.jobName,
              clientName: batchObj.clientName,
              projectName: batchObj.projectName,
              initialQty: dynamicAllocatedQty, // Overwritten to reflect their restricted balance slice
              status: batchObj.status
            ));
          }
        }

        batches = processedList;
      }
    } catch (e) {
      debugPrint("Sync Parsing Core Error Exception: $e");
    } finally {
      isLoading = false;
      notifyListeners();
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
        if (data['success'] == true && data['user'] != null) {
          final u = data['user'];
          currentUser = UserProfile(
            username: u['username'] ?? '',
            role: u['role'] ?? 'operator',
            team: u['team'] ?? 'None',
            segment: u['segment'] ?? 'None',
          );
          await fetchAndSyncFromBackend();
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> toggleShiftPunch(bool punchIn) async {
    if (punchIn) {
      activePunchInTime = DateTime.now();
    } else {
      activePunchInTime = null;
    }
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 400));
  }

  Future<void> logHourlyStatus(String batchNo, String side, int qty, String comments) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/api/log_hourly'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "batch_no": batchNo,
          "side": side,
          "qty_done": qty,
          "operator": currentUser?.username ?? 'unknown',
          "comments": comments
        }),
      );
      await fetchAndSyncFromBackend();
    } catch (e) {
      debugPrint("Hourly status upload exception: $e");
    }
  }

  Future<void> transmitBatchCloseEvent(String batchNo) async {
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

  void clearSession() {
    currentUser = null;
    activePunchInTime = null;
    batches.clear();
    materialLedger.clear();
    targetingMatrix.clear();
    processingCounters.clear();
    rawHourlyLogs.clear();
    notifyListeners();
  }
}
