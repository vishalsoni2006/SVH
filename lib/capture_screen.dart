import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'site_data.dart';
import 'reading.dart';
import 'db_helper.dart';
import 'readings_list_screen.dart';
import 'qr_scan_screen.dart';
import 'sync_service.dart';


class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  CameraController? _controller;
  final _valueController = TextEditingController();
  String? _photoPath;
  Position? _position;
  MonitoringSite? _nearestSite;
  double? _distanceToNearest;
  String? _qrSiteId;
  bool _mismatchConfirmed = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final rearCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
    );
    _controller = CameraController(rearCamera, ResolutionPreset.high);
    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _takePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final file = await _controller!.takePicture();
    setState(() => _photoPath = file.path);
    await _getLocation();
  }

  Future<void> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) return;

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    MonitoringSite? nearest;
    double? minDist;
    for (final site in sites) {
      final d = distanceInMeters(pos.latitude, pos.longitude, site.lat, site.lng);
      if (minDist == null || d < minDist) {
        minDist = d;
        nearest = site;
      }
    }

    if (mounted) {
      setState(() {
        _position = pos;
        _nearestSite = nearest;
        _distanceToNearest = minDist;
      });
    }
  }

  Future<void> _scanQr() async {
    await _controller?.dispose();
    _controller = null;
    if (mounted) setState(() {});

    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );

    await _initCamera();

    if (result != null && mounted) {
      setState(() {
        _qrSiteId = result;
        _mismatchConfirmed = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('QR confirms site: $result')),
      );
    }
  }

  Future<void> _openReadingsList() async {
    await _controller?.dispose();
    _controller = null;
    if (mounted) setState(() {});

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ReadingsListScreen()),
    );

    await _initCamera();
  }

  Future<bool> _showMismatchDialog() async {
    final distanceKm = _distanceToNearest != null
        ? (_distanceToNearest! / 1000).toStringAsFixed(0)
        : '?';
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Site mismatch detected'),
        content: Text(
          'The QR code says "$_qrSiteId", but your GPS location is closest to '
          '"${_nearestSite?.name}" (${distanceKm}km from there).\n\n'
          'This reading will be flagged for review. Continue anyway?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue anyway'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _saveReading() async {
    if (_photoPath == null || _position == null || _valueController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Take a photo and enter a value first')),
      );
      return;
    }

    final parsedValue = double.tryParse(_valueController.text);
    if (parsedValue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid numeric reading value')),
      );
      return;
    }

    final hasMismatch = _qrSiteId != null &&
        _nearestSite != null &&
        _qrSiteId != _nearestSite!.id;

    if (hasMismatch && !_mismatchConfirmed) {
      final confirmed = await _showMismatchDialog();
      if (!confirmed) return;
      if (mounted) {
        setState(() => _mismatchConfirmed = true);
      }
    }

    final timestamp = DateTime.now().toIso8601String();
    final previousHash = await DBHelper.getLatestHash();

    final hashInput = '$_photoPath|${_position!.latitude}|${_position!.longitude}|$timestamp|${previousHash ?? ''}';
    final captureHash = sha256.convert(utf8.encode(hashInput)).toString();

    await DBHelper.insertReading({
      'site_id': _qrSiteId ?? _nearestSite?.id ?? 'UNKNOWN',
      'value': parsedValue,
      'lat': _position!.latitude,
      'lng': _position!.longitude,
      'timestamp': timestamp,
      'photo_path': _photoPath,
      'had_mismatch': hasMismatch ? 1 : 0,
      'capture_hash': captureHash,
      'previous_hash': previousHash,
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reading saved locally ✓')),
    );

    setState(() {
      _photoPath = null;
      _valueController.clear();
      _qrSiteId = null;
      _mismatchConfirmed = false;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capture reading'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_upload),
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Syncing...')),
              );
              final count = await SyncService.syncPendingReadings();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Synced $count reading(s) ✓')),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: _openReadingsList,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: _controller == null || !_controller!.value.isInitialized
                ? const Center(child: CircularProgressIndicator())
                : _photoPath == null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          CameraPreview(_controller!),
                          Center(
                            child: Container(
                              width: 220,
                              height: 140,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Image.file(File(_photoPath!)),
          ),
          if (_distanceToNearest != null)
            Container(
              color: _distanceToNearest! <= 100 ? Colors.green[100] : Colors.red[100],
              padding: const EdgeInsets.all(8),
              child: Text(
                _distanceToNearest! <= 100
                    ? 'Within range of ${_nearestSite!.name}'
                    : 'Warning: ${_distanceToNearest!.toStringAsFixed(0)}m from nearest site',
              ),
            ),
          if (_qrSiteId != null)
            Container(
              color: Colors.blue[100],
              padding: const EdgeInsets.all(8),
              width: double.infinity,
              child: Text('QR confirmed: $_qrSiteId', textAlign: TextAlign.center),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _valueController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Water level reading (m)',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _photoPath == null
                        ? _takePhoto
                        : () => setState(() => _photoPath = null),
                    child: Text(_photoPath == null ? 'Capture photo' : 'Retake'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: _scanQr,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveReading,
                    child: const Text('Save reading'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}