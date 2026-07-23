import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';

import '../constants.dart';
import '../services/api_service.dart';
import '../widgets/skeleton.dart';

class OTPScreen extends StatefulWidget {
  const OTPScreen({super.key});

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final _otpController = TextEditingController();
  final _otpFocusNode = FocusNode();

  Timer? _timer;
  bool _isLoading = false;
  bool _isResending = false;
  int _secondsLeft = 30;

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _otpFocusNode.requestFocus();
    });
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        if (mounted) setState(() => _secondsLeft = 0);
        return;
      }
      if (mounted) setState(() => _secondsLeft--);
    });
  }

  Future<void> _handleVerifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the 4 digit OTP')),
      );
      return;
    }

    final email = _email;
    if (email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email not found')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ApiService.verifyOtp(email, otp, phone: _phone);
      final nextRoute = await ApiService.resolveRouteAfterAuth();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        nextRoute,
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      _otpController.clear();
      _otpFocusNode.requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('OTP verification failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOtp() async {
    final email = _email;
    if (email == null || _secondsLeft > 0) return;

    setState(() => _isResending = true);
    try {
      await ApiService.signIn(email, phone: _phone);
      if (!mounted) return;
      _otpController.clear();
      _otpFocusNode.requestFocus();
      _startTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP sent again')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Resend failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  String? get _email {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String) return args;
    if (args is Map) {
      final email = '${args['email'] ?? ''}'.trim();
      return email.isEmpty ? null : email;
    }
    return null;
  }

  String? get _phone {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map) return null;
    final phone = '${args['phone'] ?? ''}'.trim();
    return phone.isEmpty ? null : phone;
  }

  String get _maskedEmail {
    final email = _email ?? '';
    final at = email.indexOf('@');
    if (at <= 1) return email;
    return '${email[0]}***${email.substring(at)}';
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 68,
      height: 68,
      textStyle: const TextStyle(
        color: Colors.black87,
        fontSize: 24,
        fontWeight: FontWeight.w900,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7E7E7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: 'Back',
                onPressed:
                    _isLoading ? null : () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: kPrimaryOrange.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline,
                color: kPrimaryOrange,
                size: 28,
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Enter OTP',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'We sent a 4 digit code to $_maskedEmail',
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 36),
            Center(
              child: Pinput(
                controller: _otpController,
                focusNode: _otpFocusNode,
                length: 4,
                autofocus: true,
                enabled: !_isLoading,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                defaultPinTheme: defaultPinTheme,
                focusedPinTheme: defaultPinTheme.copyWith(
                  decoration: defaultPinTheme.decoration!.copyWith(
                    border: Border.all(color: kPrimaryOrange, width: 2),
                  ),
                ),
                submittedPinTheme: defaultPinTheme.copyWith(
                  decoration: defaultPinTheme.decoration!.copyWith(
                    border: Border.all(
                        color: kPrimaryOrange.withValues(alpha: 0.45)),
                  ),
                ),
                onCompleted: (_) => _handleVerifyOtp(),
              ),
            ),
            const SizedBox(height: 34),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleVerifyOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryOrange,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      kPrimaryOrange.withValues(alpha: 0.55),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const SkeletonButtonLabel(width: 72)
                    : const Text(
                        'Verify and Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 22),
            Center(
              child: TextButton(
                onPressed: (_secondsLeft == 0 && !_isResending && !_isLoading)
                    ? _resendOtp
                    : null,
                child: _isResending
                    ? const SkeletonBox(width: 86, height: 12, radius: 4)
                    : Text(
                        _secondsLeft == 0
                            ? 'Resend code'
                            : 'Resend code in ${_secondsLeft}s',
                        style: TextStyle(
                          color: _secondsLeft == 0
                              ? kPrimaryOrange
                              : Colors.black38,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }
}
