import 'package:flutter/material.dart';
import 'reading_mode.dart';

class ReadingModePicker extends StatelessWidget {
  final ReadingMode selected;
  const ReadingModePicker({super.key, required this.selected});

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .8,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Mode de lecture',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            for (final value in ReadingMode.values)
              ListTile(
                title: Text(value.label),
                subtitle: Text(value.description),
                leading: Icon(switch (value) {
                  ReadingMode.longStrip => Icons.view_stream_outlined,
                  ReadingMode.vertical => Icons.swap_vert,
                  ReadingMode.flipBook => Icons.auto_stories_outlined,
                  _ => Icons.swap_horiz,
                }),
                trailing: value == selected ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, value),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}
