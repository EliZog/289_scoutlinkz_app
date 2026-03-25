import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../main.dart'; // To access AppColors

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Mock Settings State
  bool _newAthleteProfiles = true;
  bool _messageReplies = true;
  bool _weeklyDigest = false;
  bool _profileStatusReminder = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(color: Colors.white, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            const Text(
              'Push Notifications',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Manage your notification preferences.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 32),
            _buildSwitchTile(
              title: 'New Athlete Profiles',
              subtitle: 'Get notified when a new athlete joins',
              value: _newAthleteProfiles,
              onChanged: (val) => setState(() => _newAthleteProfiles = val),
            ),
            const Divider(color: Colors.white12, height: 32),
            _buildSwitchTile(
              title: 'Message Replies',
              subtitle: 'When an athlete responds to your message',
              value: _messageReplies,
              onChanged: (val) => setState(() => _messageReplies = val),
            ),
            const Divider(color: Colors.white12, height: 32),
            _buildSwitchTile(
              title: 'Weekly Digest',
              subtitle: 'Summary of your scrolling activity',
              value: _weeklyDigest,
              onChanged: (val) => setState(() => _weeklyDigest = val),
            ),
            const Divider(color: Colors.white12, height: 32),
            _buildSwitchTile(
              title: 'Profile Status Reminder',
              subtitle: 'Remind you to update your athlete status labels',
              value: _profileStatusReminder,
              onChanged: (val) => setState(() => _profileStatusReminder = val),
            ),
            const SizedBox(height: 48),
            const Text(
              'Account Management',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildActionButton(
              title: 'Log Out',
              icon: Icons.logout,
              color: Colors.white,
              onTap: _logOut,
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              title: 'Delete Account',
              icon: Icons.delete_forever,
              color: Colors.red[400]!,
              onTap: _deleteAccount,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primary,
          activeTrackColor: AppColors.primary.withOpacity(0.5),
          inactiveThumbColor: Colors.grey[400],
          inactiveTrackColor: Colors.grey[800],
        ),
      ],
    );
  }

  Widget _buildActionButton({required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[800]!),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Text(title, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Future<void> _logOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        title: const Text('Delete Account', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete your account? This will permanently delete all your data and messages.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      )
    );

    if (confirm != true) return;

    try {
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

      final uid = user.uid;

      // 1. Delete all conversations involving this user
      final convosScout = await FirebaseFirestore.instance.collection('conversations').where('scoutUid', isEqualTo: uid).get();
      final convosAthlete = await FirebaseFirestore.instance.collection('conversations').where('athleteUid', isEqualTo: uid).get();
      
      final allConvoDocs = [...convosScout.docs, ...convosAthlete.docs];

      for (final doc in allConvoDocs) {
        // Delete all messages inside
        final msgs = await doc.reference.collection('messages').get();
        for (final msg in msgs.docs) {
          await msg.reference.delete();
        }
        // Delete conversation doc
        await doc.reference.delete();
      }

      // 2. Delete user profiles
      await FirebaseFirestore.instance.collection('athletes').doc(uid).delete();
      await FirebaseFirestore.instance.collection('scouts').doc(uid).delete();

      // 3. Delete Firebase Auth user
      await user.delete();

      if (!mounted) return;
      Navigator.pop(context); // Pop loading dialog
      Navigator.of(context).popUntil((route) => route.isFirst);

    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Pop loading dialog
      if (e.code == 'requires-recent-login') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log out and log back in to delete your account.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Pop loading dialog
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}
