import 'package:flutter/material.dart';

import '../../models/student_course_models.dart';

class StudentCatalogTab extends StatelessWidget {
  const StudentCatalogTab({
    super.key,
    required this.data,
    required this.onRefresh,
  });

  final StudentCourseData data;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (data.selectedSemesterId != null)
            _SelectedSemesterCard(data: data),
          if (data.selectedSemesterId != null) const SizedBox(height: 12),
          if (data.items.isEmpty)
            _EmptyState(message: data.message)
          else
            ...data.items.map((item) => _CourseCard(item: item)),
        ],
      ),
    );
  }
}

class _SelectedSemesterCard extends StatelessWidget {
  const _SelectedSemesterCard({required this.data});

  final StudentCourseData data;

  @override
  Widget build(BuildContext context) {
    final selected = data.semesters.where(
      (s) => s.id == data.selectedSemesterId,
    );
    final semester = selected.isEmpty ? null : selected.first;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF263244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hoc ky dang xem',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            semester?.name ?? '--',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            '${semester?.startDate ?? '--'} den ${semester?.endDate ?? '--'}',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.item});

  final StudentCourseItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF263244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _pill('${item.credits} Tín chỉ'),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.code == null || item.code!.isEmpty
                ? item.semesterName
                : '${item.code} • ${item.semesterName}',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _pill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF263244)),
      ),
      child: Text(message),
    );
  }
}
