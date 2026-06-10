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
    final bool isManagement = (role == 'admin' || role == 'manager');

    // Filter rules: Operators only interact with active open components
    List<JobBatch> visibleFormBatches = state.batches.where((b) => b.status == 'OPEN').toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Inter-Department Transfer Console"),
        backgroundColor: const Color(0xFF008080),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 3) ADMINISTRATIVE GLOBAL QUANTITY SPLIT-STATUS REPORT MATRIX
            if (isManagement) ...[
              const Text(
                "📊 Management System Matrix Split View (Current Status)", 
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

            // CORE MATERIAL ENTRY TRANSFER FORM (PRESERVED FUNCTIONALITY)
            const Text(
              "Route Batch Tracking Location Tokens", 
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF004d4d))
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _batchNo,
              hint: const Text("Select active line lot segment..."),
              decoration: const InputDecoration(border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
              items: visibleFormBatches.map((b) {
                return DropdownMenuItem(
                  value: b.batchNo, 
                  child: Text("Batch #${b.batchNo} (${b.jobName}) — Avail: ${b.initialQty}")
                );
              }).toList(),
              onChanged: (v) => setState(() => _batchNo = v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _fromStage,
                    decoration: const InputDecoration(labelText: "From Node", border: OutlineInputBorder()),
                    items: ["SMT", "Through hole", "None"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setState(() => _fromStage = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _toStage,
                    decoration: const InputDecoration(labelText: "To Destination Node", border: OutlineInputBorder()),
                    items: ["SMT", "Through hole", "None"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setState(() => _toStage = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _qtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Transfer Quantity Volume", border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _remarksController,
              decoration: const InputDecoration(labelText: "Process Documentation Remarks", border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
            ),
            const SizedBox(height: 16),
            _isSubmitting
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF008080)))
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF008080),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      int q = int.tryParse(_qtyController.text) ?? 0;
                      if (_batchNo == null || q <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Validation Failed: Check allocated quantities or selections."), backgroundColor: Colors.orange)
                        );
                        return;
                      }

                      setState(() => _isSubmitting = true);
                      final errorMsg = await state.executeLedgerTransfer(
                        _batchNo!, _fromStage, _toStage, q, _remarksController.text.trim()
                      );
                      setState(() => _isSubmitting = false);

                      if (errorMsg == null) {
                        _qtyController.clear();
                        _remarksController.clear();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Traceability transactional token emitted successfully across chains."), backgroundColor: Colors.green)
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Pipeline Failure: $errorMsg"), backgroundColor: Colors.red)
                        );
                      }
                    },
                    child: const Text("EMIT SECURE LEDGER ROUTE ENTRY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  
            const Divider(height: 40, thickness: 1.5),
            
            // PRESERVED WORKING HISTORICAL LEDGER BLOCKS LISTVIEW
            const Text("📋 Operational Tracking Ledger Historical Blocks", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF004d4d))),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.materialLedger.length,
              itemBuilder: (context, idx) {
                final ent = state.materialLedger[idx];
                return Card(
                  color: Colors.white,
                  child: ListTile(
                    leading: const Icon(Icons.history_toggle_off, color: Color(0xFF008080)),
                    title: Text("Batch: ${ent.batchNo} -> ${ent.qtyTransferred} Units"),
                    subtitle: Text("Node Path: ${ent.fromStage} ➔ ${ent.toStage}\nSign-Off Operator: ${ent.operator}\nTimestamp: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(ent.timestamp)}"),
                    trailing: const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
