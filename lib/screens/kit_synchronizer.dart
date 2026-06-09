import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';

class KitSynchronizerScreen extends StatelessWidget {
  const KitSynchronizerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<EMSStateEngine>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Kit Synchronizer Gateway"),
        backgroundColor: const Color(0xFF008080),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.cloud_sync, size: 80, color: Color(0xFF008080)),
              const SizedBox(height: 16),
              const Text(
                "Global Data Sync Console",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF004d4d)),
              ),
              const SizedBox(height: 8),
              const Text(
                "Align local state engines with background Computer Vision processing pipelines and Flask servers safely.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    _buildSyncStatusRow("Live Operational Batches", "${state.batches.length} Records Tracked"),
                    const Divider(),
                    _buildSyncStatusRow("Allocation Targets Logged", "${state.targetingMatrix.length} Rules Active"),
                    const Divider(),
                    _buildSyncStatusRow("Traceability Ledger Blocks", "${state.materialLedger.length} Emitted Hashes"),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              state.isLoading
                  ? const Column(
                      children: [
                        CircularProgressIndicator(color: Color(0xFF008080)),
                        SizedBox(height: 12),
                        Text("Executing dynamic server pipeline fetch request...", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                      ],
                    )
                  : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF008080),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        await state.fetchAndSyncFromBackend();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("All framework registers fully updated."), backgroundColor: Colors.green)
                        );
                      },
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      label: const Text("EXECUTE FORCE SYNC HANDSHAKE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSyncStatusRow(String title, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF004d4d))),
          Text(val, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        ],
      ),
    );
  }
}
