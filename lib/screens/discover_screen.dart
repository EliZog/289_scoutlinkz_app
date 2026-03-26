import 'package:flutter/material.dart';
import '../../main.dart'; // AppColors
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'profile_screen.dart'; // UserRole
import 'auth/role_selection_screen.dart';
import '../widgets/discover_feed_player.dart'; // Added for DiscoverVideoPlayer

class DiscoverScreen extends StatefulWidget {
  final UserRole role;
  
  const DiscoverScreen({super.key, required this.role});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  // Mock data for the feed fallback
  final List<Map<String, dynamic>> _highlights = [
    {
      'name': 'Devin Smith',
      'position': 'Goalkeeper',
      'location': 'Ann Arbor, MI',
      'videoId': 'mock_video_id',
      'color': Colors.blueGrey[900],
      'title': 'Championship Final Saves',
    },
    {
      'name': 'Sarah Kicks',
      'position': 'Striker',
      'location': 'Chicago, IL',
      'videoId': 'mock_video_id',
      'color': Colors.deepPurple[900],
      'title': 'Hat-trick in State Semi-Final',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark feed look
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('athletes').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
          }
          // Filter locally for athletes strictly with highlights > 0
          final athletes = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final highlights = data['highlights'] as List<dynamic>?;
            return highlights != null && highlights.isNotEmpty;
          }).toList();
          
          if (athletes.isEmpty) {
            return _buildMockDataFeed();
          }

          return PageView.builder(
            scrollDirection: Axis.vertical,
            itemCount: athletes.length,
            itemBuilder: (context, index) {
              final data = athletes[index].data() as Map<String, dynamic>;
              final highlights = data['highlights'] as List<dynamic>;
              final firstHighlight = highlights.first as Map<String, dynamic>;
              
              final highlightData = {
                'name': data['name'] ?? 'Athlete',
                'position': data['position'] ?? '',
                'location': data['location'] ?? '',
                'videoId': firstHighlight['videoId'],
                'color': Colors.blueGrey[900],
                'athleteUid': athletes[index].id,
                'title': firstHighlight['title'] ?? 'Highlight Reel',
              };
              return _buildHighlightVideo(highlightData);
            },
          );
        },
      ),
    );
  }

  Widget _buildMockDataFeed() {
    return PageView.builder(
      scrollDirection: Axis.vertical,
      itemCount: _highlights.length,
      itemBuilder: (context, index) {
        final highlight = _highlights[index];
        return _buildHighlightVideo(highlight);
      },
    );
  }

  Widget _buildHighlightVideo(Map<String, dynamic> highlight) {
    bool isRecruiter = widget.role == UserRole.recruiter;
    bool isUnauthenticated = widget.role == UserRole.unauthenticated;

    return Stack(
      children: [
        // YouTube Video Background
        DiscoverVideoPlayer(videoId: highlight['videoId'] ?? ''),
        
        // Trap all iframe pointer hijacks before they break the UI interactions
        Positioned.fill(
          child: PointerInterceptor(
            child: Container(color: Colors.transparent),
          ),
        ),
        
        // Right Side Actions
        Positioned(
          right: 16,
          bottom: 100,
          child: Column(
            children: [
              if (isRecruiter) ...[
                _buildActionItem(Icons.bookmark_border, 'Save'),
              ],
            ],
          ),
        ),

        // Bottom Left Info
        Positioned(
          left: 16,
          bottom: 100,
          right: 80, // Leave room for side actions
          child: GestureDetector(
            onTap: () {
              if (highlight['athleteUid'] == null) return;
              
              final currentUid = FirebaseAuth.instance.currentUser?.uid;
              final isMe = currentUid == highlight['athleteUid'];
              
              UserRole targetRole;
              if (widget.role == UserRole.recruiter) {
                targetRole = UserRole.recruiter;
              } else if (isMe) {
                targetRole = UserRole.athleteSelf;
              } else {
                targetRole = UserRole.athleteOther;
              }
              
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(
                    role: targetRole,
                    athleteUid: highlight['athleteUid'],
                    onNavigateToMessages: () {
                      Navigator.pop(context); // Optional UI routing logic
                    },
                  ),
                ),
              );
            },
            child: Container(
              color: Colors.transparent, // Ensures click hit area bounds
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    highlight['name'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        highlight['position'],
                        style: TextStyle(color: Colors.grey[300], fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      if (highlight['location'] != '')
                        Text(
                          '• ${highlight['location']}',
                          style: TextStyle(color: Colors.grey[400], fontSize: 14),
                        ),
                    ],
                  ),
                  if (highlight['title'] != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      highlight['title'],
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        
        // Unauthenticated Overlay prompt to sign up/login
        if (isUnauthenticated)
          Positioned(
            top: 50,
            right: 16,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text('Sign Up / Login'),
            ),
          ),
      ],
    );
  }

  Widget _buildActionItem(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 32),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
