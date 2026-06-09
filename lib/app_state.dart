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
        batches = fetchedBatches.map((b) {
          final rawQty = b['initial_qty'] ?? b['pcb_qty'] ?? 0;
          return JobBatch(
            batchNo: b['batch_no']?.toString() ?? '',
            jobName: b['job_name']?.toString() ?? b['job_code']?.toString() ?? '',
            clientName: b['client_name']?.toString() ?? '',
            projectName: b['project_name']?.toString() ?? '',
            initialQty: rawQty is num ? rawQty.toInt() : (int.tryParse(rawQty.toString()) ?? 0),
            status: b['status']?.toString() ?? 'OPEN',
          );
        }).toList();

        // 2. Sync Ledger entries
        final List fetchedLedger = data['ledger'] ?? data['material_ledger'] ?? [];
        materialLedger = fetchedLedger.map((l) {
          final rawQty = l['qty_transferred'] ?? l['qty'] ?? 0;
          return LedgerEntry(
            batchNo: l['batch_no']?.toString() ?? '',
            fromStage: l['from_stage']?.toString() ?? '',
            toStage: l['to_stage']?.toString() ?? '',
            qtyTransferred: rawQty is num ? rawQty.toInt() : (int.tryParse(rawQty.toString()) ?? 0),
            timestamp: DateTime.tryParse(l['entry_timestamp']?.toString() ?? l['timestamp']?.toString() ?? '') ?? DateTime.now(),
            operator: l['operator_username']?.toString() ?? l['operator']?.toString() ?? '',
            comments: l['comments']?.toString() ?? '',
          );
        }).toList();

        // 3. Sync Targeting bounds
        final List fetchedTargets = data['targets'] ?? data['floor_targets'] ?? [];
        targetingMatrix = fetchedTargets.map((t) {
          final rawQty = t['target_qty'] ?? t['qty'] ?? 0;
          return FloorTarget(
            batchNo: t['batch_no']?.toString() ?? '',
            segment: t['segment']?.toString() ?? '',
            team: t['team']?.toString() ?? '',
            targetQty: rawQty is num ? rawQty.toInt() : (int.tryParse(rawQty.toString()) ?? 0),
          );
        }).toList();

        // 4. Rebuild performance counters safely
        final List hourlyLogs = data['hourly_logs'] ?? data['production_logs'] ?? [];
        processingCounters.clear();
        for (var log in hourlyLogs) {
          final bNo = log['batch_no']?.toString() ?? '';
          final side = log['side']?.toString() ?? 'TOP';
          final rawQty = log['qty_done'] ?? log['qty'] ?? 0;
          final int qty = rawQty is num ? rawQty.toInt() : (int.tryParse(rawQty.toString()) ?? 0);
          
          if (bNo.isNotEmpty) {
            if (!processingCounters.containsKey(bNo)) {
              processingCounters[bNo] = {"TOP": 0, "BOTTOM": 0};
            }
            processingCounters[bNo]![side] = (processingCounters[bNo]![side] ?? 0) + qty;
          }
        }
      }
    } catch (e) {
      debugPrint("🚨 PIPELINE CRASH: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
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
          username: u['username']?.toString() ?? '',
          role: (u['role'] ?? 'operator').toString().trim().toLowerCase(), 
          team: u['team']?.toString() ?? 'None',
          segment: u['segment']?.toString() ?? 'None',
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
    if (currentUser == null) return "No active operational user session found.";

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
        if (!processingCounters.containsKey(batchNo)) {
          processingCounters[batchNo] = {"TOP": 0, "BOTTOM": 0};
        }
        processingCounters[batchNo]![side] = (processingCounters[batchNo]![side] ?? 0) + qty;
        
        await fetchAndSyncFromBackend();
        return null;
      } else {
        return data['message'] ?? "Validation failure on shopfloor log entry.";
      }
    } catch (e) {
      return "Network connection issue reporting status data.";
    }
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
    required String remarks,
