import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models.dart';
import '../theme.dart';

class QRPairingScreen extends StatefulWidget {
  final EphemeralProfile myProfile;
  final Peer targetPeer;
  final Function(String) onVerified;

  const QRPairingScreen({
    super.key,
    required this.myProfile,
    required this.targetPeer,
    required this.onVerified,
  });

  @override
  State<QRPairingScreen> createState() => _QRPairingScreenState();
}

class _QRPairingScreenState extends State<QRPairingScreen> {
  bool _isScanning = false;
  String _errorMsg = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: YamiTheme.bgDeep,
      appBar: AppBar(
        backgroundColor: YamiTheme.bgDeep,
        title: Text(
          'VERIFY: ${widget.targetPeer.alias}',
          style: YamiTheme.headingStyle,
        ),
        iconTheme: const IconThemeData(color: YamiTheme.textBright),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 1,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'YOUR IDENTITY (SHOW TO PEER)',
                    style: YamiTheme.labelStyle.copyWith(
                      color: YamiTheme.accentWine,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: QrImageView(
                      data: widget.myProfile.id,
                      version: QrVersions.auto,
                      size: 200.0,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Colors.black,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${widget.myProfile.id.substring(0, 16)}...',
                    style: YamiTheme.monoBrightStyle.copyWith(
                      color: YamiTheme.textSub,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: 1,
            color: YamiTheme.borderMid,
          ),
          Expanded(
            flex: 1,
            child: _buildScannerSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerSection() {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.camera_alt_outlined,
                color: YamiTheme.textGhost,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Camera scanning is only supported on mobile devices.',
                textAlign: TextAlign.center,
                style: YamiTheme.bodySmallStyle.copyWith(
                  color: YamiTheme.textSub,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: YamiTheme.accentBrass,
                  foregroundColor: YamiTheme.bgDeep,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(YamiTheme.radiusSoft),
                  ),
                ),
                onPressed: () {
                  // Fallback for Windows: trust blindly
                  widget.onVerified(widget.targetPeer.id);
                  Navigator.pop(context);
                },
                child: Text(
                  'FORCE VERIFY (DESKTOP)',
                  style: YamiTheme.labelStyle.copyWith(color: YamiTheme.bgDeep),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isScanning) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: Text(
                'SCAN PEER QR',
                style: YamiTheme.labelStyle.copyWith(color: YamiTheme.bgDeep),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: YamiTheme.accentBrass,
                foregroundColor: YamiTheme.bgDeep,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(YamiTheme.radiusSoft),
                ),
              ),
              onPressed: () {
                setState(() {
                  _isScanning = true;
                  _errorMsg = '';
                });
              },
            ),
            if (_errorMsg.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                _errorMsg,
                style: YamiTheme.bodySmallStyle.copyWith(
                  color: YamiTheme.accentEmber,
                ),
              ),
            ]
          ],
        ),
      );
    }

    return Stack(
      children: [
        MobileScanner(
          onDetect: (capture) {
            final List<Barcode> barcodes = capture.barcodes;
            for (final barcode in barcodes) {
              if (barcode.rawValue != null) {
                final scannedId = barcode.rawValue!;
                if (scannedId == widget.targetPeer.id) {
                  widget.onVerified(scannedId);
                  Navigator.pop(context);
                } else {
                  setState(() {
                    _isScanning = false;
                    _errorMsg = 'IDENTITY MISMATCH! Scanned ID does not match the selected peer.';
                  });
                }
                break;
              }
            }
          },
        ),
        Positioned(
          top: 16,
          right: 16,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () {
              setState(() {
                _isScanning = false;
              });
            },
          ),
        ),
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: YamiTheme.accentBrass, width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }
}
