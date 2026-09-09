import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../theme.dart';

/// FULL CRUD — Saved Locations, using SQLite (Practical 9 pattern).
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

  Future<void> _refresh() async {
    final locations = await _db.getLocations();
    setState(() => _locations = locations);
  }

  Widget _styledField({required TextEditingController ctrl, required String hint, required IconData icon}) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.mint, size: 20),
        filled: true,
        fillColor: AppColors.bg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      ),
    );
  }

  // CREATE / UPDATE — shared dialog form, now matching the app's real dialog style
  void _showLocationForm({SavedLocationModel? existing}) {
    final labelCtrl = TextEditingController(text: existing?.label ?? '');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');
    final isEditing = existing != null;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: AppColors.mintLight, borderRadius: BorderRadius.circular(12)),
                    child: Icon(isEditing ? Icons.edit_location_alt : Icons.add_location_alt, color: AppColors.mint),
                  ),
                  const SizedBox(width: 12),
                  Text(isEditing ? 'Edit Location' : 'Add Location', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.teal)),
                ],
              ),
              const SizedBox(height: 20),
              _styledField(ctrl: labelCtrl, hint: 'Label (e.g. Home)', icon: Icons.label_outline),
              const SizedBox(height: 12),
              _styledField(ctrl: addressCtrl, hint: 'Address', icon: Icons.location_on_outlined),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (labelCtrl.text.isEmpty || addressCtrl.text.isEmpty) return;

                        if (existing == null) {
                          // CREATE — in the full app, geocode the address first
                          // via RoutingService.geocode() to get real lat/lon.
                          await _db.insertLocation(SavedLocationModel(
                            label: labelCtrl.text,
                            address: addressCtrl.text,
                            lat: 0,
                            lon: 0,
                          ));
                        } else {
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
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteLocation(int id) async {
    await _db.deleteLocation(id);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Saved Locations')),
      body: _locations.isEmpty
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(color: AppColors.mintLight, shape: BoxShape.circle),
                child: const Icon(Icons.location_on_outlined, color: AppColors.mint, size: 32),
              ),
              const SizedBox(height: 16),
              const Text('No saved locations yet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.teal)),
              const SizedBox(height: 4),
              const Text('Tap the + button below to add one', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _locations.length,
        itemBuilder: (ctx, i) {
          final loc = _locations[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: AppColors.mintLight, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.location_on, color: AppColors.mint, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(loc.label.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.teal, letterSpacing: 0.3)),
                      const SizedBox(height: 2),
                      Text(loc.address, style: const TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit_outlined, size: 18, color: Colors.grey.shade600),
                  onPressed: () => _showLocationForm(existing: loc),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                  onPressed: () => _deleteLocation(loc.id!),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.mint,
        onPressed: () => _showLocationForm(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}