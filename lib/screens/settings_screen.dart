import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/pet_controller.dart';
import '../theme/app_theme.dart';

/// Settings: sound on/off, vibration on/off, editable footer text and a
/// confirm-guarded counter reset. All values persist via PetController ->
/// SharedPreferences (fully offline).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _footer;

  @override
  void initState() {
    super.initState();
    _footer = TextEditingController(text: context.read<PetController>().footerText);
  }

  @override
  void dispose() {
    _footer.dispose();
    super.dispose();
  }

  Future<void> _confirmReset() async {
    final pet = context.read<PetController>();
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Maar counter reset karein?'),
        content: Text('Abhi ${pet.hits} maar record hain.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Nahi')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset')),
        ],
      ),
    );
    if (yes == true) {
      await pet.resetCounter();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Counter reset ho gaya 😌')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pet = context.watch<PetController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _card(context, child: Column(
            children: [
              SwitchListTile(
                title: const Text('Sound effects'),
                subtitle: const Text('Ouch, giggle aur talking voice'),
                value: pet.soundsOn,
                onChanged: (v) => pet.setSounds(v),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Vibration'),
                subtitle: const Text('Halka haptic jab Miko ko maaro'),
                value: pet.vibrationOn,
                onChanged: (v) => pet.setVibration(v),
              ),
            ],
          )),
          const SizedBox(height: 12),

          // ---- editable footer line ----
          _card(context, child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Footer line',
                    style: TextStyle(fontWeight: FontWeight.w600, color: context.ink)),
                const SizedBox(height: 6),
                TextField(
                  controller: _footer,
                  maxLength: 48,
                  decoration: const InputDecoration(
                    hintText: 'Sirf Yashi ke liye 💗',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (v) => pet.setFooter(v),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      pet.setFooter(_footer.text);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Saved 💗')),
                      );
                    },
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          )),
          const SizedBox(height: 12),

          // ---- reset counter ----
          _card(context, child: ListTile(
            leading: Icon(Icons.restart_alt_rounded, color: context.accent),
            title: const Text('Reset maar counter'),
            subtitle: Text('Abhi: ${pet.hits}'),
            onTap: _confirmReset,
          )),
          const SizedBox(height: 20),

          Center(
            child: Text(
              'Miko Monkey v1.0.0\nOriginal character • No ads • No tracking',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: context.ink.withOpacity(0.6), height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, {required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.35 : 0.07),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
