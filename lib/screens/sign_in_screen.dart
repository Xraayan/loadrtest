import 'package:flutter/material.dart';
import '../constants.dart';
import '../services/api_service.dart';
import '../widgets/skeleton.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  void _handleSignIn() async {
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email')),
      );
      return;
    }
    final phoneDigits = phone.replaceAll(RegExp(r'\D'), '');
    if (phoneDigits.length < 10 || phoneDigits.length > 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid phone number')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ApiService.signIn(email, phone: phone);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP sent to your email')),
        );
        Navigator.pushNamed(
          context,
          '/otp',
          arguments: {'email': email, 'phone': phone},
        );
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
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 50),
            Image.asset('assets/loadr_logo.png', width: 44, height: 44),
            const Text("Welcome LoadR",
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const Text("Please enter your sign in details.",
                style: TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 50),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              enabled: !_isLoading,
              decoration: InputDecoration(
                labelText: "Email",
                hintText: "Enter email address",
                suffixIcon:
                    const Icon(Icons.email_outlined, color: Colors.grey),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              enabled: !_isLoading,
              decoration: InputDecoration(
                labelText: "Phone number",
                hintText: "Enter phone number",
                suffixIcon:
                    const Icon(Icons.phone_outlined, color: Colors.grey),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const Spacer(),
            const Center(
              child: Text.rich(
                TextSpan(
                  text: "By clicking Next, you agree with our\n",
                  children: [
                    TextSpan(
                        text: "Terms and Conditions",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: " and "),
                    TextSpan(
                        text: "Privacy Policy",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleSignIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryOrange,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
              ),
              child: _isLoading
                  ? const SkeletonButtonLabel(width: 64)
                  : const Text("Sign In", style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
