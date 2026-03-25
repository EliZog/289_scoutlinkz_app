import 'package:flutter/material.dart';
import 'package:line_icons/line_icons.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../main.dart'; // To access AppColors
import 'profile_screen.dart';
import 'messages_screen.dart';
import 'discover_screen.dart';

class MainScreen extends StatefulWidget {
  final UserRole initialRole;

  const MainScreen({super.key, this.initialRole = UserRole.unauthenticated});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 1; // Default index to Discover

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0: // Messages
        return MessagesScreen(role: widget.initialRole);
      case 1: // Discover
        return DiscoverScreen(role: widget.initialRole);
      case 2: // Profile Tab
        return ProfileScreen(
          role: widget.initialRole == UserRole.recruiter ? UserRole.recruiter : UserRole.athleteSelf,
          onNavigateToMessages: () => setState(() => _currentIndex = 0),
        );
      default:
        return const Center(child: Text("Not Implemented"));
    }
  }

  // ---- BOTTOM NAVIGATION ----
  Widget _buildBottomNav() {
    return Container(
      height: 85, // Need to make room for FAB overlapping layout in simple manner
      decoration: BoxDecoration(
        color: AppColors.backgroundDark.withValues(alpha: 0.9),
        border: const Border(top: BorderSide(color: Colors.white10)),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ColorFilter.mode(AppColors.backgroundDark.withValues(alpha: 0.8), BlendMode.dstOut),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildNavItem(LineIcons.facebookMessenger, 'Messages', 0),
                _buildDiscoverButton(),
                _buildProfileNav(2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    bool isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 36,
            child: Center(
              child: Icon(icon, color: isActive ? AppColors.primary : Colors.grey[500]),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: isActive ? AppColors.primary : Colors.grey[500], fontSize: 10, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildDiscoverButton() {
    bool isActive = _currentIndex == 1;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = 1),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 36, height: 36, // Slightly smaller since it's inline now
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : AppColors.cardDark,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.backgroundDark, width: 2),
              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: isActive ? 0.4 : 0.0), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Icon(LineIcons.compass, size: 20, color: isActive ? Colors.white : Colors.grey[500]),
          ),
          const SizedBox(height: 4),
          Text('Discover', style: TextStyle(color: isActive ? Colors.white : Colors.grey[500], fontSize: 10, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildProfileNav(int index) {
    bool isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 36,
            child: Center(
              child: Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  shape: BoxShape.circle,
                  border: Border.all(color: isActive ? Colors.white : Colors.grey[600]!),
                ),
                child: Center(
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseAuth.instance.currentUser == null ? null : FirebaseFirestore.instance.collection(widget.initialRole == UserRole.recruiter ? 'scouts' : 'athletes').doc(FirebaseAuth.instance.currentUser!.uid).snapshots(),
                    builder: (context, snapshot) {
                       String initial = 'U';
                       if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
                         final data = snapshot.data!.data() as Map<String, dynamic>?;
                         if (data != null) {
                           final name = data['name'] ?? data['displayName'] ?? 'User';
                           if (name.isNotEmpty) initial = name[0].toUpperCase();
                         }
                       }
                       return Text(initial, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold));
                    }
                  )
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text('Profile', style: TextStyle(color: isActive ? Colors.white : Colors.grey[500], fontSize: 10, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
