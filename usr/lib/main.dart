import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const DssVerifierApp());
}

class DssVerifierApp extends StatelessWidget {
  const DssVerifierApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DSS Signature Verifier',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const VerifierScreen(),
      },
    );
  }
}

class VerifierScreen extends StatefulWidget {
  const VerifierScreen({super.key});

  @override
  State<VerifierScreen> createState() => _VerifierScreenState();
}

class _VerifierScreenState extends State<VerifierScreen> {
  String _statusMessage = 'Select a signed PDF to verify';
  bool _isLoading = false;
  Map<String, dynamic>? _validationResult;
  
  // Default local DSS API URL - user can change this in a real app
  final String _apiUrl = 'http://localhost:8080/services/rest/validation/validateSignature';

  Future<void> _pickAndVerifyPdf() async {
    try {
      // 1. Pick File
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true, // Important for web/desktop to get bytes directly
      );

      if (result == null) return;

      setState(() {
        _isLoading = true;
        _statusMessage = 'Processing ${result.files.single.name}...';
        _validationResult = null;
      });

      PlatformFile file = result.files.single;
      Uint8List? fileBytes = file.bytes;

      // On some platforms (like mobile), bytes might be null but path is available
      if (fileBytes == null && file.path != null) {
        fileBytes = await File(file.path!).readAsBytes();
      }

      if (fileBytes == null) {
        throw Exception("Could not read file data");
      }

      // 2. Prepare Payload for DSS API
      // DSS REST API expects a JSON object with the Base64 encoded file
      String base64Pdf = base64Encode(fileBytes);
      
      Map<String, dynamic> requestBody = {
        "signedDocument": {
          "bytes": base64Pdf,
          "digestAlgorithm": null,
          "name": file.name
        },
        "originalDocuments": [],
        "policy": null,
        "signatureId": null,
        "level": null
      };

      // 3. Call API
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {"Content-Type": "application/json", "Accept": "application/json"},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        _processResponse(jsonResponse);
      } else {
        throw Exception("API Error: ${response.statusCode} - ${response.body}");
      }

    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
        if (e.toString().contains("Connection refused")) {
          _statusMessage += "\n\nMake sure the DSS Webapp is running locally on port 8080.";
        }
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _processResponse(Map<String, dynamic> json) {
    // DSS returns a complex object. We are interested in the 'SimpleReport'.
    // Structure usually: { "simpleReport": { ... }, "detailedReport": { ... }, ... }
    // Or sometimes the root IS the report depending on the endpoint version.
    // We'll try to find 'SimpleReport' or assume root if keys match.
    
    Map<String, dynamic>? simpleReport = json['simpleReport'] ?? json;
    
    // Check for signatures
    // Usually simpleReport['signatureOrTimestamp'] is a list
    var signatures = simpleReport?['signatureOrTimestamp'];
    
    if (signatures == null || (signatures is List && signatures.isEmpty)) {
      setState(() {
        _statusMessage = "No signatures found in the document.";
      });
      return;
    }

    // For this demo, we check the first signature
    var firstSig = (signatures is List) ? signatures.first : signatures;
    
    // RELEVANT FIELDS FOR VALIDITY:
    // 1. Indication: Should be 'TOTAL_PASSED'
    // 2. SubIndication: If not passed, this gives the reason (e.g., 'NO_CERTIFICATE_CHAIN_FOUND')
    
    String indication = firstSig['indication'] ?? 'UNKNOWN';
    String? subIndication = firstSig['subIndication'];
    
    bool isValid = indication == 'TOTAL_PASSED';

    setState(() {
      _statusMessage = isValid ? "Signature is VALID" : "Signature is INVALID";
      _validationResult = {
        "Indication": indication,
        "SubIndication": subIndication ?? "None",
        "Signed By": firstSig['signedBy'] ?? "Unknown",
        "Signing Time": firstSig['signingTime'] ?? "Unknown",
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DSS Signature Verifier'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading)
                const CircularProgressIndicator()
              else ...[
                Icon(
                  _validationResult == null 
                      ? Icons.picture_as_pdf 
                      : (_statusMessage.contains("VALID") ? Icons.check_circle : Icons.error),
                  size: 80,
                  color: _validationResult == null 
                      ? Colors.grey 
                      : (_statusMessage.contains("VALID") ? Colors.green : Colors.red),
                ),
                const SizedBox(height: 20),
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 30),
                if (_validationResult != null) ...[
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _validationResult!.entries.map((e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("${e.key}: ", style: const TextStyle(fontWeight: FontWeight.bold)),
                              Flexible(child: Text(e.value.toString())),
                            ],
                          ),
                        )).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
                ElevatedButton.icon(
                  onPressed: _pickAndVerifyPdf,
                  icon: const Icon(Icons.upload_file),
                  label: const Text("Select PDF & Verify"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Note: Ensure DSS Webapp is running at http://localhost:8080",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
