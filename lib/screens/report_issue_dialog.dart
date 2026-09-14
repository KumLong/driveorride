import 'package:flutter/material.dart';
import '../services/report_service.dart';
import '../theme.dart';

Future<void> showReportIssueDialog(
    BuildContext context, {
      required String category,
      String? stationName,
      double? latitude,
      double? longitude,
    }) async {
  final reportService = ReportService();
  String issueType = 'accident';
  final descriptionCtrl = TextEditingController();
  bool submitting = false;
  String? error;

  await showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.report_problem_outlined, color: Colors.redAccent),
                ),
                const SizedBox(width: 12),
                const Text('Report an Issue', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.teal)),
              ]),
              const SizedBox(height: 8),
              Text(
                category == 'road'
                    ? 'Reports your current location — other drivers nearby may see this once reviewed.'
                    : 'Reports the station you\'re currently at — other riders on this line may see this once reviewed.',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),

              const Text('Issue type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.teal)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: [
                  _typeChip('accident', 'Accident', issueType, (v) => setDialogState(() => issueType = v)),
                  _typeChip('breakdown', category == 'road' ? 'Breakdown' : 'Train Breakdown', issueType, (v) => setDialogState(() => issueType = v)),
                  _typeChip('delay', 'Delay', issueType, (v) => setDialogState(() => issueType = v)),
                  _typeChip('other', 'Other', issueType, (v) => setDialogState(() => issueType = v)),
                ],
              ),
              const SizedBox(height: 16),

              const Text('Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.teal)),
              const SizedBox(height: 8),
              TextField(
                controller: descriptionCtrl,
                maxLines: 3,
                maxLength: 200,
                decoration: InputDecoration(
                  hintText: 'Please describe the situation.',
                  filled: true,
                  fillColor: AppColors.bg,
                  errorText: error,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: submitting ? null : () => Navigator.pop(dialogContext), child: const Text('Cancel'))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                      onPressed: submitting ? null : () async {
                        final description = descriptionCtrl.text.trim();
                        if (description.isEmpty) {
                          setDialogState(() => error = 'Please describe what happened.');
                          return;
                        }
                        if (description.length < 10) {
                          setDialogState(() => error = 'Please add a bit more detail (at least 10 characters).');
                          return;
                        }
                        setDialogState(() { submitting = true; error = null; });
                        try {
                          await reportService.submitReport(
                            category: category,
                            stationName: stationName,
                            latitude: latitude,
                            longitude: longitude,
                            issueType: issueType,
                            description: description,
                          );
                          if (dialogContext.mounted) Navigator.pop(dialogContext);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Report submitted — thanks for helping other commuters.')),
                            );
                          }
                        } catch (e) {
                          setDialogState(() { submitting = false; error = 'Could not submit. Please try again.'; });
                        }
                      },
                      child: submitting
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Submit Report'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _typeChip(String value, String label, String currentValue, ValueChanged<String> onSelected) {
  final selected = value == currentValue;
  return GestureDetector(
    onTap: () => onSelected(value),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? Colors.redAccent : AppColors.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : Colors.grey.shade700)),
    ),
  );
}