import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import '../controllers/recognition_controller.dart';
import 'registration_screen.dart';
import 'attendance_screen.dart';
import 'attendance_report_screen.dart';
import 'student_list_screen.dart';
import '../services/export_service.dart';
import '../services/firebase_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Deeper navy
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(context),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 10),
                    _buildSectionHeader('Live Statistics', Icons.analytics_rounded),
                    const SizedBox(height: 16),
                    _buildStatCards(context),
                    const SizedBox(height: 32),
                    _buildSectionHeader('Smart Controls', Icons.bolt_rounded),
                    const SizedBox(height: 16),
                    _buildActionGrid(context),
                    const SizedBox(height: 48),
                    _buildInfoCard(context),
                    const SizedBox(height: 20),
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
      expandedHeight: 100,
      backgroundColor: Colors.transparent,
      elevation: 0,
      floating: true,
      pinned: true,
      centerTitle: false,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'KIETIAN',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
            ),
          ),
          const Text(
            'DASHBOARD',
            style: TextStyle(
              fontWeight: FontWeight.w900, 
              letterSpacing: 1, 
              fontSize: 24,
              color: Colors.white,
            ),
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white70, size: 20),
            onPressed: () => context.read<AuthController>().logout(),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF6366F1), size: 18),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        const Spacer(),
        Container(
          height: 1,
          width: 40,
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ],
    );
  }

  Widget _buildStatCards(BuildContext context) {
    final recognition = context.watch<RecognitionController>();
    return Row(
      children: [
        _statCard('ENROLLED', '${recognition.students.length}', context, onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentListScreen()));
        }),
        const SizedBox(width: 16),
        _statCard('PRESENT idag', '${recognition.todayAttendanceCount}', context, isSuccess: true),
      ],
    );
  }

  Widget _statCard(String label, String value, BuildContext context, {bool isSuccess = false, VoidCallback? onTap}) {
    final color = isSuccess ? const Color(0xFF10B981) : const Color(0xFF6366F1);
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(isSuccess ? Icons.verified_user_rounded : Icons.people_rounded, color: color, size: 20),
                ),
                const SizedBox(height: 20),
                Text(value, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(label.toUpperCase(), style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    if (onTap != null) ...[
                      const Spacer(),
                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 10),
                    ],
                  ],
                ),
              ],
            ),
          ),
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
      childAspectRatio: 1.1,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _actionCard(
          context,
          'Enroll New',
          Icons.person_add_alt_1_rounded,
          const Color(0xFF6366F1),
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegistrationScreen())),
        ),
        _actionCard(
          context,
          'Scanner',
          Icons.face_retouching_natural_rounded,
          const Color(0xFF10B981),
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen())),
        ),
        _actionCard(
          context,
          'Reports',
          Icons.bar_chart_rounded,
          const Color(0xFFF59E0B),
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceReportScreen())),
        ),
      ],
    );
  }

  Widget _actionCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [color, color.withValues(alpha: 0.5)],
                ).createShader(bounds),
                child: Icon(icon, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 12),
              Text(
                title, 
                style: const TextStyle(
                  color: Colors.white, 
                  fontWeight: FontWeight.w800, 
                  fontSize: 14,
                  letterSpacing: 0.5,
                )
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Container(
            height: 1,
            width: 100,
            color: Colors.white.withValues(alpha: 0.05),
          ),
          const SizedBox(height: 20),
          Text(
            'KIETIAN SMART ATTENDANCE',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.2), 
              fontSize: 10, 
              fontWeight: FontWeight.w900, 
              letterSpacing: 2
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'v2.6 PREMIUM EDITION',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.1), fontSize: 8, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
