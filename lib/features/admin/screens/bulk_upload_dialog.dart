import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../services/firestore_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/storage_service.dart';
import '../../../core/utils/pdf_classifier.dart';
import '../../../core/utils/input_validator.dart';

class BulkUploadDialog extends ConsumerStatefulWidget {
  final String uploadType; // 'Notes' or 'Question Papers'
  const BulkUploadDialog({super.key, required this.uploadType});

  @override
  ConsumerState<BulkUploadDialog> createState() => _BulkUploadDialogState();
}

class _UploadItem {
  final PlatformFile file;
  String course;
  String subject;
  String semester;
  String year;
  String status; // 'pending', 'approved'
  double confidence;
  String uploadState; // 'waiting', 'uploading', 'success', 'duplicate', 'error'
  String errorMessage;

  _UploadItem({
    required this.file,
    this.course = '',
    this.subject = '',
    this.semester = '',
    this.year = '',
    this.status = 'pending',
    this.confidence = 0,
    this.uploadState = 'waiting',
    this.errorMessage = '',
  });
}

class _BulkUploadDialogState extends ConsumerState<BulkUploadDialog> {
  List<_UploadItem> _items = [];
  bool _isUploading = false;
  int _completedCount = 0;

  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
        withData: true, // IMPORTANT: Required for Web support!
      );

      if (result != null) {
        setState(() {
          for (var platformFile in result.files) {
            // Only accept PDF
            if (platformFile.extension?.toLowerCase() != 'pdf') continue;
            // Max size 20MB
            if (platformFile.size > 20 * 1024 * 1024) continue;

            final classification = PdfClassifier.classifyFromFilename(platformFile.name);
            double confidence = 0.0;
            if (classification.course != null) confidence += 40;
            if (classification.subject != null) confidence += 40;
            if (classification.semester != null || classification.year != null) confidence += 20;

            String determinedType = classification.type ?? (widget.uploadType == 'Notes' ? 'Notes' : 'Paper');

            _items.add(_UploadItem(
              file: platformFile,
              course: classification.course ?? '',
              subject: classification.subject ?? '',
              semester: classification.semester ?? '',
              year: classification.year ?? '',
              confidence: confidence,
              status: confidence >= 90 ? 'approved' : 'pending',
            ));
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error picking files: $e')));
    }
  }

  Future<String> _generateHash(PlatformFile file) async {
    if (file.bytes != null) {
      return sha256.convert(file.bytes!).toString();
    } else if (file.path != null) {
      final bytes = await File(file.path!).readAsBytes();
      return sha256.convert(bytes).toString();
    }
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  Future<bool> _isDuplicate(String hash, String collection) async {
    final query = await FirebaseFirestore.instance.collection(collection).where('fileHash', isEqualTo: hash).limit(1).get();
    return query.docs.isNotEmpty;
  }

  Future<void> _startUpload() async {
    if (_items.isEmpty) return;
    setState(() {
      _isUploading = true;
      _completedCount = 0;
    });

    final user = ref.read(authServiceProvider).currentUser;
    final uploaderId = user?.uid ?? 'unknown_admin';

    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (item.uploadState == 'success' || item.uploadState == 'duplicate') {
        _completedCount++;
        continue;
      }

      setState(() => item.uploadState = 'uploading');

      try {
        final hash = await _generateHash(item.file);
        final collectionName = widget.uploadType == 'Notes' ? 'notes' : 'questionPapers';
        
        final isDup = await _isDuplicate(hash, collectionName);
        if (isDup) {
          setState(() {
            item.uploadState = 'duplicate';
            item.errorMessage = 'Duplicate file skipped.';
            _completedCount++;
          });
          continue;
        }

        final storageService = ref.read(storageServiceProvider);

        String downloadUrl;
        if (item.file.bytes != null) {
          // Web bytes upload: goes through Cloudinary directly (no file path)
          // Server-side scan via bytes is handled by the upload preset settings
          downloadUrl = await storageService.uploadPdfBytes(
            item.file.bytes!, item.file.name, uploaderId,
          );
        } else {
          // Mobile/desktop: run full secure pipeline (pre-flight + scan + upload)
          final (url, _) = await storageService.uploadPdfSecure(
            File(item.file.path!), uploaderId,
          );
          downloadUrl = url;
        }

        final docData = {
          'title': InputValidator.sanitizeSingleLine(p.basenameWithoutExtension(item.file.name)),
          'course': InputValidator.sanitizeSingleLine(item.course.isNotEmpty ? item.course : 'Global'),
          'subject': InputValidator.sanitizeSingleLine(item.subject.isNotEmpty ? item.subject : 'General'),
          'semester': InputValidator.sanitizeSingleLine(item.semester.isNotEmpty ? item.semester : 'All'),
          'year': InputValidator.sanitizeSingleLine(item.year),
          'pdfUrl': downloadUrl,
          'fileHash': hash,
          'uploadedBy': uploaderId,
          'status': item.status,
          'downloads': 0,
          'likes': 0,
          'reports': 0,
          'qualityScore': item.confidence.toInt(),
          'createdAt': FieldValue.serverTimestamp(),
          'collegeId': 'Global',
          'state': 'Global',
          'district': 'Global',
        };

        final docRef = await FirebaseFirestore.instance.collection(collectionName).add(docData);

        // Audit Log
        await FirebaseFirestore.instance.collection('adminLogs').add({
          'adminId': uploaderId,
          'adminName': user?.displayName ?? 'Admin',
          'action': 'Bulk Upload',
          'targetId': docRef.id,
          'targetContent': p.basenameWithoutExtension(item.file.name),
          'timestamp': FieldValue.serverTimestamp(),
        });

        setState(() {
          item.uploadState = 'success';
          _completedCount++;
        });

      } catch (e) {
        setState(() {
          item.uploadState = 'error';
          item.errorMessage = e.toString();
        });
      }
    }

    setState(() => _isUploading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Bulk Upload - ${widget.uploadType}', style: AppTextStyles.headingMedium),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 16),
            if (_items.isEmpty)
              Expanded(
                child: Center(
                  child: ElevatedButton.icon(
                    onPressed: _pickFiles,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Select PDF Files'),
                  ),
                ),
              )
            else ...[
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _isUploading ? null : _pickFiles,
                    icon: const Icon(Icons.add),
                    label: const Text('Add More Files'),
                  ),
                  const Spacer(),
                  Text('$_completedCount / ${_items.length} Completed', style: AppTextStyles.bodyMedium),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _isUploading ? null : _startUpload,
                    icon: _isUploading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.upload),
                    label: Text(_isUploading ? 'Uploading...' : 'Start Upload'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return Card(
                      child: ListTile(
                        leading: _buildStatusIcon(item.uploadState),
                        title: Text(item.file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          'Course: ${item.course.isEmpty ? '?' : item.course} | Sub: ${item.subject.isEmpty ? '?' : item.subject} | Status: ${item.status.toUpperCase()}\n${item.errorMessage}',
                          style: TextStyle(color: item.uploadState == 'error' ? Colors.red : Colors.grey[600], fontSize: 12),
                        ),
                        trailing: _isUploading ? null : IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() => _items.removeAt(index));
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(String state) {
    switch (state) {
      case 'waiting': return const Icon(Icons.schedule, color: Colors.grey);
      case 'uploading': return const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2));
      case 'success': return const Icon(Icons.check_circle, color: Colors.green);
      case 'duplicate': return const Icon(Icons.warning, color: Colors.orange);
      case 'error': return const Icon(Icons.error, color: Colors.red);
      default: return const Icon(Icons.help);
    }
  }
}
