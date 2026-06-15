import 'package:flutter/material.dart';
import '../constants.dart';
import '../services/api_service.dart';

class OTPScreen extends StatefulWidget {
  const OTPScreen({super.key});

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final _otpControllers = List.generate(4, (_) => TextEditingController());
  bool _isLoading = false;

  void _handleVerifyOtp() async {
    String otp = _otpControllers.map((c) => c.text).join();

    if (otp.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter complete OTP')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final phone = ModalRoute.of(context)?.settings.arguments as String?;
      if (phone == null) throw Exception('Phone number not found');

      final response = await ApiService.verifyOtp(phone, otp);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication successful')),
        );
        Navigator.pushNamed(context, '/location');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = ModalRoute.of(context)?.settings.arguments as String?;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 50),
            const Text("Enter OTP",
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            Text(
              "Please enter the 4 digit OTP sent on +91${phone?.replaceRange(0, phone.length - 4, '*' * (phone.length - 4)) ?? '****'}.",
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(4, (index) => _otpBox(index)),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleVerifyOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryOrange,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : const Text("NEXT"),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text.rich(TextSpan(children: [
                const TextSpan(text: "Didn't receive the code? "),
                TextSpan(
                    text: "Resend (30s)",
                    style: TextStyle(
                        color: kPrimaryOrange, fontWeight: FontWeight.bold)),
              ])),
            )
          ],
        ),
      ),
    );
  }

  Widget _otpBox(int index) {
    return Container(
      width: 65,
      height: 65,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _otpControllers[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        enabled: !_isLoading,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        decoration: const InputDecoration(
          border: InputBorder.none,
          counterText: '',
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 3) {
            FocusScope.of(context).nextFocus();
          } else if (value.isEmpty && index > 0) {
            FocusScope.of(context).previousFocus();
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}
