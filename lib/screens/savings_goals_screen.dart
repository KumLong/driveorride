import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../theme.dart';

class SavingsGoalsScreen extends StatefulWidget {
  const SavingsGoalsScreen({super.key});

  @override
  State<SavingsGoalsScreen> createState() => _SavingsGoalsScreenState();
}

class _SavingsGoalsScreenState extends State<SavingsGoalsScreen> {
  final _db = DatabaseService();
  List<SavingsGoalModel> _goals = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final goals = await _db.getGoals();
    setState(() => _goals = goals);
  }

  void _showGoalForm({SavingsGoalModel? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final targetCtrl = TextEditingController(text: existing?.targetAmount.toString() ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Create New Goal' : 'Edit Goal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Goal name (e.g. Concert Tickets)')),
            TextField(
              controller: targetCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Target amount (RM)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final target = double.tryParse(targetCtrl.text) ?? 0;
              if (nameCtrl.text.isEmpty || target <= 0) return;

              if (existing == null) {
                await _db.insertGoal(SavingsGoalModel(name: nameCtrl.text, targetAmount: target));
              } else {
                await _db.updateGoal(SavingsGoalModel(
                  id: existing.id,
                  name: nameCtrl.text,
                  targetAmount: target,
                  savedAmount: existing.savedAmount,
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

  Future<void> _deleteGoal(int id) async {
    await _db.deleteGoal(id);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Savings Goals')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(Icons.track_changes, size: 40, color: AppColors.mint),
                SizedBox(height: 8),
                Text('Set a goal, stay motivated!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 4),
                Text(
                  'Every time you choose transit over driving, your savings grow toward something you love.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Expanded(
            child: _goals.isEmpty
                ? const Center(child: Text('No goals yet. Tap + to create one.'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _goals.length,
                    itemBuilder: (ctx, i) {
                      final goal = _goals[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(goal.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                                  Text('${goal.progressPercent.toStringAsFixed(0)}%',
                                      style: const TextStyle(color: AppColors.mint, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: goal.progressPercent / 100,
                                  backgroundColor: Colors.grey.shade200,
                                  color: AppColors.mint,
                                  minHeight: 8,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text('RM ${goal.savedAmount.toStringAsFixed(2)} of RM ${goal.targetAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    onPressed: () => _showGoalForm(existing: goal),
                                    icon: const Icon(Icons.edit, size: 16),
                                    label: const Text('Edit'),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => _deleteGoal(goal.id!),
                                    icon: const Icon(Icons.delete_outline, size: 16),
                                    label: const Text('Delete'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showGoalForm(),
                icon: const Icon(Icons.add),
                label: const Text('Create New Goal'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.mint, foregroundColor: Colors.white, padding: const EdgeInsets.all(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
