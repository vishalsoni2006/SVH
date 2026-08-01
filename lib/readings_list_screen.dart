import 'package:flutter/material.dart';
import 'db_helper.dart';

class ReadingsListScreen extends StatefulWidget {
  const ReadingsListScreen({super.key});
  @override
  State<ReadingsListScreen> createState() => _ReadingsListScreenState();
}

class _ReadingsListScreenState extends State<ReadingsListScreen> {
  List<Map<String, dynamic>> _readings = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await DBHelper.getAllReadings();
    setState(() => _readings = data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved readings'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _readings.isEmpty
          ? const Center(child: Text('No readings saved yet'))
          : ListView.builder(
              itemCount: _readings.length,
              itemBuilder: (context, i) {
                final r = _readings[i];
                return ListTile(
                  leading: Icon(
                    r['sync_status'] == 'synced'
                        ? Icons.cloud_done
                        : Icons.cloud_upload_outlined,
                    color: r['sync_status'] == 'synced' ? Colors.green : Colors.orange,
                  ),
                  title: Text('${r['site_id']} — ${r['value']} m'),
                  subtitle: Text(r['timestamp']),
                );
              },
            ),
    );
  }
}