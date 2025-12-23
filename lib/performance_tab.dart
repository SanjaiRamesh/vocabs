import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'assessment_result_service.dart';
import 'assessment_result.dart';

class PerformanceTab extends StatefulWidget {
  final VoidCallback? onSetHeaderTitle;
  const PerformanceTab({super.key, this.onSetHeaderTitle});
  @override
  State<PerformanceTab> createState() => _PerformanceTabState();
}

class _PerformanceTabState extends State<PerformanceTab> {
  List<AssessmentResult> _results = [];
  bool _exporting = false;
  String? _exportPath;

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    await AssessmentResultService.init();
    final results = await AssessmentResultService.getAllResults();
    setState(() {
      _results = results;
    });
  }

  Color _resultColor(String result) {
    switch (result) {
      case 'correct':
        return Colors.green;
      case 'incorrect':
        return Colors.red;
      default:
        return Colors.yellow;
    }
  }

  Future<void> _exportToCSV() async {
    setState(() {
      _exporting = true;
      _exportPath = null;
    });
    final rows = <List<String>>[
      ['Date', 'Word', 'Heard', 'Result', 'List Name', 'Subject'],
      ..._results.map(
        (r) => [
          r.date.split('T').first,
          r.word,
          r.heard,
          r.result,
          r.listName,
          r.subject,
        ],
      ),
    ];
    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      '${dir.path}/assessment_results_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
    await file.writeAsString(csv);
    setState(() {
      _exporting = false;
      _exportPath = file.path;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Performance')),
      body: Column(
        children: [
          if (_exporting) const LinearProgressIndicator(),
          if (_exportPath != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Exported to: $_exportPath',
                style: const TextStyle(color: Colors.green),
              ),
            ),
          Expanded(
            child: _results.isEmpty
                ? const Center(child: Text('No results yet.'))
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Word')),
                        DataColumn(label: Text('Heard')),
                        DataColumn(label: Text('Result')),
                        DataColumn(label: Text('List')),
                        DataColumn(label: Text('Subject')),
                      ],
                      rows: _results
                          .map(
                            (r) => DataRow(
                              cells: [
                                DataCell(Text(r.date.split('T').first)),
                                DataCell(Text(r.word)),
                                DataCell(Text(r.heard)),
                                DataCell(
                                  Row(
                                    children: [
                                      Icon(
                                        r.result == 'correct'
                                            ? Icons.check
                                            : Icons.close,
                                        color: _resultColor(r.result),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(r.result),
                                    ],
                                  ),
                                ),
                                DataCell(Text(r.listName)),
                                DataCell(Text(r.subject)),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: _results.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _exportToCSV,
              icon: const Icon(Icons.download),
              label: const Text('Export CSV'),
            )
          : null,
    );
  }
}
