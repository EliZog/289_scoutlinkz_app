import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../main.dart'; // To access AppColors
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

enum UserRole { unauthenticated, athleteSelf, athleteOther, recruiter, scoutSelf }

class ProfileScreen extends StatefulWidget {
  final UserRole role; // Injected from MainScreen
  final VoidCallback onNavigateToMessages;
  final String? athleteUid;

  const ProfileScreen({super.key, required this.role, required this.onNavigateToMessages, this.athleteUid});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isFollowing = false;
  int _selectedRecruiterStatus = 0; // 0: Interested, 1: Under Review, ...

  // Editable Profile State Data
  String _fullName = 'Devin Smith';
  String _positionStr = 'Goalkeeper • Class of 2026';
  String _aboutText = 'Explosive shot-stopper with strong distribution. Comfortable playing out of the back.';
  String _tagsText = 'Soccer, Goalkeeper, GPA 3.7, Grad 2026';
  String _gpa = '';
  String _height = '';
  String _weight = '';
  List<dynamic> _highlightsList = [
    {'title': 'Top play', 'videoId': 'mock_id'},
    {'title': 'Great save', 'videoId': 'mock_id'},
  ];
  List<dynamic> _statsList = [];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  void _loadProfileData() {
    final targetUid = widget.athleteUid ?? FirebaseAuth.instance.currentUser?.uid;
    if (targetUid != null) {
      if (widget.role == UserRole.scoutSelf) {
        FirebaseFirestore.instance.collection('scouts').doc(targetUid).snapshots().listen((doc) {
          if (doc.exists && mounted) {
            final data = doc.data()!;
            setState(() {
              _fullName = data['displayName'] ?? 'Recruiter';
              _positionStr = 'Recruiter • ${data['organization'] ?? 'Independent'}';
              _aboutText = 'Scout / Recruiter Profile';
              _tagsText = 'Scout';
            });
          }
        });
        return;
      }
      FirebaseFirestore.instance.collection('athletes').doc(targetUid).snapshots().listen((doc) {
        if (doc.exists && mounted) {
          final data = doc.data()!;
          setState(() {
            _fullName = data['name'] ?? _fullName;
            _aboutText = data['bio'] ?? _aboutText;
            String sport = data['sport'] ?? 'Soccer';
            String pos = data['position'] ?? 'Goalkeeper';
            String year = (data['gradYear'] ?? 2026).toString();
            String gpa = data['gpa'] ?? '3.7';
            _positionStr = '$pos • Class of $year';
            _tagsText = '$sport, $pos, GPA $gpa, Grad $year';
            _height = data['height'] ?? '';
            _weight = data['weight'] ?? '';
            _gpa = data['gpa'] ?? '';
            
            if (data['highlights'] != null) {
              _highlightsList = data['highlights'];
            }
            if (data['stats'] != null) {
              _statsList = data['stats'];
            }
          });
        }
      });
    }
  }

  Future<void> _navigateToEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(
          initialName: _fullName,
          initialAbout: _aboutText,
          initialHeight: _height,
          initialWeight: _weight,
          initialGpa: _gpa,
          initialHighlights: _highlightsList.map((h) => (h['videoId'] ?? '').toString()).toList(),
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final newHighlights = (result['highlights'] as List).map((url) => {'title': 'Highlight', 'videoId': url.toString()}).toList();
        
        // Critical Fix: Save to Firestore
        await FirebaseFirestore.instance.collection('athletes').doc(user.uid).set({
          'name': result['name'],
          'bio': result['bio'],
          'height': result['height'],
          'weight': result['weight'],
          'gpa': result['gpa'],
          'highlights': newHighlights,
        }, SetOptions(merge: true));
        
        // Local State Update
        setState(() {
          _fullName = result['name'] as String;
          _aboutText = result['bio'] as String;
          _height = result['height'] as String;
          _weight = result['weight'] as String;
          _gpa = result['gpa'] as String;
          _highlightsList = newHighlights;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 120), // Leave space for bottom nav
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  if (widget.role != UserRole.scoutSelf) ...[
                    const SizedBox(height: 24),
                    _buildStatsRow(),
                  ],
                  const SizedBox(height: 24),
                  
                  // Role-specific sections
                  if (widget.role == UserRole.athleteSelf) ...[
                    _buildRecruiterInterestBanner(),
                    const SizedBox(height: 32),
                    _buildAboutSection(isSelf: true),
                    const SizedBox(height: 32),
                    _buildHighlightsSelf(),
                    const SizedBox(height: 32),
                    _buildActionButtonsSelf(),
                  ] else if (widget.role == UserRole.athleteOther) ...[
                    _buildActionButtonsOther(),
                    const SizedBox(height: 32),
                    _buildAboutSection(isSelf: false),
                    const SizedBox(height: 32),
                    _buildHighlightsOther(),
                  ] else if (widget.role == UserRole.recruiter) ...[
                    _buildStatusPills(),
                    const SizedBox(height: 20),
                    _buildRecruiterSummary(),
                    const SizedBox(height: 20),
                    _buildPrivateScoutNotesInner(), // Specifically formatted for the card layout
                    const SizedBox(height: 20),
                    _buildActionButtonsRecruiter(),
                    const SizedBox(height: 32),
                    _buildHighlightsOther(), // Reusing the vertical 16:9 list from Athlete view
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- 1. APP BAR ----
  PreferredSizeWidget _buildAppBar() {
    switch (widget.role) {
      case UserRole.athleteSelf:
        return AppBar(
          backgroundColor: AppColors.backgroundLight.withOpacity(0.0), // Need blur theoretically, simplified here
          surfaceTintColor: Colors.transparent,
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ColorFilter.mode(AppColors.backgroundDark.withOpacity(0.8), BlendMode.srcOver),
              child: Container(decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white12)))),
            ),
          ),
          title: const Text('Dashboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
          actions: [
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(icon: const Icon(Icons.notifications_none, color: Colors.grey), onPressed: () {}),
                Positioned(
                  top: 12, right: 12,
                  child: Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: AppColors.backgroundDark, width: 1.5)),
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: Colors.grey),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
              },
            ),
            const SizedBox(width: 8),
          ],
        );
      case UserRole.athleteOther:
        return AppBar(
          backgroundColor: AppColors.backgroundLight.withOpacity(0.0),
          surfaceTintColor: Colors.transparent,
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ColorFilter.mode(AppColors.backgroundDark.withOpacity(0.8), BlendMode.srcOver),
              child: Container(decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white12)))),
            ),
          ),
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.grey, size: 20), onPressed: () => Navigator.pop(context)),
          title: const Text('Athlete Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
          centerTitle: false,
          actions: [
            IconButton(icon: const Icon(Icons.more_horiz, color: Colors.grey), onPressed: () {}),
            const SizedBox(width: 8),
          ],
        );
      case UserRole.recruiter:
        return AppBar(
          backgroundColor: AppColors.backgroundLight.withOpacity(0.0),
          surfaceTintColor: Colors.transparent,
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ColorFilter.mode(AppColors.backgroundDark.withOpacity(0.8), BlendMode.srcOver),
              child: Container(decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white12)))),
            ),
          ),
          leading: Navigator.canPop(context) 
            ? IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.grey, size: 20), onPressed: () => Navigator.pop(context))
            : Padding(
                padding: const EdgeInsets.only(left: 16.0, top: 12, bottom: 12),
                child: Container(
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.travel_explore, color: Colors.white, size: 18),
                ),
              ),
          title: const Text('Recruiter View', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic, letterSpacing: -0.5)),
          actions: [
            IconButton(icon: const Icon(Icons.star, color: Colors.amber), onPressed: () {}),
            IconButton(icon: const Icon(Icons.more_horiz, color: Colors.grey), onPressed: () {}),
            const SizedBox(width: 8),
          ],
        );
      case UserRole.scoutSelf:
        return AppBar(
          backgroundColor: AppColors.backgroundLight.withOpacity(0.0),
          surfaceTintColor: Colors.transparent,
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ColorFilter.mode(AppColors.backgroundDark.withOpacity(0.8), BlendMode.srcOver),
              child: Container(decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white12)))),
            ),
          ),
          title: const Text('Scout Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: Colors.grey),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
              },
            ),
            const SizedBox(width: 8),
          ],
        );
      default:
        return AppBar(backgroundColor: Colors.transparent, elevation: 0);
    }
  }

  // ---- 2. HEADER ----
  Widget _buildHeader() {
    String initial = _fullName.isNotEmpty ? _fullName[0].toUpperCase() : 'U';

    if (widget.role == UserRole.recruiter || widget.role == UserRole.scoutSelf) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: 100, width: 100,
            child: Stack(
              children: [
                Container(
                  width: 96, height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [AppColors.primary, Colors.purple, Colors.pink]),
                    boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.3), blurRadius: 10, spreadRadius: 2)],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: Container(
                      decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.cardDark, border: Border.all(color: AppColors.backgroundDark, width: 2)),
                      child: Center(child: Text(initial, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white))),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 4, right: 4,
                  child: Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: AppColors.backgroundDark, width: 4)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(_fullName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                    const SizedBox(width: 8),
                    Icon(Icons.verified, color: Colors.blue[400], size: 18),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(4)),
                      child: const Text('GOALKEEPER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(4)),
                      child: const Text('CLASS OF 2026', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
                    ),
                  ],
                ),
              ],
            ),
          )
        ],
      );
    }
    
    // Self or Other Athlete Header
    return Row(
      children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [AppColors.primary, AppColors.accentPurple], begin: Alignment.topRight, end: Alignment.bottomLeft),
            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 10, spreadRadius: 2)],
          ),
          child: Padding(
            padding: const EdgeInsets.all(2.0),
            child: Container(
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.cardDark, border: Border.all(color: AppColors.backgroundDark, width: 2)),
              child: Center(child: Text(initial, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white))),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_fullName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.sports_soccer, size: 16, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(_positionStr, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[400])),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ---- 3. STATS ----
  Widget _buildStatsRow() {
    if (_statsList.isEmpty) {
      // Mock defaults
      bool isRecruiter = widget.role == UserRole.recruiter;
      return Row(
        children: [
          Expanded(child: _buildStatCard('68', 'SAVES')),
          const SizedBox(width: 12),
          Expanded(child: _buildStatCard(isRecruiter ? '18' : '9', isRecruiter ? 'GAMES' : 'CLEAN SHEETS')),
          const SizedBox(width: 12),
          Expanded(child: _buildStatCard(isRecruiter ? '3.7' : '1.2k', isRecruiter ? 'GPA' : 'FOLLOWERS')),
        ],
      );
    }
    
    return Row(
      children: _statsList.take(3).map((statObj) {
        final label = statObj['label'] ?? '';
        final value = statObj['value'] ?? '';
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: statObj == _statsList.last ? 0 : 12.0),
            child: _buildStatCard(value, label.toUpperCase()),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatCard(String value, String label) {
    bool isRecruiter = widget.role == UserRole.recruiter;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isRecruiter ? Colors.transparent : AppColors.cardLight.withOpacity(0.05), // Recruiter has no bg on cards in design
        borderRadius: BorderRadius.circular(12),
        border: isRecruiter ? null : Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: isRecruiter ? 14 : 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[400], letterSpacing: 0.5)),
        ],
      ),
    );
  }

  // ---- 4. ATHLETE (SELF) SPECIFIC ----
  Widget _buildRecruiterInterestBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF312E81), Color(0xFF0F172A), Color(0xFF0F172A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
        boxShadow: [BoxShadow(color: const Color(0xFF312E81).withOpacity(0.2), blurRadius: 15)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.analytics_outlined, color: AppColors.accentPurple, size: 20)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.withOpacity(0.3))),
                child: Row(
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    const Text('Active', style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 16),
          Text('Recruiter Interest', style: TextStyle(color: Colors.grey[300], fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseAuth.instance.currentUser == null ? null : FirebaseFirestore.instance.collection('conversations').where('athleteUid', isEqualTo: FirebaseAuth.instance.currentUser!.uid).snapshots(),
            builder: (context, snapshot) {
              int count = 0;
              if (snapshot.hasData) count = snapshot.data!.docs.length;
              return Text('$count Recruiters contacted you', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold));
            }
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: widget.onNavigateToMessages,
            child: Container(
              width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('View Messages', style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, color: Colors.black, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightsSelf() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Featured Highlights', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            GestureDetector(
              onTap: _highlightsList.isEmpty ? null : _showFullPortfolio,
              child: Row(
                children: [
                  Text('Full Portfolio', style: TextStyle(color: _highlightsList.isEmpty ? Colors.grey[600] : AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                  Icon(Icons.chevron_right, color: _highlightsList.isEmpty ? Colors.grey[600] : AppColors.primary, size: 16),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: _highlightsList.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final h = _highlightsList[index];
              return HighlightVideoPlayer(
                videoUrl: h['videoId'] ?? '',
                title: h['title'] ?? 'Highlight ${index + 1}',
                subtitle: 'Just updated',
                isHorizontal: true,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtonsSelf() {
    return Row(
      children: [
        Expanded(child: _buildButton('Edit Profile', Icons.edit, false, onTap: _navigateToEditProfile)),
        const SizedBox(width: 12),
        Expanded(child: _buildButton('Share Profile', Icons.ios_share, true)),
      ],
    );
  }

  // ---- 5. ATHLETE (OTHER) SPECIFIC ----
  Widget _buildActionButtonsOther() {
    return Row(
      children: [
        Expanded(
          child: _buildButton(
            _isFollowing ? 'Following' : 'Follow', 
            _isFollowing ? Icons.person : Icons.person_add, 
            !_isFollowing,
            onTap: () {
              setState(() {
                _isFollowing = !_isFollowing;
              });
            }
          ),
        ),
        if (widget.role != UserRole.athleteOther) ...[
          const SizedBox(width: 12),
          Expanded(child: _buildButton('Message', Icons.message, false, onTap: widget.onNavigateToMessages)),
        ],
      ],
    );
  }

  Widget _buildHighlightsOther() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Featured Highlights', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            GestureDetector(
              onTap: _highlightsList.isEmpty ? null : _showFullPortfolio,
              child: Row(
                children: [
                  Text('Full Portfolio', style: TextStyle(color: _highlightsList.isEmpty ? Colors.grey[600] : AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                  Icon(Icons.chevron_right, color: _highlightsList.isEmpty ? Colors.grey[600] : AppColors.primary, size: 16),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ..._highlightsList.map((h) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: HighlightVideoPlayer(
            videoUrl: h['videoId'] ?? '',
            title: h['title'] ?? 'Featured Match',
            subtitle: '10k views',
            isHorizontal: false,
          ),
        )).toList(),
      ],
    );
  }

  // ---- 6. RECRUITER SPECIFIC ----
  // ---- 6. RECRUITER SPECIFIC ----
  Widget _buildStatusPills() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildPill('Interested', Icons.check_circle, AppColors.statusInterested, _selectedRecruiterStatus == 0, () => setState(() => _selectedRecruiterStatus = 0)),
          const SizedBox(width: 8),
          _buildPill('Contacted', null, AppColors.statusContacted, _selectedRecruiterStatus == 1, () => setState(() => _selectedRecruiterStatus = 1)),
          const SizedBox(width: 8),
          _buildPill('Interview', null, AppColors.statusInterview, _selectedRecruiterStatus == 2, () => setState(() => _selectedRecruiterStatus = 2)),
          const SizedBox(width: 8),
          _buildPill('Pass', null, AppColors.statusPassed, _selectedRecruiterStatus == 3, () => setState(() => _selectedRecruiterStatus = 3)),
        ],
      ),
    );
  }

  Widget _buildPill(String label, IconData? icon, Color color, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isActive ? color : Colors.grey[800]!, width: 2),
      ),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 6)],
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    ));
  }

  Widget _buildRecruiterSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[800]!),
        gradient: const LinearGradient(colors: [AppColors.cardDark, Color(0xFF0F172A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0, right: 0,
            child: Column(
              children: [
                const Text('SCOUT SCORE', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                const SizedBox(height: 4),
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withOpacity(0.1), border: Border.all(color: AppColors.primary, width: 4)),
                  child: const Center(child: Text('A+', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900))),
                )
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.analytics, color: AppColors.primary, size: 16),
                  SizedBox(width: 8),
                  Text('RECRUITER SUMMARY', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Height', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        RichText(text: const TextSpan(children: [TextSpan(text: "6'3\"", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)), TextSpan(text: " (191cm)", style: TextStyle(fontSize: 12, color: Colors.grey))])),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Weight', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        RichText(text: const TextSpan(children: [TextSpan(text: "185 lbs", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)), TextSpan(text: " (84kg)", style: TextStyle(fontSize: 12, color: Colors.grey))])),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Recruiter Interest', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        Row(
                          children: [
                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            const Text('High Demand', style: TextStyle(color: Colors.orange, fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        )
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Active Scouts', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        const Text('12 Watching', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white12),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _showScoutsBottomSheet,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: 60, height: 24,
                      child: Stack(
                        children: [
                          Positioned(left: 0, child: Container(width: 24, height: 24, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey[700], border: Border.all(color: AppColors.cardDark, width: 2)), child: const Center(child: Text('U1', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold))))),
                          Positioned(left: 16, child: Container(width: 24, height: 24, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey[600], border: Border.all(color: AppColors.cardDark, width: 2)), child: const Center(child: Text('M2', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold))))),
                          Positioned(left: 32, child: Container(width: 24, height: 24, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey[500], border: Border.all(color: AppColors.cardDark, width: 2)), child: const Center(child: Text('S3', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold))))),
                        ],
                      ),
                    ),
                    const Text('Other scouts from Big 10 are viewing', style: TextStyle(color: Colors.grey, fontSize: 10)),
                  ],
                ),
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtonsRecruiter() {
    return Row(
      children: [
        Expanded(child: _buildButton('Contact', Icons.send, true, height: 56, onTap: () {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null && widget.athleteUid != null) {
            final convId = '${user.uid}_${widget.athleteUid!}';
            Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
               conversationId: convId,
               otherUid: widget.athleteUid!,
               otherName: _fullName,
            )));
          }
        })),
        const SizedBox(width: 12),
        Expanded(child: _buildButton('Add Note', Icons.edit_note, false, height: 56)),
      ],
    );
  }

  void _showFullPortfolio() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          builder: (context, scrollController) {
            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Full Portfolio', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: _highlightsList.length,
                    itemBuilder: (context, index) {
                      final h = _highlightsList[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: HighlightVideoPlayer(
                          videoUrl: h['videoId'] ?? '',
                          title: h['title'] ?? 'Highlight ${index + 1}',
                          subtitle: 'Highlight',
                          isHorizontal: false, // Standard vertical ratio
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showScoutsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Scouts Viewing', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true,
                itemCount: 3,
                itemBuilder: (context, index) {
                  final schools = ['University of Michigan', 'Ohio State University', 'Penn State'];
                  final initials = ['UM', 'OSU', 'PSU'];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(backgroundColor: Colors.grey[800], child: Text(initials[index], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    title: Text('Anonymous Scout', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    subtitle: Text(schools[index], style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPrivateScoutNotesInner() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
            children: [
              Icon(Icons.description, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text('Private Scout Notes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[800]!)),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 32, height: 32, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey[700]), child: const Center(child: Text('ME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('My Observation', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              Text('2 days ago', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Exceptional reflexes on close-range shots. Distribution with feet is college-ready. Needs to work on command of the 6-yard box during corners.', style: TextStyle(fontSize: 12, color: Colors.grey[400], height: 1.5)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(border: Border.all(color: AppColors.primary.withOpacity(0.3)), borderRadius: BorderRadius.circular(12), color: AppColors.primary.withOpacity(0.05)),
                  child: const Center(child: Text('View All 3 Notes', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold))),
                )
              ],
            ),
          )
        ],
    );
  }

  // ---- SHARED COMPONENTS ----
  Widget _buildAboutSection({required bool isSelf}) {
    List<String> displayTags = _tagsText.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(isSelf ? 'About You' : 'Bio & Tags', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: displayTags.map((t) => _buildTag(t, isPurple: t.contains('GPA'))).toList(),
        ),
        const SizedBox(height: 12),
        Text(
          _aboutText.isNotEmpty ? _aboutText : 'No bio available.',
          style: TextStyle(color: Colors.grey[400], fontSize: 14, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildTag(String text, {bool isPurple = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isPurple ? Colors.purple[900]?.withOpacity(0.3) : Colors.grey[800]?.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isPurple ? Colors.purple[800]!.withOpacity(0.5) : Colors.transparent),
      ),
      child: Text(text, style: TextStyle(color: isPurple ? Colors.purple[300] : Colors.grey[300], fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildButton(String label, IconData icon, bool isPrimary, {double height = 44, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap ?? () {},
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: isPrimary ? AppColors.primary : AppColors.cardDark,
          borderRadius: BorderRadius.circular(12), // Or 16 for recruiter
          border: isPrimary ? null : Border.all(color: Colors.grey[700]!),
          boxShadow: isPrimary ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: (height > 50) ? 20 : 16, color: Colors.white),
            const SizedBox(width: 8),
            Flexible(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white), overflow: TextOverflow.ellipsis, maxLines: 1)),
          ],
        ),
      ),
    );
  }
} // End of _ProfileScreenState

class HighlightVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String title;
  final String subtitle;
  final bool isHorizontal;
  
  const HighlightVideoPlayer({
    super.key,
    required this.videoUrl,
    required this.title,
    required this.subtitle,
    this.isHorizontal = false,
  });

  @override
  State<HighlightVideoPlayer> createState() => _HighlightVideoPlayerState();
}

class _HighlightVideoPlayerState extends State<HighlightVideoPlayer> {
  late YoutubePlayerController _controller;
  String? _videoId;

  @override
  void initState() {
    super.initState();
    _videoId = _extractVideoId(widget.videoUrl);
    if (_videoId != null) {
      _controller = YoutubePlayerController.fromVideoId(
        videoId: _videoId!,
        autoPlay: true,
        params: const YoutubePlayerParams(showFullscreenButton: true),
      );
    }
  }

  String? _extractVideoId(String url) {
    final RegExp regex = RegExp(r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})');
    final match = regex.firstMatch(url);
    return match?.group(1);
  }

  @override
  void dispose() {
    if (_videoId != null) {
      _controller.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.isHorizontal ? _buildHorizontal(context) : _buildVertical(context);
  }

  void _playVideo(BuildContext context) {
    if (_videoId == null) return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: YoutubePlayer(controller: _controller),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    ).then((_) {
      _controller.pauseVideo();
    });
  }

  Widget _buildHorizontal(BuildContext context) {
    return GestureDetector(
      onTap: () => _playVideo(context),
      child: Container(
        width: 240,
        decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(16)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16), 
              child: _videoId != null 
                ? Image.network('https://img.youtube.com/vi/$_videoId/0.jpg', fit: BoxFit.cover)
                : Container(color: Colors.grey[700]),
            ),
            Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: const LinearGradient(colors: [Colors.transparent, Colors.black87], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
            Center(
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: Colors.white24, shape: BoxShape.circle, border: Border.all(color: Colors.white54)),
                child: const Icon(Icons.play_arrow, color: Colors.white),
              ),
            ),
            Positioned(bottom: 12, left: 12, right: 12, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)), Text(widget.subtitle, style: TextStyle(color: Colors.grey[300], fontSize: 10))])),
          ],
        ),
      ),
    );
  }

  Widget _buildVertical(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: GestureDetector(
        onTap: () => _playVideo(context),
        child: Container(
          decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(16)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16), 
                child: _videoId != null 
                  ? Image.network('https://img.youtube.com/vi/$_videoId/0.jpg', fit: BoxFit.cover)
                  : Container(color: Colors.grey[700]),
              ),
              Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: const LinearGradient(colors: [Colors.transparent, Colors.black87], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
              Center(
                child: Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(color: Colors.white24, shape: BoxShape.circle, border: Border.all(color: Colors.white54)),
                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 30),
                ),
              ),
              Positioned(bottom: 16, left: 16, right: 16, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)), const SizedBox(height: 2), Text(widget.subtitle, style: TextStyle(color: Colors.grey[300], fontSize: 12))])),
            ],
          ),
        ),
      ),
    );
  }
}
