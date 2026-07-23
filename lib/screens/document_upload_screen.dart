import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import '../services/api_service.dart';
import '../widgets/onboarding_stepper.dart';
import '../widgets/skeleton.dart';

class DocumentUploadScreen extends StatefulWidget {
  const DocumentUploadScreen({super.key});

  @override
  State<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedDocument;
  bool _isUploading = false;

  Future<void> _chooseSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Capture with camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) {
      return;
    }

    final pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (pickedFile == null) {
      return;
    }

    if (!mounted) return;
    setState(() => _selectedDocument = pickedFile);
  }

  Future<void> _handleUpload() async {
    final document = _selectedDocument;
    if (document == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose or capture your license')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('uid');
      if (uid == null) {
        throw Exception('User not authenticated');
      }

      await ApiService.uploadDocument(
        uid,
        filePath: document.path,
        filename: document.name,
      );

      if (mounted) {
        Navigator.pushNamed(context, '/success');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const OnboardingStepper(currentStep: 3),
              const Text("Step 3 of 3", style: TextStyle(color: Colors.grey)),
              const Text(
                "Verify Driver License",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "Upload a legible picture of your driver license to verify it.",
                style: TextStyle(color: Colors.black87),
              ),
              const SizedBox(height: 40),
              InkWell(
                onTap: _chooseSource,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: double.infinity,
                  height: 250,
                  decoration: BoxDecoration(
                    color: _selectedDocument != null
                        ? kPrimaryOrange.withValues(alpha: 0.06)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _selectedDocument != null
                          ? kPrimaryOrange
                          : Colors.grey.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  child: _selectedDocument == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.cloud_upload_outlined,
                              size: 80,
                              color: Colors.grey[700],
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              "Choose image or capture image",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        )
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.file(
                                File(_selectedDocument!.path),
                                fit: BoxFit.cover,
                              ),
                            ),
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  borderRadius: const BorderRadius.vertical(
                                    bottom: Radius.circular(18),
                                  ),
                                ),
                                child: Text(
                                  _selectedDocument!.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 10,
                              top: 10,
                              child: CircleAvatar(
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.9),
                                child: IconButton(
                                  tooltip: 'Change image',
                                  icon: const Icon(Icons.edit_outlined),
                                  color: kPrimaryOrange,
                                  onPressed: _chooseSource,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              if (_selectedDocument != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isUploading ? null : _chooseSource,
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Choose another image'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    foregroundColor: kPrimaryOrange,
                    side: const BorderSide(color: kPrimaryOrange),
                  ),
                ),
              ],
              const Spacer(),
              ElevatedButton(
                onPressed: _isUploading ? null : _handleUpload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryOrange,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isUploading
                    ? const SkeletonButtonLabel(width: 44)
                    : const Text(
                        "NEXT",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
