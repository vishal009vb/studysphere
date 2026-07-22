import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../courses/models/course_model.dart';
import '../../../services/storage_service.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class CourseFormSheet extends ConsumerStatefulWidget {
  final CourseModel? existingCourse;

  const CourseFormSheet({super.key, this.existingCourse});

  @override
  ConsumerState<CourseFormSheet> createState() => _CourseFormSheetState();
}

class _CourseFormSheetState extends ConsumerState<CourseFormSheet> {
  final _formKey = GlobalKey<FormState>();

  // Controllers for text fields
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _youtubeUrlController;
  late TextEditingController _thumbnailUrlController;
  late TextEditingController _channelNameController;
  late TextEditingController _instructorNameController;
  late TextEditingController _durationController;
  late TextEditingController _totalVideosController;
  late TextEditingController _tagsController;

  // Dropdowns / Toggles
  String _category = 'Programming';
  String _subCategory = '';
  String _level = 'Beginner';
  String _language = 'English';
  bool _certificateAvailable = false;
  bool _isPaid = false;
  bool _isFeatured = false;
  bool _isRecommended = false;
  bool _isVisible = true;

  bool _isUploadingImage = false;
  bool _isSaving = false;

  final List<String> _categories = ['Programming', 'Web Dev', 'App Dev', 'DSA', 'Core Subjects', 'Other'];
  final List<String> _levels = ['Beginner', 'Intermediate', 'Advanced', 'All Levels'];
  final List<String> _languages = ['English', 'Hindi', 'Marathi', 'Mixed'];

  @override
  void initState() {
    super.initState();
    final c = widget.existingCourse;
    _titleController = TextEditingController(text: c?.title ?? '');
    _descriptionController = TextEditingController(text: c?.description ?? '');
    _youtubeUrlController = TextEditingController(text: c?.youtubePlaylistUrl ?? '');
    _thumbnailUrlController = TextEditingController(text: c?.thumbnailUrl ?? '');
    _channelNameController = TextEditingController(text: c?.channelName ?? '');
    _instructorNameController = TextEditingController(text: c?.instructorName ?? '');
    _durationController = TextEditingController(text: c?.duration ?? 'Full Course');
    _totalVideosController = TextEditingController(text: c?.totalVideos.toString() ?? '0');
    _tagsController = TextEditingController(text: c?.tags.join(', ') ?? '');

    if (c != null) {
      if (_categories.contains(c.category)) _category = c.category;
      _subCategory = c.subCategory;
      if (_levels.contains(c.level)) _level = c.level;
      if (_languages.contains(c.language)) _language = c.language;
      _certificateAvailable = c.certificateAvailable;
      _isPaid = c.isPaid;
      _isFeatured = c.isFeatured;
      _isRecommended = c.isRecommended;
      _isVisible = c.isVisible;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _youtubeUrlController.dispose();
    _thumbnailUrlController.dispose();
    _channelNameController.dispose();
    _instructorNameController.dispose();
    _durationController.dispose();
    _totalVideosController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        withData: true, // required for web bytes
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;
        if (bytes == null) return;

        setState(() => _isUploadingImage = true);

        final user = FirebaseAuth.instance.currentUser;
        final storage = ref.read(storageServiceProvider);
        
        final url = await storage.uploadImageBytes(
          bytes,
          file.name,
          user?.uid ?? 'admin',
        );

        setState(() {
          _thumbnailUrlController.text = url;
          _isUploadingImage = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image uploaded successfully!'), backgroundColor: AppColors.success),
          );
        }
      }
    } catch (e) {
      setState(() => _isUploadingImage = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  // Helper to extract proper video/playlist ID for the module
  String _getEmbedUrl(String url) {
    if (url.isEmpty) return '';
    final trimmed = url.trim();
    if (trimmed.contains('list=')) {
      try {
        final uri = Uri.parse(trimmed);
        if (uri.queryParameters.containsKey('list')) {
          return uri.queryParameters['list']!;
        }
      } catch (_) {}
    }
    if (trimmed.contains('watch?v=')) {
      try {
        final uri = Uri.parse(trimmed);
        if (uri.queryParameters.containsKey('v')) {
          return uri.queryParameters['v']!;
        }
      } catch (_) {}
    }
    if (trimmed.contains('youtu.be/')) {
      return trimmed.split('youtu.be/').last.split('?').first;
    }
    return trimmed;
  }

  Future<void> _saveCourse() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final db = FirebaseFirestore.instance;
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid ?? 'admin';

      final docRef = widget.existingCourse != null
          ? db.collection('courses').doc(widget.existingCourse!.id)
          : db.collection('courses').doc();

      final ytUrl = _youtubeUrlController.text.trim();
      List<CourseModule> generatedModules = [];

      // If it's a playlist, fetch all videos using YoutubeExplode
      if (ytUrl.contains('playlist?list=')) {
        final yt = YoutubeExplode();
        final listId = ytUrl.split('playlist?list=')[1].split('&').first;
        try {
          var videoStream = yt.playlists.getVideos(listId);
          int index = 1;
          await for (var video in videoStream) {
            generatedModules.add(CourseModule(
              id: '${docRef.id}_vid_$index',
              title: video.title,
              youtubeVideoId: video.id.value,
              duration: video.duration?.inMinutes.toString() ?? '0',
            ));
            index++;
          }
        } catch (e) {
          debugPrint('Error fetching playlist: $e');
        } finally {
          yt.close();
        }
      }

      // Fallback: If not a playlist or fetching failed, use the single URL
      if (generatedModules.isEmpty) {
        generatedModules.add(CourseModule(
          id: '${docRef.id}_module',
          title: 'Full Course / Playlist Video',
          youtubeVideoId: _getEmbedUrl(ytUrl),
          duration: _durationController.text.trim(),
        ));
      }

      final tagsList = _tagsController.text
          .split(',')
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .toList();

      final course = CourseModel(
        id: docRef.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _category,
        subCategory: _subCategory,
        level: _level,
        language: _language,
        channelName: _channelNameController.text.trim(),
        instructorName: _instructorNameController.text.trim(),
        thumbnailUrl: _thumbnailUrlController.text.trim(),
        youtubePlaylistUrl: ytUrl,
        duration: _durationController.text.trim(),
        totalVideos: generatedModules.length, // Automatically set total videos
        certificateAvailable: _certificateAvailable,
        isPaid: _isPaid,
        isFeatured: _isFeatured,
        isRecommended: _isRecommended,
        isVisible: _isVisible,
        isDeleted: widget.existingCourse?.isDeleted ?? false, // Preserve soft delete state
        order: widget.existingCourse?.order ?? DateTime.now().millisecondsSinceEpoch,
        tags: tagsList,
        createdAt: widget.existingCourse?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: widget.existingCourse?.createdBy ?? uid,
        updatedBy: uid,
        modules: generatedModules,
      );

      await docRef.set(course.toMap());

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingCourse == null ? 'Course added successfully!' : 'Course updated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.existingCourse == null ? 'Add New Course' : 'Edit Course',
                    style: AppTextStyles.headingMedium.copyWith(fontSize: 20),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            
            // Form
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text('Basic Info', style: AppTextStyles.headingSmall.copyWith(color: AppColors.primary)),
                    const SizedBox(height: 16),
                    _buildTextField(_titleController, 'Course Title *', 'e.g., Complete Flutter Bootcamp'),
                    const SizedBox(height: 16),
                    _buildTextField(_descriptionController, 'Description *', 'Course overview...', maxLines: 3),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildDropdown('Category *', _categories, _category, (v) => setState(() => _category = v!))),
                        const SizedBox(width: 16),
                        Expanded(child: _buildDropdown('Difficulty', _levels, _level, (v) => setState(() => _level = v!))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildDropdown('Language', _languages, _language, (v) => setState(() => _language = v!)),
                    
                    const SizedBox(height: 32),
                    Text('Instructor & Channel', style: AppTextStyles.headingSmall.copyWith(color: AppColors.primary)),
                    const SizedBox(height: 16),
                    _buildTextField(_channelNameController, 'Channel Name *', 'e.g., CodeWithHarry'),
                    const SizedBox(height: 16),
                    _buildTextField(_instructorNameController, 'Instructor Name (Optional)', 'e.g., Harry'),

                    const SizedBox(height: 32),
                    Text('Media', style: AppTextStyles.headingSmall.copyWith(color: AppColors.primary)),
                    const SizedBox(height: 16),
                    _buildTextField(_youtubeUrlController, 'YouTube Playlist/Video URL *', 'https://youtube.com/playlist?...'),
                    const SizedBox(height: 16),
                    
                    // Thumbnail Upload
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: _buildTextField(_thumbnailUrlController, 'Thumbnail URL', 'Auto-filled after upload'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _isUploadingImage ? null : _pickAndUploadImage,
                          icon: _isUploadingImage 
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.upload_file),
                          label: const Text('Upload'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            backgroundColor: AppColors.secondary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),
                    Text('Details', style: AppTextStyles.headingSmall.copyWith(color: AppColors.primary)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildTextField(_durationController, 'Estimated Duration', 'e.g., 10+ Hours')),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField(_totalVideosController, 'Total Videos', 'e.g., 50', keyboardType: TextInputType.number)),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                    Text('StudySphere Settings', style: AppTextStyles.headingSmall.copyWith(color: AppColors.primary)),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Is Featured ⭐'),
                      value: _isFeatured,
                      onChanged: (v) => setState(() => _isFeatured = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      title: const Text('Is Recommended 🎯'),
                      value: _isRecommended,
                      onChanged: (v) => setState(() => _isRecommended = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      title: const Text('Is Visible 👁️'),
                      subtitle: const Text('Hide from users without deleting'),
                      value: _isVisible,
                      onChanged: (v) => setState(() => _isVisible = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(_tagsController, 'Tags (Comma separated)', 'e.g., flutter, dart, mobile'),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            
            // Footer (Save Button)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveCourse,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(widget.existingCourse == null ? 'Save Course' : 'Update Course', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, String hint, {int maxLines = 1, TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
        filled: true,
        fillColor: AppColors.surfaceLowest,
      ),
      validator: (value) {
        if (label.contains('*') && (value == null || value.trim().isEmpty)) {
          return 'This field is required';
        }
        return null;
      },
    );
  }

  Widget _buildDropdown(String label, List<String> items, String value, void Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        filled: true,
        fillColor: AppColors.surfaceLowest,
      ),
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
      onChanged: onChanged,
    );
  }
}
