import 'package:flutter/material.dart';
import '../main.dart'; // To access AppColors

class EditProfileScreen extends StatefulWidget {
  final String initialName;
  final String initialAbout;
  final String initialHeight;
  final String initialWeight;
  final String initialGpa;
  final List<String> initialHighlights;

  const EditProfileScreen({
    super.key,
    required this.initialName,
    required this.initialAbout,
    required this.initialHeight,
    required this.initialWeight,
    required this.initialGpa,
    required this.initialHighlights,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _aboutController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  late TextEditingController _gpaController;
  late List<TextEditingController> _highlightControllers;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _aboutController = TextEditingController(text: widget.initialAbout);
    _heightController = TextEditingController(text: widget.initialHeight);
    _weightController = TextEditingController(text: widget.initialWeight);
    _gpaController = TextEditingController(text: widget.initialGpa);
    _highlightControllers = widget.initialHighlights
        .map((url) => TextEditingController(text: url))
        .toList();
    if (_highlightControllers.isEmpty) {
      _highlightControllers.add(TextEditingController()); // at least one empty
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aboutController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _gpaController.dispose();
    for (var c in _highlightControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _saveProfile() {
    // Return updated data to the previous screen
    Navigator.pop(context, {
      'name': _nameController.text.trim(),
      'bio': _aboutController.text.trim(),
      'height': _heightController.text.trim(),
      'weight': _weightController.text.trim(),
      'gpa': _gpaController.text.trim(),
      'highlights': _highlightControllers
          .map((c) => c.text.trim())
          .where((text) => text.isNotEmpty)
          .toList(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _saveProfile,
            child: const Text('Save', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Picture Placeholder
            Center(
              child: GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile picture upload tapped')));
                },
                child: Stack(
                  children: [
                    Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.cardDark,
                        border: Border.all(color: AppColors.primary, width: 2),
                      ),
                      child: const Center(child: Text('DS', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white))),
                    ),
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Name Section
            const Text('Full Name', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'e.g. David Smith',
                filled: true,
                fillColor: AppColors.cardDark,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 24),
            
            // About Section
            const Text('Bio', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            TextField(
              controller: _aboutController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Tell coaches about your playing style...',
                filled: true,
                fillColor: AppColors.cardDark,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 24),

            // Physical Attributes
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Height', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _heightController,
                        decoration: InputDecoration(hintText: 'e.g. 6\'3"', filled: true, fillColor: AppColors.cardDark, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Weight', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _weightController,
                        decoration: InputDecoration(hintText: 'e.g. 185 lbs', filled: true, fillColor: AppColors.cardDark, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Academic
            const Text('GPA', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            TextField(
              controller: _gpaController,
              decoration: InputDecoration(hintText: 'e.g. 3.8', filled: true, fillColor: AppColors.cardDark, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 24),

            // Highlights
            const Text('Featured Highlights (YouTube URLs)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            ..._highlightControllers.asMap().entries.map((entry) {
              int idx = entry.key;
              TextEditingController controller = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          hintText: 'https://youtube.com/watch?v=...',
                          filled: true,
                          fillColor: AppColors.cardDark,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          prefixIcon: const Icon(Icons.play_circle_fill, color: Colors.grey),
                        ),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    if (_highlightControllers.length > 1) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                        onPressed: () {
                          setState(() {
                            controller.dispose();
                            _highlightControllers.removeAt(idx);
                          });
                        },
                      ),
                    ]
                  ],
                ),
              );
            }),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _highlightControllers.add(TextEditingController());
                });
              },
              icon: const Icon(Icons.add, color: AppColors.primary),
              label: const Text('Add another video', style: TextStyle(color: AppColors.primary)),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}
