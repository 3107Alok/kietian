import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import '../controllers/recognition_controller.dart';
import 'registration_screen.dart';
import 'attendance_screen.dart';
import '../services/export_service.dart';
import '../services/firebase_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              _buildSliverAppBar(context),
              SliverPadding(
                padding: const EdgeInsets.all(20.0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildStatCards(context),
                    const SizedBox(height: 32),
                    _buildSectionHeader('Actions'),
                    const SizedBox(height: 12),
                    _buildActionGrid(context),
                    const SizedBox(height: 32),
                    _buildSectionHeader('Recent Students'),
                    const SizedBox(height: 12),
                    _buildStudentList(context),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 80,
      backgroundColor: Colors.transparent,
      elevation: 0,
      floating: true,
      title: const Text(
        'DASHBOARD',
        style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 20),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: Colors.white70),
          onPressed: () => context.read<AuthController>().logout(),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: Colors.white38,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildStatCards(BuildContext context) {
    final recognition = context.watch<RecognitionController>();
    return Row(
      children: [
        _statCard('ENROLLED', '${recognition.students.length}', Icons.groups_rounded, const Color(0xFF4E4EBA)),
        const SizedBox(width: 16),
        _statCard('PRESENT', '0', Icons.check_circle_rounded, Colors.greenAccent),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 20),
            Text(value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _actionCard(
          context,
          'Register',
          Icons.person_add_rounded,
          const Color(0xFF4E4EBA),
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegistrationScreen())),
        ),
        _actionCard(
          context,
          'Attendance',
          Icons.linked_camera_rounded,
          Colors.greenAccent,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen())),
        ),
      ],
    );
  }

  Widget _actionCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentList(BuildContext context) {
    final students = context.watch<RecognitionController>().students;
    if (students.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Center(
          child: Text('No students registered yet', style: TextStyle(color: Colors.white24)),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: students.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final student = students[index];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(20),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF4E4EBA).withValues(alpha: 0.2),
              child: Text(student.name[0], style: const TextStyle(color: Color(0xFF4E4EBA), fontWeight: FontWeight.bold)),
            ),
            title: Text(student.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            subtitle: Text('Roll: ${student.rollNumber}', style: const TextStyle(color: Colors.white38)),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              onPressed: () => _showDeleteConfirmation(context, student.id, student.name),
            ),
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context, String id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('DELETE STUDENT', style: TextStyle(color: Colors.white, letterSpacing: 1.5)),
        content: Text('Are you sure you want to remove $name?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () {
              context.read<RecognitionController>().deleteStudent(id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$name removed successfully')),
              );
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
