import 'package:flutter/material.dart';

class WordSubject {
  final String name;
  WordSubject({required this.name});
}

class WordSubjectManager extends StatefulWidget {
  final List<WordSubject> initialSubjects;
  final void Function(List<WordSubject>)? onSubjectsChanged;
  const WordSubjectManager({
    super.key,
    this.initialSubjects = const [],
    this.onSubjectsChanged,
  });

  @override
  State<WordSubjectManager> createState() => _WordSubjectManagerState();
}

class _WordSubjectManagerState extends State<WordSubjectManager> {
  late List<WordSubject> _subjects;
  String _subjectInput = '';

  @override
  void initState() {
    super.initState();
    _subjects = List.from(widget.initialSubjects);
  }

  void _addSubject() {
    final name = _subjectInput.trim();
    if (name.isEmpty || _subjects.any((s) => s.name == name)) return;
    setState(() {
      _subjects.add(WordSubject(name: name));
      _subjectInput = '';
    });
    widget.onSubjectsChanged?.call(_subjects);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Subjects',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(labelText: 'Add Subject'),
                    onChanged: (v) => setState(() => _subjectInput = v),
                    controller: TextEditingController(text: _subjectInput),
                    onSubmitted: (_) => _addSubject(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.blue),
                  onPressed: _addSubject,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: _subjects
                  .map((s) => Chip(label: Text(s.name)))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
