import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/database_service.dart';

/// FULL CRUD TEMPLATE — Saved Locations, using SQLite (Practical 9 pattern).
/// Copy this exact structure for Savings Goals and Trip History screens.
class SavedLocationsScreen extends StatefulWidget {
  const SavedLocationsScreen({super.key});

  @override
  State<SavedLocationsScreen> createState() => _SavedLocationsScreenState();
}

class _SavedLocationsScreenState extends State<SavedLocationsScreen> {
  final _db = DatabaseService();
  List<SavedLocationModel> _locations = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  // READ
  Future<void> _refresh() async {
    final locations = await _db.getLocations();
    setState(() => _locations = locations);
  }

  // CREATE / UPDATE — shared dialog form
  void _showLocationForm({SavedLocationModel? existing}) {
    final labelCtrl = TextEditingController(text: existing?.label ?? '');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Location' : 'Edit Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: labelCtrl, decoration: const InputDecoration(labelText: 'Label (e.g. Home)')),
            TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (labelCtrl.text.isEmpty || addressCtrl.text.isEmpty) return;

              if (existing == null) {
                // CREATE — in the full app, geocode the address first via
                // RoutingService.geocode() to get real lat/lon.
                await _db.insertLocation(SavedLocationModel(
                  label: labelCtrl.text,
                  address: addressCtrl.text,
                  lat: 0,
                  lon: 0,
                ));
              } else {
                // UPDATE
                await _db.updateLocation(SavedLocationModel(
                  id: existing.id,
                  label: labelCtrl.text,
                  address: addressCtrl.text,
                  lat: existing.lat,
                  lon: existing.lon,
                ));
              }
              if (ctx.mounted) Navigator.pop(ctx);
              _refresh();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // DELETE
  Future<void> _deleteLocation(int id) async {
    await _db.deleteLocation(id);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Locations')),
      body: _locations.isEmpty
          ? const Center(child: Text('No saved locations yet. Tap + to add one.'))
          : ListView.builder(
              itemCount: _locations.length,
              itemBuilder: (ctx, i) {
                final loc = _locations[i];
                return ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(loc.label),
                  subtitle: Text(loc.address),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => _showLocationForm(existing: loc)),
                      IconButton(icon: const Icon(Icons.delete_outline, size: 20), onPressed: () => _deleteLocation(loc.id!)),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(onPressed: () => _showLocationForm(), child: const Icon(Icons.add)),
    );
  }
}
