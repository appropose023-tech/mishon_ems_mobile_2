import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models.dart';

class BillingDispatchScreen extends StatefulWidget {
  const BillingDispatchScreen({super.key});

  @override
  State<BillingDispatchScreen> createState() => _BillingDispatchScreenState();
}

class _BillingDispatchScreenState extends State<BillingDispatchScreen> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<EMSStateEngine>(context);
    final openBatches = state.batches.where((b) => b.status == 'OPEN').toList();
    final closedBatches = state.batches.where((b) => b.status == 'CLOSED').toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Billing & Dispatch Terminal"),
        backgroundColor: const Color(0xFF008080),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text("📦 Open Lots Awaiting Administration Closure", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF004d4d))),
              const SizedBox(height: 8),
              openBatches.isEmpty
                  ? const Card(child: Padding(padding: EdgeInsets.all(16.0), child: Text("All manufacturing lots are securely locked or closed.", style: TextStyle(color: Colors.grey))))
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: openBatches.length,
                      itemBuilder: (context, idx) {
                        final b = openBatches[idx];
                        return Card(
                          child: ListTile(
                            title: Text("Batch #${b.batchNo} - ${b.jobName}"),
                            subtitle: Text("Client: ${b.clientName} | Total Kit Count: ${b.initialQty}"),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade800),
                              onPressed: _isProcessing ? null : () async {
                                setState(() => _isProcessing = true);
                                await state.transmitBatchCloseEvent(b.batchNo);
                                setState(() => _isProcessing = false);
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Batch #${b.batchNo} moved to CLOSED bounds safety layer.")));
                              },
                              child: const Text("CLOSE LOT", style: TextStyle(color: Colors.white, fontSize: 12)),
                            ),
                          ),
                        );
                      },
                    ),
              const SizedBox(height: 24),
              const Text("🚛 Closed Batches Cleared for Final Billing & Shipment", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF004d4d))),
              const SizedBox(height: 8),
              closedBatches.isEmpty
                  ? const Card(child: Padding(padding: EdgeInsets.all(16.0), child: Text("No batches currently isolated inside closed dispatch bounds.", style: TextStyle(color: Colors.grey))))
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: closedBatches.length,
                      itemBuilder: (context, idx) {
                        final cb = closedBatches[idx];
                        return Card(
                          color: Colors.green.shade50,
                          child: ListTile(
                            leading: const Icon(Icons.local_shipping, color: Colors.green),
                            title: Text("Batch #${cb.batchNo} - ${cb.jobName}"),
                            subtitle: Text("Invoice Clearance Entity: ${cb.clientName}"),
                            trailing: const Text(
                              "READY",
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 14),
                            ),
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
