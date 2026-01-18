import 'package:flutter/material.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy & Data Usage'),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text(
              'What Data We Collect',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '• Word attempts and responses (auditory or visual)',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            const Text(
              '• No personal identifiers (name, email, phone number) are collected.',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            const Text(
              '• Practice session timestamps and repetition progress',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            const Text(
              'Where Data is Stored',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '• All data is stored locally on your device.',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            const Text(
              '• No data is sent to external servers.',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            const Text(
              'How We Use Data',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '• Data supports your learning progress and spaced repetition schedule.',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            const Text(
              '• In aggregated, anonymized form, data may be used for research evaluation at the conference.',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
}
