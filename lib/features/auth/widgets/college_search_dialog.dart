import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/college_service.dart';
import '../../../core/constants/app_text_styles.dart';

Future<CollegeData?> showCollegeSearchBottomSheet(
  BuildContext context,
  WidgetRef ref,
  String? state,
  String? district,
) {
  return showModalBottomSheet<CollegeData>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          child: _CollegeSearchContent(state: state, district: district, ref: ref),
        ),
      );
    },
  );
}

class _CollegeSearchContent extends StatefulWidget {
  final String? state;
  final String? district;
  final WidgetRef ref;

  const _CollegeSearchContent({required this.state, required this.district, required this.ref});

  @override
  State<_CollegeSearchContent> createState() => _CollegeSearchContentState();
}

class _CollegeSearchContentState extends State<_CollegeSearchContent> {
  final TextEditingController _searchController = TextEditingController();
  List<CollegeData> _allColleges = [];
  List<CollegeData> _filteredColleges = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadColleges();
  }

  Future<void> _loadColleges() async {
    final collegeService = widget.ref.read(collegeServiceProvider);
    final colleges = await collegeService.searchColleges(
      query: '',
      state: widget.state,
      district: widget.district,
      limit: 1000,
    );
    if (mounted) {
      setState(() {
        _allColleges = colleges;
        _filteredColleges = colleges;
        _isLoading = false;
      });
    }
  }

  void _filterColleges(String query) {
    if (query.isEmpty) {
      setState(() => _filteredColleges = _allColleges);
      return;
    }
    final lowerQuery = query.toLowerCase();
    setState(() {
      _filteredColleges = _allColleges
          .where((c) => c.college.toLowerCase().contains(lowerQuery))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        Text('Select College', style: AppTextStyles.headingMedium.copyWith(fontSize: 20)),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            onChanged: _filterColleges,
            decoration: InputDecoration(
              hintText: 'Search college name...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredColleges.isEmpty
                  ? Center(child: Text('No colleges found for this district.', style: AppTextStyles.bodyMedium))
                  : ListView.separated(
                      itemCount: _filteredColleges.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final college = _filteredColleges[index];
                        return ListTile(
                          title: Text(
                            college.college,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          subtitle: Text(
                            '${college.district}, ${college.state}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onTap: () => Navigator.of(context).pop(college),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
