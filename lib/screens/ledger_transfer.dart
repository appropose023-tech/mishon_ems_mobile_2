import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';
import '../models.dart';

class InterDepartmentLedgerGatewayView extends StatefulWidget {
  const InterDepartmentLedgerGatewayView({Key? key}) : super(key: key);

  @override
  State<InterDepartmentLedgerGatewayView> createState() => _InterDepartmentLedgerGatewayViewState();
}

class _InterDepartmentLedgerGatewayViewState extends State<InterDepartmentLedgerGatewayView> {
  String? _batchNo;
  String _fromStage = "SMT";
  String _toStage = "Through hole";
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _qtyController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<EMSStateEngine>(context);
    
    final String role = (state.currentUser?.role ?? 'operator').trim().toLowerCase();
    final String userTeam = state.currentUser?.team ?? 'None';
    final String userSegment = state.currentUser?.segment ?? 'None';
    final bool isManagement = (role == 'admin' || role == 'manager');

    // Filter active open batches so floor operators only see their assigned target segments/teams
    List<JobBatch> visibleFormBatches = state.batches.where((b) => b.status == 'OPEN').toList();
    if (!isManagement) {
      visibleFormBatches = visibleFormBatches.where((b) => 
        state.targetingMatrix.any((target) => 
          target.batchNo == b.batchNo && 
          target.segment == userSegment && 
          target.team == userTeam
        )
      ).toList();
    }

    // Dynamic safety fallback if a previously selected batch falls out of scope following a sync loop
    if (_batchNo != null && !visibleFormBatches.any((b) => b.batchNo == _batchNo)) {
      _batchNo = null;
    }

    // Visibility Scoping Layer for Logs filtering
    final filteredLedger = state.materialLedger.where((ent) {
      if (isManagement) return true;
      return ent.fromStage == userSegment || ent.toStage == userSegment;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Light background replaces harsh full dark modes
      appBar: AppBar(
        title: const Text("Inter-Department Ledgers"),
        backgroundColor: const Color(0xFF008080),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Assignment Context Tag Info Widget
              Card(
                elevation: 0,
                color: const Color(0xFFE2E8F0),
                margin: const EdgeInsets.only(bottom: 16), // FIXED: Changed from invalid .bottom constructor
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      const Icon(Icons.account_tree, color: Color(0xFF004d4d)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isManagement ? "Scope Context: Comprehensive Factory Matrix" : "Scope Context Account: $userSegment Segment Routing Only",
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004d4d), fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Wrap entry utilities inside a scrollable layer, reserving a fixed area below for ledger data blocks
              Expanded(
                flex: 4,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ADMINISTRATIVE GLOBAL QUANTITY SPLIT-STATUS REPORT MATRIX
                      if (isManagement) ...[
                        const Text(
                          "📋 Management System Matrix Split View (Current Status)", 
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF004d4d))
                        ),
                        const SizedBox(height: 8),
                        Card(
                          color: Colors.blueGrey.shade900,
                          elevation: 3,
                          child: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: state.batches.map((b) {
                                // Calculate dynamic tracking metrics per staging area from raw ledger blocks
                                int inSMT = b.status == 'CLOSED' ? 0 : b.initialQty; 
                                int inTH = 0;

                                // Scan total transfers to adjust balances per stage
                                for (var log in state.materialLedger) {
                                  if (log.batchNo == b.batchNo) {
                                    if (log.fromStage == 'SMT') inSMT -= log.qtyTransferred;
                                    if (log.toStage == 'SMT') inSMT += log.qtyTransferred;
                                    if (log.fromStage == 'Through hole') inTH -= log.qtyTransferred;
                                    if (log.toStage == 'Through hole') inTH += log.qtyTransferred;
                                  }
                                }

                                bool isClosed = b.status == 'CLOSED';

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Lot #${b.batchNo} (${b.jobName.padRight(12).substring(0,12)})",
                                        style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 12),
                                      ),
                                      Text(
                                        isClosed 
                                            ? "🟢 LOCKED [BILLING/DISPATCH]" 
                                            : "SMT Bal: $inSMT | TH Bal: $inTH",
                                        style: TextStyle(
                                          color: isClosed ? Colors.grey.shade400 : Colors.greenAccent, 
                                          fontFamily: 'monospace', 
                                          fontSize: 12,
                                          fontWeight: isClosed ? FontWeight.normal : FontWeight.bold
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const Divider(height: 32, thickness: 1.5),
                      ],

                      const Text("Log Inter-Department Transfer Route", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF004d4d))),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _batchNo,
                        hint: const Text("Select active job lot..."),
                        isExpanded: true,
                        decoration: const InputDecoration(border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                        items: visibleFormBatches.map((b) => DropdownMenuItem(
                          value: b.batchNo, 
                          child: Text(
                            "Batch #${b.batchNo} - ${b.jobName} [Avail: ${b.initialQty}]",
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          )
                        )).toList(),
                        onChanged: (v) => setState(() => _batchNo = v),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _fromStage,
                              decoration: const InputDecoration(labelText: "Source Stage Node", border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                              items: ["SMT", "Through hole", "Quality", "Packing"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                              onChanged: (v) => setState(() => _fromStage = v!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _toStage,
                              decoration: const InputDecoration(labelText: "Target Destination Node", border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                              items: ["SMT", "Through hole", "Quality", "Packing"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                              onChanged: (v) => setState(() => _toStage = v!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _qtyController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "Quantity Units to Route Out", border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _remarksController,
                        decoration: const InputDecoration(labelText: "Routing Remarks / Sign-off Passnotes", border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      _isSubmitting
                          ? const Center(child: CircularProgressIndicator(color: Color(0xFF008080)))
                          : ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF008080), padding: const EdgeInsets.symmetric(vertical: 14)),
                              onPressed: () async {
                                int count = int.tryParse(_qtyController.text) ?? 0;
                                if (_batchNo != null && count > 0) {
                                  setState(() => _isSubmitting = true);
                                  final err = await state.executeLedgerTransfer(
                                    _batchNo!,
                                    _fromStage,
                                    _toStage,
                                    count,
                                    _remarksController.text.trim(),
                                  );
                                  setState(() => _isSubmitting = false);
                                  if (err == null) {
                                    _qtyController.clear();
                                    _remarksController.clear();
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Handshake route registered safely."), backgroundColor: Colors.green));
                                    }
                                  } else {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Pipeline Failure: $err"), backgroundColor: Colors.red));
                                    }
                                  }
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ensure batch selection and transfer outputs are non-zero."), backgroundColor: Colors.orange));
                                }
                              },
                              child: const Text("EMIT SECURE LEDGER ROUTE ENTRY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                      const Divider(height: 32, thickness: 1.5),
                      const Text("📋 Operational Tracking Ledger Historical Blocks", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF004d4d))),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              // Bounded constraint box tracking visual list updates safely without screen layout structural crashes
              Expanded(
                flex: 3,
                child: filteredLedger.isEmpty
                    ? const Center(child: Text("No tracking items allocated inside your node history context.", style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: filteredLedger.length,
                        itemBuilder: (context, idx) {
                          final ent = filteredLedger[idx];
                          String formattedTime = "";
                          try {
                            formattedTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(ent.timestamp);
                          } catch (e) {
                            formattedTime = ent.timestamp.toString();
                          }

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            color: Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("Batch Code Reference: #${ent.batchNo}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                      Text("${ent.qtyTransferred} Units", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF008080))),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text("Sequence Vector: ${ent.fromStage} ➔ ${ent.toStage}", style: const TextStyle(fontSize: 13, color: Colors.black87)),
                                  if (ent.comments.isNotEmpty) Text("Comments: ${ent.comments}", style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.black54)),
                                  const Divider(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("Auth Signee: ${ent.operator}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                      Text(formattedTime, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
