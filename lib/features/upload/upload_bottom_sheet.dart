import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../models/note_model.dart';
import '../../models/question_paper_model.dart';
import '../../core/utils/pdf_classifier.dart';
import '../../core/utils/input_validator.dart';
import '../../core/config/app_config.dart';
import 'package:go_router/go_router.dart';

class UploadBottomSheet extends ConsumerStatefulWidget {
  const UploadBottomSheet({super.key});

  @override
  ConsumerState<UploadBottomSheet> createState() => _UploadBottomSheetState();
}

class _UploadBottomSheetState extends ConsumerState<UploadBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _subjectController = TextEditingController();
  final _yearController = TextEditingController(text: DateTime.now().year.toString());
  
  String _selectedCourse = 'BCA';
  String _selectedSemester = 'Semester 1';

  final List<String> _courses = [
    'BCA',
    'B.Sc CS',
    'MCA',
    'B.Tech',
    'MBA',
    'B.Com',
    'BA',
  ];

  List<String> get _semesters {
    int maxSem = 6;
    if (_selectedCourse == 'MCA' || _selectedCourse == 'MBA') {
      maxSem = 4;
    } else if (_selectedCourse == 'B.Tech') {
      maxSem = 8;
    } else {
      maxSem = 6;
    }
    return List.generate(maxSem, (i) => 'Semester ${i + 1}');
  }
  bool _isPaper = false;
  bool _isUploading = false;
  String _uploadStatusText = '';
  File? _selectedFile;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final sems = _semesters;
    setState(() {
      _selectedSemester = sems.isNotEmpty ? sems.first : '';
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _subjectController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      final fileName = result.files.single.name;
      final classification = PdfClassifier.classifyFromFilename(fileName);

      setState(() {
        _selectedFile = File(result.files.single.path!);
        
        // Auto-fill metadata if detected
        if (classification.type != null) {
          _isPaper = classification.type == 'Paper';
        }
        if (classification.course != null && ['BCA', 'BCS', 'MCA', 'MCS'].contains(classification.course)) {
          _selectedCourse = classification.course!;
        }
        if (classification.semester != null) {
          final validSems = _semesters;
          if (validSems.contains(classification.semester)) {
            _selectedSemester = classification.semester!;
          }
        }
        if (classification.title != null) {
          _titleController.text = classification.title!;
        }
        if (classification.subject != null) {
          _subjectController.text = classification.subject!;
        }
        if (classification.year != null && _isPaper) {
          _yearController.text = classification.year!;
        }
      });
      
      if (mounted && (classification.course != null || classification.title != null)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Auto-filled file details from filename!'),
            backgroundColor: AppColors.primary,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _handleUpload() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a PDF file to upload.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    
    setState(() {
        _isUploading = true;
        _uploadStatusText = 'Preparing upload...';
      });

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final storageService = ref.read(storageServiceProvider);
      final user = ref.read(authServiceProvider).currentUser;

      if (user == null) throw const PdfScanException('You must be logged in to upload.');

      // Client-side rate guard (server enforces hard limit)
      if (!InputValidator.checkClientRateLimit('upload_${user.uid}', AppConfig.clientUploadPerMinute)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Uploading too quickly. Please wait a moment.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        setState(() => _isUploading = false);
        return;
      }

      setState(() => _uploadStatusText = 'Validating PDF...');

      // 1. Secure upload: pre-flight + server scan + Cloudinary
      //    Hash comes from the server scan (authoritative)
      final (pdfUrl, fileHash) = await storageService.uploadPdfSecure(
        _selectedFile!,
        user.uid,
      );

      // 2. Check for duplicates using the server-verified hash
      setState(() => _uploadStatusText = 'Checking for duplicates...');
      final isDuplicate = await firestoreService.checkDuplicateFile(fileHash);
      if (isDuplicate) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This PDF has already been uploaded.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        setState(() => _isUploading = false);
        return;
      }

      // 3. Create Firestore Document
      final profile = await firestoreService.getUserProfile(user.uid);
      final String uploadStatus = profile.role == 'admin' ? 'approved' : 'pending';

      setState(() => _uploadStatusText = uploadStatus == 'approved'
          ? 'Saving document...'
          : 'Submitting for review...');

      final String docId = DateTime.now().millisecondsSinceEpoch.toString();

      // Sanitize metadata before writing to Firestore
      final cleanTitle = InputValidator.sanitizeSingleLine(_titleController.text);
      final cleanSubject = InputValidator.sanitizeSingleLine(_subjectController.text);
      final cleanDesc = InputValidator.sanitizeForDisplay(_descController.text);

      if (_isPaper) {
        await firestoreService.uploadQuestionPaper(
          QuestionPaperModel(
            paperId: docId,
            title: cleanTitle,
            course: _selectedCourse,
            semester: _selectedSemester,
            subject: cleanSubject,
            year: InputValidator.sanitizeSingleLine(_yearController.text),
            pdfUrl: pdfUrl,
            fileHash: fileHash,
            uploadedBy: user.uid,
            status: uploadStatus,
            collegeId: profile.collegeId,
            state: profile.state,
            district: profile.district,
          ),
        );
      } else {
        await firestoreService.uploadNote(
          NoteModel(
            noteId: docId,
            title: cleanTitle,
            description: cleanDesc,
            course: _selectedCourse,
            semester: _selectedSemester,
            subject: cleanSubject,
            pdfUrl: pdfUrl,
            fileHash: fileHash,
            uploadedBy: user.uid,
            status: uploadStatus,
            createdAt: DateTime.now(),
            collegeId: profile.collegeId,
            state: profile.state,
            district: profile.district,
          ),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Material uploaded successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context); // Close bottom sheet
        
        // Redirect to detail page if it's a note and approved
        if (!_isPaper && uploadStatus == 'approved') {
          context.push('/notes/$docId');
        }
      }
    } on UploadRateLimitException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } on PdfScanException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.reason),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Upload failed. Please check your connection and try again.'),
            backgroundColor: AppColors.error,
          ),
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
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Contribute Content',
                style: AppTextStyles.headingMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              // Segmented switch
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _isPaper = false),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: !_isPaper ? AppColors.surface : Colors.white,
                        side: BorderSide(color: !_isPaper ? AppColors.primary : AppColors.border),
                      ),
                      child: const Text('Notes'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _isPaper = true),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _isPaper ? AppColors.surface : Colors.white,
                        side: BorderSide(color: _isPaper ? AppColors.primary : AppColors.border),
                      ),
                      child: const Text('PYQ Paper'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                maxLength: AppConfig.maxTitleLength,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Title required';
                  final r = InputValidator.validateTitle(val);
                  return r.isValid ? null : r.error;
                },
              ),
              const SizedBox(height: 16),
              if (!_isPaper) ...[
                TextFormField(
                  controller: _descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _subjectController,
                decoration: const InputDecoration(labelText: 'Subject'),
                maxLength: AppConfig.maxSubjectLength,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Subject required';
                  final r = InputValidator.validateSubject(val);
                  return r.isValid ? null : r.error;
                },
              ),
              const SizedBox(height: 16),
              if (_isPaper) ...[
                TextFormField(
                  controller: _yearController,
                  decoration: const InputDecoration(labelText: 'Year (e.g., 2023)'),
                  keyboardType: TextInputType.number,
                  validator: (val) => val == null || val.isEmpty ? 'Year required' : null,
                ),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedCourse,
                      items: _courses
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedCourse = val!;
                          final sems = _semesters;
                          if (sems.isEmpty) {
                            _selectedSemester = '';
                          } else if (!sems.contains(_selectedSemester)) {
                            _selectedSemester = sems.first;
                          }
                        });
                      },
                      decoration: const InputDecoration(labelText: 'Course'),
                    ),
                  ),
                  if (_semesters.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedSemester.isEmpty ? _semesters.first : _selectedSemester,
                        items: _semesters
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (val) => setState(() => _selectedSemester = val!),
                        decoration: const InputDecoration(labelText: 'Semester'),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 24),
              
              // File Picker Section
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.background,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf, color: AppColors.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedFile != null
                            ? p.basename(_selectedFile!.path)
                            : 'No PDF selected',
                        style: AppTextStyles.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: _isUploading ? null : _pickFile,
                      child: Text(_selectedFile == null ? 'Browse' : 'Change'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              if (_isUploading) ...[
                Text(_uploadStatusText, textAlign: TextAlign.center, style: AppTextStyles.bodyMedium),
                const SizedBox(height: 8),
                const LinearProgressIndicator(),
              ] else ...[
                ElevatedButton.icon(
                  onPressed: _handleUpload,
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text('Upload Content'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}


