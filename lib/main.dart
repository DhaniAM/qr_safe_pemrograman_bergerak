import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blueGrey),
      home: const QRViewExample(),
    );
  }
}

class QRViewExample extends StatefulWidget {
  const QRViewExample({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _QRViewExampleState();
}

class _QRViewExampleState extends State<QRViewExample> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  Barcode? result;
  QRViewController? controller;

  @override
  void reassemble() {
    super.reassemble();
    controller!.pauseCamera();
    controller!.resumeCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR Safe Scanner')),
      body: Column(
        children: <Widget>[
          Expanded(flex: 4, child: _buildQrView(context)),
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (result != null)
                  Text('Result: ${result!.code}')
                else
                  const Text('Scan a code'),
                ElevatedButton(
                  onPressed: result != null && result!.code != null
                      ? () => _checkWithVirusTotal(result!.code!)
                      : null,
                  child: const Text('Check with VirusTotal'),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildQrView(BuildContext context) {
    return QRView(
      key: qrKey,
      onQRViewCreated: _onQRViewCreated,
      overlay: QrScannerOverlayShape(
        borderColor: Colors.white,
        borderRadius: 10,
        borderLength: 30,
        borderWidth: 10,
        cutOutSize: MediaQuery.of(context).size.width * 0.8,
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      this.controller = controller;
    });
    controller.scannedDataStream.listen((scanData) {
      setState(() {
        result = scanData;
      });
    });
  }

  Future<void> _checkWithVirusTotal(String url) async {
    const apiKey =
        'd339c89b5ee5df008019c0ab811d3dd79c36f048848ef28e153f0ac2b20bd1fc';
    final encodedUrl = base64Url
        .encode(utf8.encode(url))
        .replaceAll('=', ''); // Encode and remove padding
    final apiUrl = 'https://www.virustotal.com/api/v3/urls/$encodedUrl';
    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'x-apikey': apiKey,
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        // Tampilkan hasil dari VirusTotal (misalnya dideteksi atau aman)
        final scanResult =
            jsonResponse['data']['attributes']['last_analysis_stats'];
        final malicious = scanResult['malicious'];
        final suspicious = scanResult['suspicious'];
        final isDangerous = malicious > 0 || suspicious > 0;

        if (isDangerous) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('VirusTotal Result'),
              content: Text(
                  'Scan Result: URL/Website is dangerous. Don\'t open it to protect yourself!'),
              actions: <Widget>[
                TextButton(
                  child: const Text('OK'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          );
        } else {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('VirusTotal Result'),
              content: Text(
                  'Scan Result: Link is safe! You can open the link safely.'),
              actions: <Widget>[
                TextButton(
                  child: const Text('Close'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: const Text('Open URL'),
                  onPressed: () {
                    _launchUrl(Uri.parse(url));
                  },
                ),
              ],
            ),
          );
        }
      } else {
        _showErrorDialog('Error: Unable to scan the URL with VirusTotal.');
      }
    } catch (e) {
      _showErrorDialog('Error: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(Uri url) async {
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
