import 'package:flutter/material.dart';
import '../services/local_tts_service.dart';

class NetworkTestScreen extends StatefulWidget {
  const NetworkTestScreen({super.key});

  @override
  State<NetworkTestScreen> createState() => _NetworkTestScreenState();
}

class _NetworkTestScreenState extends State<NetworkTestScreen> {
  Map<String, dynamic>? _testResults;
  bool _isTestingNetwork = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Diagnostics'),
        backgroundColor: Colors.blue.shade100,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'TTS Network Diagnostics',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _isTestingNetwork ? null : _runNetworkTest,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
              child: _isTestingNetwork
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text('Testing Network...'),
                      ],
                    )
                  : const Text(
                      'Run Network Test',
                      style: TextStyle(fontSize: 18),
                    ),
            ),

            const SizedBox(height: 20),

            if (_testResults != null) ...[
              const Text(
                'Test Results:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildResultItem(
                          'Platform',
                          _testResults!['platform']?.toString() ?? 'Unknown',
                          null,
                        ),
                        _buildResultItem(
                          'Base URL',
                          _testResults!['base_url']?.toString() ?? 'Unknown',
                          null,
                        ),
                        _buildResultItem(
                          'Internet Connectivity',
                          _testResults!['internet']?.toString() ?? 'Unknown',
                          _testResults!['internet'] == true,
                        ),
                        _buildResultItem(
                          'Local Network Connectivity',
                          _testResults!['local_network']?.toString() ??
                              'Unknown',
                          _testResults!['local_network'] == true,
                        ),
                        _buildResultItem(
                          'TTS Service Health',
                          _testResults!['tts_service']?.toString() ?? 'Unknown',
                          _testResults!['tts_service'] == true,
                        ),

                        if (_testResults!['tts_response'] != null) ...[
                          const SizedBox(height: 10),
                          const Text(
                            'TTS Service Response:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            margin: const EdgeInsets.only(top: 5),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Text(
                              _testResults!['tts_response'].toString(),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],

                        if (_testResults!['tts_error'] != null) ...[
                          const SizedBox(height: 10),
                          const Text(
                            'TTS Service Error:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            margin: const EdgeInsets.only(top: 5),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Text(
                              _testResults!['tts_error'].toString(),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],

                        const SizedBox(height: 15),
                        const Text(
                          'Alternative IP Tests:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (_testResults!['alternative_ips'] != null) ...[
                          ..._testResults!['alternative_ips'].entries
                              .map<Widget>(
                                (entry) => _buildResultItem(
                                  'IP ${entry.key}',
                                  entry.value.toString(),
                                  entry.value == true,
                                ),
                              )
                              .toList(),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultItem(String label, String value, bool? isSuccess) {
    Color? backgroundColor;
    Color? textColor;

    if (isSuccess != null) {
      backgroundColor = isSuccess ? Colors.green.shade50 : Colors.red.shade50;
      textColor = isSuccess ? Colors.green.shade800 : Colors.red.shade800;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isSuccess == true
              ? Colors.green.shade200
              : isSuccess == false
              ? Colors.red.shade200
              : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(value, style: TextStyle(color: textColor)),
          ),
          if (isSuccess != null) ...[
            Icon(
              isSuccess ? Icons.check_circle : Icons.error,
              color: isSuccess ? Colors.green : Colors.red,
              size: 20,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _runNetworkTest() async {
    setState(() {
      _isTestingNetwork = true;
      _testResults = null;
    });

    try {
      final results = await LocalTtsService.instance.testNetworkConnectivity();
      setState(() {
        _testResults = results;
      });
    } catch (e) {
      setState(() {
        _testResults = {'error': 'Test failed: ${e.toString()}'};
      });
    } finally {
      setState(() {
        _isTestingNetwork = false;
      });
    }
  }
}
