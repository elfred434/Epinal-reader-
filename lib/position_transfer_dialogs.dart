import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PositionCodeDialog extends StatefulWidget {
  const PositionCodeDialog({super.key, required this.code});
  final String code;
  @override
  State<PositionCodeDialog> createState() => _PositionCodeDialogState();
}

class _PositionCodeDialogState extends State<PositionCodeDialog> {
  bool failed = false;
  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Code de lecture'),
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Copiez ce code et envoyez-le à votre autre appareil. Il ne contient pas le livre.',
        ),
        const SizedBox(height: 16),
        SelectableText(widget.code),
        if (failed)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'Copie impossible : sélectionnez le code manuellement.',
            ),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Fermer'),
      ),
      FilledButton.icon(
        onPressed: () async {
          try {
            await Clipboard.setData(ClipboardData(text: widget.code));
            if (context.mounted) Navigator.pop(context, true);
          } catch (_) {
            if (mounted) setState(() => failed = true);
          }
        },
        icon: const Icon(Icons.copy),
        label: const Text('Copier le code'),
      ),
    ],
  );
}

class PositionImportDialog extends StatefulWidget {
  const PositionImportDialog({super.key});
  @override
  State<PositionImportDialog> createState() => _PositionImportDialogState();
}

class _PositionImportDialogState extends State<PositionImportDialog> {
  final controller = TextEditingController();
  bool pasteFailed = false;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Recevoir une position'),
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Collez le code de l’autre appareil. Il remplacera la position actuelle de ce livre.',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          maxLength: 12000,
          decoration: const InputDecoration(
            labelText: 'Code de lecture',
            border: OutlineInputBorder(),
          ),
        ),
        TextButton.icon(
          onPressed: () async {
            try {
              final data = await Clipboard.getData(Clipboard.kTextPlain);
              if (!mounted) return;
              setState(() {
                pasteFailed = data?.text == null;
                if (data?.text != null) controller.text = data!.text!;
              });
            } catch (_) {
              if (mounted) setState(() => pasteFailed = true);
            }
          },
          icon: const Icon(Icons.content_paste),
          label: const Text('Coller'),
        ),
        if (pasteFailed) const Text('Presse-papiers vide ou inaccessible.'),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, controller.text),
        child: const Text('Appliquer'),
      ),
    ],
  );
}
