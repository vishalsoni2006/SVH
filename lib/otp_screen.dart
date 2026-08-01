import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'capture_screen.dart';

class OtpScreen extends StatefulWidget {
  final String verificationId;
  final String phone;
  const OtpScreen({super.key, required this.verificationId, required this.phone});
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otpController = TextEditingController();
  bool _verifying = false;

  Future<void> _verify() async {
    setState(() => _verifying = true);
    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: _otpController.text.trim(),
      );
      await FirebaseAuth.instance.signInWithCredential(cred);
      if (mounted) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const CaptureScreen()));
      }
    } catch (e) {
      setState(() => _verifying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid OTP, try again')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify OTP')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Enter the 6-digit code sent to ${widget.phone}'),
            const SizedBox(height: 20),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _verifying ? null : _verify,
              child: _verifying
                  ? const CircularProgressIndicator()
                  : const Text('Verify & Login'),
            ),
          ],
        ),
      ),
    );
  }
}