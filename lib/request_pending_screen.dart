import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RequestPendingScreen extends StatefulWidget {
  final bool isNewRequest;
  const RequestPendingScreen({super.key, this.isNewRequest = false});
  @override
  State<RequestPendingScreen> createState() => _RequestPendingScreenState();
}

class _RequestPendingScreenState extends State<RequestPendingScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _submitted = false;

  Future<void> _submitRequest() async {
    await FirebaseFirestore.instance.collection('access_requests').add({
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': '+91${_phoneController.text.trim()}',
      'status': 'pending',
      'submitted_at': FieldValue.serverTimestamp(),
    });
    setState(() => _submitted = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isNewRequest || _submitted) {
      return Scaffold(
        appBar: AppBar(title: const Text('Access status')),
        body: const Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.hourglass_top_rounded, size: 60, color: Colors.orange),
              SizedBox(height: 16),
              Text(
                'Your access request is pending supervisor approval.\n\nThis is common for remote monitoring sites — a supervisor will verify your identity and activate your account shortly.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Request access')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Not registered yet, or posted in a low-signal area? Submit your details for manual verification.'),
            const SizedBox(height: 20),
            TextField(controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full name', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _emailController,
                decoration: const InputDecoration(labelText: 'Official email', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _phoneController,
                decoration: const InputDecoration(prefixText: '+91 ', labelText: 'Mobile number', border: OutlineInputBorder())),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _submitRequest, child: const Text('Submit request')),
          ],
        ),
      ),
    );
  }
}