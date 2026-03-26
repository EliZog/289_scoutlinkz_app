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
  int _selectedRecruiterStatus = -1; // -1: None, 0: Interested, 1: Contacted, 2: In Review, 3: Passed
  bool _isAthleteSaved = false;

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
      
      if (widget.role == UserRole.recruiter) {
        final myUid = FirebaseAuth.instance.currentUser?.uid;
        if (myUid != null) {
          FirebaseFirestore.instance.collection('scouts').doc(myUid).snapshots().listen((doc) {
            if (doc.exists && mounted) {
              final data = doc.data()!;
              final savedIds = List<String>.from(data['savedIds'] ?? []);
              final statuses = Map<String, dynamic>.from(data['statuses'] ?? {});
              
              setState(() {
                _isAthleteSaved = savedIds.contains(targetUid);
                String currentStatus = statuses[targetUid] ?? 'none';
                if (currentStatus == 'interested') _selectedRecruiterStatus = 0;
                else if (currentStatus == 'contacted') _selectedRecruiterStatus = 1;
                else if (currentStatus == 'in-review') _selectedRecruiterStatus = 2;
                else if (currentStatus == 'passed') _selectedRecruiterStatus = 3;
                else _selectedRecruiterStatus = -1;
              });
            }
          });
        }
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
                  ] else if (widget.role == UserRole.scoutSelf) ...[
                    _buildScoutDashboard(),
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
            IconButton(
              icon: Icon(_isAthleteSaved ? Icons.star : Icons.star_border, color: _isAthleteSaved ? Colors.amber : Colors.grey),
              onPressed: _toggleSaveAthlete,
            ),
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
                if (widget.role == UserRole.scoutSelf || widget.role == UserRole.recruiter && _positionStr.contains('Recruiter'))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                    child: Text(_positionStr.split('•').last.trim().toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 0.5)),
                  )
                else
                  Wrap(
                    spacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(4)),
                        child: Text(_positionStr.split('•').first.trim().toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(4)),
                        child: Text(_positionStr.split('•').last.trim().toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
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
          _buildPill('Interested', AppColors.statusInterested, _selectedRecruiterStatus == 0, () => _updateScoutStatus('interested')),
          const SizedBox(width: 8),
          _buildPill('Contacted', AppColors.statusContacted, _selectedRecruiterStatus == 1, () => _updateScoutStatus('contacted')),
          const SizedBox(width: 8),
          _buildPill('In Review', AppColors.statusInterview, _selectedRecruiterStatus == 2, () => _updateScoutStatus('in-review')),
          const SizedBox(width: 8),
          _buildPill('Passed', AppColors.statusPassed, _selectedRecruiterStatus == 3, () => _updateScoutStatus('passed')),
        ],
      ),
    );
  }

  Widget _buildPill(String label, Color color, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.1) : AppColors.cardLight.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isActive ? color : Colors.transparent, width: 2),
      ),
      child: Row(
        children: [
          if (isActive) ...[Icon(Icons.check_circle, size: 14, color: color), const SizedBox(width: 6)],
          Text(label, style: TextStyle(color: isActive ? color : Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    ));
  }
  
  Future<void> _updateScoutStatus(String status) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid != null && widget.athleteUid != null) {
      // Toggle off if same
      String newStatus = status;
      if (status == 'interested' && _selectedRecruiterStatus == 0) newStatus = 'none';
      if (status == 'contacted' && _selectedRecruiterStatus == 1) newStatus = 'none';
      if (status == 'in-review' && _selectedRecruiterStatus == 2) newStatus = 'none';
      if (status == 'passed' && _selectedRecruiterStatus == 3) newStatus = 'none';

      await FirebaseFirestore.instance.collection('scouts').doc(myUid).set({
         'statuses': { widget.athleteUid!: newStatus }
      }, SetOptions(merge: true));
    }
  }

  Future<void> _toggleSaveAthlete() async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid != null && widget.athleteUid != null) {
      if (_isAthleteSaved) {
        await FirebaseFirestore.instance.collection('scouts').doc(myUid).update({
          'savedIds': FieldValue.arrayRemove([widget.athleteUid!])
        });
      } else {
        await FirebaseFirestore.instance.collection('scouts').doc(myUid).set({
          'savedIds': FieldValue.arrayUnion([widget.athleteUid!]),
          'statuses': { widget.athleteUid!: 'interested' } // Auto-mark interested on save
        }, SetOptions(merge: true));
      }
    }
  }

  Widget _buildScoutDashboard() {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return const SizedBox();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('scouts').doc(myUid).snapshots(),
      builder: (context, snapshot) {
        int savedCount = 0;
        int contactedCount = 0;
        int inReviewCount = 0;
        List<String> savedIds = [];
        
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          savedIds = List<String>.from(data['savedIds'] ?? []);
          savedCount = savedIds.length;
          final statuses = Map<String, dynamic>.from(data['statuses'] ?? {});
          statuses.values.forEach((val) {
             if (val == 'interested') savedCount++; // Also count implicit saves
             if (val == 'contacted') contactedCount++;
             if (val == 'in-review') inReviewCount++;
          });
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(child: _buildStatCard(savedCount.toString(), 'SAVED ATHLETES')),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard(contactedCount.toString(), 'CONTACTED')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildStatCard(inReviewCount.toString(), 'IN REVIEW')),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('0', 'PROFILE VIEWS')),
              ],
            ),
            const SizedBox(height: 48),
            if (savedIds.isNotEmpty) ...[
               const Row(
                 children: [
                   Icon(Icons.star, color: Colors.amber, size: 20),
                   SizedBox(width: 8),
                   Text('Starred Athletes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber)),
                 ],
               ),
               const SizedBox(height: 16),
               StreamBuilder<QuerySnapshot>(
                 stream: FirebaseFirestore.instance.collection('athletes').where(FieldPath.documentId, whereIn: savedIds.take(10).toList()).snapshots(),
                 builder: (context, starredSnap) {
                    if (!starredSnap.hasData) return const Center(child: CircularProgressIndicator());
                    final starredDocs = starredSnap.data!.docs;
                    return GridView.builder(
                       shrinkWrap: true,
                       physics: const NeverScrollableScrollPhysics(),
                       gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                         crossAxisCount: 3,
                         crossAxisSpacing: 12,
                         mainAxisSpacing: 12,
                         childAspectRatio: 0.85,
                       ),
                       itemCount: starredDocs.length,
                       itemBuilder: (context, index) => _buildAthleteGridCard(starredDocs[index], isStarred: true),
                    );
                 }
               ),
               const SizedBox(height: 24),
            ],
            
            const Row(
              children: [
                Text('Recent Athletes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('athletes').orderBy('createdAt', descending: true).limit(9).snapshots(),
              builder: (context, athletesSnap) {
                 if (!athletesSnap.hasData) return const Center(child: CircularProgressIndicator());
                 final docs = athletesSnap.data!.docs;
                 return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: docs.length,
                    itemBuilder: (context, index) => _buildAthleteGridCard(docs[index], isStarred: false),
                 );
              }
            )
          ],
        );
      }
    );
  }

  Widget _buildAthleteGridCard(DocumentSnapshot doc, {bool isStarred = false}) {
    final ath = doc.data() as Map<String, dynamic>;
    String rawName = (ath['name'] ?? 'A').toString().trim();
    String initial = rawName.isNotEmpty ? rawName[0].toUpperCase() : 'A';
    
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(
           role: UserRole.recruiter,
           onNavigateToMessages: widget.onNavigateToMessages,
           athleteUid: doc.id,
        )));
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isStarred ? Colors.amber.withOpacity(0.05) : AppColors.cardLight.withOpacity(0.05), 
          borderRadius: BorderRadius.circular(16),
          border: isStarred ? Border.all(color: Colors.amber.withOpacity(0.5), width: 1.5) : null,
          boxShadow: isStarred ? [BoxShadow(color: Colors.amber.withOpacity(0.1), blurRadius: 8, spreadRadius: 1)] : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 26, 
                  backgroundColor: isStarred ? Colors.amber[700] : AppColors.primary, 
                  child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))
                ),
                if (isStarred)
                  Positioned(
                    bottom: -2, right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(color: Colors.amber, shape: BoxShape.circle, border: Border.all(color: AppColors.backgroundDark, width: 2)),
                      child: const Icon(Icons.star, color: Colors.white, size: 10),
                    ),
                  )
              ],
            ),
            const SizedBox(height: 8),
            Text(ath['name'] ?? 'Athlete', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis, maxLines: 1),
            const SizedBox(height: 2),
            Text(ath['position'] ?? 'Player', style: TextStyle(fontSize: 10, color: Colors.grey[400]), overflow: TextOverflow.ellipsis, maxLines: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildRecruiterSummary() {
    if (widget.athleteUid == null) return const SizedBox();
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('scouts').snapshots(),
      builder: (context, snapshot) {
        int scoreModifier = 0;
        int scoutCount = 0;
        List<String> activeScoutUids = [];
        
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
             final data = doc.data() as Map<String, dynamic>;
             final statuses = Map<String, dynamic>.from(data['statuses'] ?? {});
             final status = statuses[widget.athleteUid!];
             
             if (status != null && status != 'none') {
                scoutCount++;
                activeScoutUids.add(doc.id);
                if (status == 'interested') scoreModifier += 1;
                else if (status == 'contacted') scoreModifier += 2;
                else if (status == 'in-review') scoreModifier += 3;
                else if (status == 'passed') scoreModifier += 4;
             }
          }
        }

        String scoreLetter = 'C';
        if (scoreModifier >= 10) scoreLetter = 'A+';
        else if (scoreModifier >= 6) scoreLetter = 'A';
        else if (scoreModifier >= 3) scoreLetter = 'B';

        String demandLabel = scoreModifier >= 6 ? 'High Demand' : (scoreModifier >= 3 ? 'Solid Interest' : 'Developing');
        Color demandColor = scoreModifier >= 6 ? Colors.orange : (scoreModifier >= 3 ? Colors.green : Colors.grey);

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
                      child: Center(child: Text(scoreLetter, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900))),
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
                            RichText(text: TextSpan(children: [TextSpan(text: _height.isNotEmpty ? _height : "--", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))])),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Weight', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            RichText(text: TextSpan(children: [TextSpan(text: _weight.isNotEmpty ? _weight : "--", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))])),
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
                                Container(width: 8, height: 8, decoration: BoxDecoration(color: demandColor, shape: BoxShape.circle)),
                                const SizedBox(width: 6),
                                Text(demandLabel, style: TextStyle(color: demandColor, fontSize: 14, fontWeight: FontWeight.bold)),
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
                            Text('$scoutCount Active', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 8),
                  if (activeScoutUids.isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SizedBox(
                          width: (activeScoutUids.take(3).length * 16.0) + 12.0, height: 24,
                          child: Stack(
                            children: activeScoutUids.take(3).toList().asMap().entries.map((entry) {
                              int idx = entry.key;
                              String scoutId = entry.value;
                              return Positioned(
                                left: idx * 16.0,
                                child: StreamBuilder<DocumentSnapshot>(
                                  stream: FirebaseFirestore.instance.collection('scouts').doc(scoutId).snapshots(),
                                  builder: (context, scoutSnap) {
                                     String initials = 'S';
                                     if (scoutSnap.hasData && scoutSnap.data!.exists) {
                                       var data = scoutSnap.data!.data() as Map<String, dynamic>?;
                                       if (data != null) {
                                         String name = data['organization'] ?? data['displayName'] ?? 'S';
                                         initials = name.isNotEmpty ? name[0].toUpperCase() : 'S';
                                       }
                                     }
                                     return Container(width: 24, height: 24, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey[(800 - idx * 100).clamp(400, 800)], border: Border.all(color: AppColors.cardDark, width: 2)), child: Center(child: Text(initials, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))));
                                  }
                                )
                              );
                            }).toList(),
                          ),
                        ),
                        Text('Organizations are active', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                      ],
                    )
                  else
                    const Text('No active scouts yet.', style: TextStyle(color: Colors.grey, fontSize: 10)),
                ],
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildActionButtonsRecruiter() {
    return Row(
      children: [
        Expanded(child: _buildButton('Contact', Icons.send, true, height: 56, onTap: () async {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null && widget.athleteUid != null) {
            final convId = '${user.uid}_${widget.athleteUid!}';
            
            // Create conversation doc explicitly to prevent loading lock
            await FirebaseFirestore.instance.collection('conversations').doc(convId).set({
               'scoutUid': user.uid,
               'athleteUid': widget.athleteUid!,
               'updatedAt': FieldValue.serverTimestamp(),
               'participants': [user.uid, widget.athleteUid!],
            }, SetOptions(merge: true));

            if (mounted) {
               Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
                  conversationId: convId,
                  otherUid: widget.athleteUid!,
                  otherName: _fullName,
               )));
            }
          }
        })),
        const SizedBox(width: 12),
        Expanded(child: _buildButton('Add Note', Icons.edit_note, false, height: 56, onTap: _showAddNoteBottomSheet)),
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

  void _showAddNoteBottomSheet() {
    final TextEditingController _noteController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
         padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
         child: Column(
           mainAxisSize: MainAxisSize.min,
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
              const Text('Add Private Note', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),
              TextField(
                controller: _noteController, 
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Record a scouting observation...',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  filled: true,
                  fillColor: AppColors.backgroundDark,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ), 
                maxLines: 4
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () async {
                    if (_noteController.text.isNotEmpty) {
                      final myUid = FirebaseAuth.instance.currentUser?.uid;
                      if (myUid != null && widget.athleteUid != null) {
                         final ref = FirebaseFirestore.instance.collection('scouts').doc(myUid).collection('notes').doc(widget.athleteUid);
                         await ref.set({
                            'notesList': FieldValue.arrayUnion([{
                                'text': _noteController.text,
                                'date': Timestamp.now()
                            }])
                         }, SetOptions(merge: true));
                      }
                    }
                    if (mounted) Navigator.pop(context);
                  },
                  child: const Text('Save Note', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 24),
           ]
         )
      )
    );
  }

  Widget _buildPrivateScoutNotesInner() {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null || widget.athleteUid == null) return const SizedBox();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('scouts').doc(myUid).collection('notes').doc(widget.athleteUid).snapshots(),
      builder: (context, snapshot) {
         List<dynamic> notes = [];
         if (snapshot.hasData && snapshot.data!.exists) {
            notes = (snapshot.data!.data() as Map<String, dynamic>)['notesList'] ?? [];
         }
         
         if (notes.isEmpty) return const SizedBox();

         final latestNote = notes.last as Map<String, dynamic>;
         final noteText = latestNote['text'] ?? '';
         
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
                                   Text('Active Note', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                                 ],
                               ),
                               const SizedBox(height: 6),
                               Text(noteText, style: TextStyle(fontSize: 13, color: Colors.grey[300], height: 1.5)),
                             ],
                           ),
                         ),
                       ],
                     ),
                     if (notes.length > 1) ...[
                       const SizedBox(height: 16),
                       Container(
                         width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10),
                         decoration: BoxDecoration(border: Border.all(color: AppColors.primary.withOpacity(0.3)), borderRadius: BorderRadius.circular(12), color: AppColors.primary.withOpacity(0.05)),
                         child: Center(child: Text('View All ${notes.length} Notes', style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold))),
                       )
                     ]
                   ],
                 ),
               )
             ],
         );
      }
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
