import 'package:flutter/material.dart';
import '../main.dart'; // To access AppColors
import 'profile_screen.dart'; // To access UserRole
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatelessWidget {
  final UserRole role;
  
  const MessagesScreen({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.edit_square, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          _buildPriorityRecruitersList(),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10, height: 1),
          Expanded(
            child: _buildGeneralMessageList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityRecruitersList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            'PRIORITY RECRUITERS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: AppColors.accentPurple,
            ),
          ),
        ),
        SizedBox(
          height: 100,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('conversations').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) return const SizedBox();

              final myConvos = snapshot.data!.docs.where((doc) => doc.id.contains(user.uid)).toList();
              myConvos.sort((a, b) {
                final ad = a.data() as Map<String, dynamic>;
                final bd = b.data() as Map<String, dynamic>;
                return (bd['updatedAt'] as Timestamp?)?.compareTo(ad['updatedAt'] as Timestamp? ?? Timestamp.now()) ?? 0;
              });

              return ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: myConvos.length,
                separatorBuilder: (context, index) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final conv = myConvos[index];
                  String otherUid = conv.id.replaceAll(user.uid, '').replaceAll('_', '');
                  if (otherUid.isEmpty) return const SizedBox();

                  return StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('scouts').doc(otherUid).snapshots(),
                    builder: (context, scoutSnap) {
                      String name = 'Loading...';
                      String initial = '..';
                      if (scoutSnap.hasData && scoutSnap.data!.exists) {
                        final scoutData = scoutSnap.data!.data() as Map<String, dynamic>;
                        name = scoutData['name'] ?? scoutData['displayName'] ?? 'Recruiter';
                        initial = name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.substring(0, 1).toUpperCase();
                      }

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(
                            conversationId: conv.id,
                            otherName: name,
                            otherUid: otherUid,
                          )));
                        },
                        child: _buildPriorityRecruiterAvatar(name, initial, AppColors.primary),
                      );
                    }
                  );
                },
              );
            }
          ),
        ),
      ],
    );
  }

  Widget _buildPriorityRecruiterAvatar(String name, String initials, Color color, {bool hasUnread = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  border: Border.all(
                    color: hasUnread ? AppColors.accentPurple : Colors.transparent,
                    width: 3,
                  ),
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                  ),
                ),
              ),
              if (hasUnread)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.backgroundDark, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 70,
            child: Text(
              name,
              style: const TextStyle(fontSize: 10, color: Colors.white70),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralMessageList() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    String queryField = role == UserRole.recruiter ? 'scoutUid' : 'athleteUid';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('conversations')
          .where(queryField, isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading messages: ${snapshot.error}',
              style: const TextStyle(color: Colors.white54, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }
        
        final conversations = snapshot.data!.docs.toList();
        
        // Sort conversations client-side by updatedAt descending
        conversations.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTimestamp = aData['updatedAt'] as Timestamp?;
          final bTimestamp = bData['updatedAt'] as Timestamp?;
          if (aTimestamp == null && bTimestamp == null) return 0;
          if (aTimestamp == null) return 1;
          if (bTimestamp == null) return -1;
          return bTimestamp.compareTo(aTimestamp);
        });
        
        if (conversations.isEmpty) {
          final emptyText = role == UserRole.recruiter 
              ? 'No athletes have messaged you' 
              : 'No scouts have messaged you';
          return Center(child: Text(emptyText, style: const TextStyle(color: Colors.white54, fontSize: 16)));
        }
        
        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 120),
          itemCount: conversations.length + 1, 
          itemBuilder: (context, index) {
            if (index == 0) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'CONVERSATIONS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: Colors.white54,
                  ),
                ),
              );
            }
            
            final doc = conversations[index - 1];
            final data = doc.data() as Map<String, dynamic>;
            
            // To be robust we fetch the other participant's doc, but for immediate UI we can parse Uid
            final otherUid = role == UserRole.recruiter ? data['athleteUid'] : data['scoutUid'];
            final uidStr = otherUid?.toString() ?? '';
            final placeholderName = 'User ${uidStr.length > 4 ? uidStr.substring(0, 4) : uidStr}';
            
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection(role == UserRole.recruiter ? 'athletes' : 'scouts').doc(otherUid).get(),
              builder: (context, userSnapshot) {
                String name = placeholderName;
                if (userSnapshot.hasData && userSnapshot.data!.exists) {
                  final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                  name = userData['name'] ?? userData['displayName'] ?? placeholderName;
                }
                
                return FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                    .collection('conversations')
                    .doc(doc.id)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .limit(1)
                    .get(),
                  builder: (context, msgSnapshot) {
                    String lastMessage = 'Tap to start a conversation';
                    if (msgSnapshot.hasData && msgSnapshot.data!.docs.isNotEmpty) {
                      final mData = msgSnapshot.data!.docs.first.data() as Map<String, dynamic>;
                      lastMessage = mData['text'] ?? mData['message'] ?? 'Message received';
                    }
                    // Alternatively try createdAt if timestamp isn't used
                    if (msgSnapshot.hasError || (!msgSnapshot.hasData && msgSnapshot.connectionState == ConnectionState.done)) {
                       // Fallback to checking createdAt if 'timestamp' is missing index
                       return FutureBuilder<QuerySnapshot>(
                          future: FirebaseFirestore.instance.collection('conversations').doc(doc.id).collection('messages').orderBy('createdAt', descending: true).limit(1).get(),
                          builder: (ctx, altSnapshot) {
                            if (altSnapshot.hasData && altSnapshot.data!.docs.isNotEmpty) {
                               final mData = altSnapshot.data!.docs.first.data() as Map<String, dynamic>;
                               lastMessage = mData['text'] ?? mData['message'] ?? 'Message received';
                            }
                            return _buildMessageTile(name, lastMessage, 'Recent', isUnread: false);
                          }
                       );
                    }
                    
                    return _buildMessageTile(name, lastMessage, 'Recent', isUnread: false, onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(
                        conversationId: doc.id,
                        otherName: name,
                        otherUid: otherUid,
                      )));
                    });
                  }
                );
              }
            );
          },
        );
      },
    );
  }

  Widget _buildMessageTile(String name, String message, String time, {bool isUnread = false, VoidCallback? onTap}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Colors.grey[700]!, Colors.grey[800]!],
          ),
        ),
        child: Center(
          child: Text(
            name.substring(0, 1),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      title: Text(
        name,
        style: TextStyle(
          fontWeight: isUnread ? FontWeight.bold : FontWeight.w500,
          color: Colors.white,
          fontSize: 16,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          message,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isUnread ? Colors.white : Colors.white54,
            fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            time,
            style: TextStyle(
              color: isUnread ? AppColors.accentPurple : Colors.white54,
              fontSize: 12,
              fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (isUnread) ...[
            const SizedBox(height: 6),
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppColors.accentPurple,
                shape: BoxShape.circle,
              ),
            ),
          ]
        ],
      ),
      onTap: onTap ?? () {},
    );
  }
}
