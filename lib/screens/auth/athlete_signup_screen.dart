import 'package:flutter/material.dart';
import '../../main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AthleteSignupScreen extends StatefulWidget {
  const AthleteSignupScreen({super.key});

  @override
  State<AthleteSignupScreen> createState() => _AthleteSignupScreenState();
}

class _AthleteSignupScreenState extends State<AthleteSignupScreen> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();

  // Use flat fields for simplicity.
  // Step 1: Basic Info
  String _fullName = '';
  String _location = '';
  String _sport = 'Basketball'; // Default for dropdown
  String _position = 'Point Guard';
  String _foot = 'Right'; // Default for dropdown
  String _gradYear = '';
  String _gpa = '';
  String _height = '';
  String _weight = '';
  String _bio = '';

  // Step 2: Stats
  // We'll store stats as a list of Label-Value pairs
  List<Map<String, String>> _stats = [
    {'label': 'Points Per Game', 'value': '24.5'},
    {'label': 'Assists', 'value': '8.2'},
  ];

  // Step 3: Contact Info
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _addStat() {
    setState(() {
      _stats.add({'label': '', 'value': ''});
    });
  }

  void _removeStat(int index) {
    setState(() {
      _stats.removeAt(index);
    });
  }

  void _publishProfile() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      setState(() => _isLoading = true);

      try {
        UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        
        await FirebaseFirestore.instance.collection('athletes').doc(userCredential.user!.uid).set({
          'uid': userCredential.user!.uid,
          'name': _fullName,
          'email': _emailController.text.trim(),
          'bio': _bio,
          'location': _location,
          'phone': _phoneController.text.trim(),
          'position': _position,
          'sport': _sport,
          'foot': _foot,
          'height': _height,
          'weight': _weight,
          'gpa': _gpa,
          'gradYear': int.tryParse(_gradYear) ?? 2026,
          'profileComplete': true,
          'role': 'athlete',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'highlights': [], // Empty array of objects {title, videoId}
          'stats': _stats, // Array of {label, value}
        });
        
        if (mounted) {
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      } on FirebaseAuthException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Signup failed')));
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Athlete Profile', style: TextStyle(color: Colors.white, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildStepperHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: _buildStepContent(),
                ),
              ),
              _buildBottomAction(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepperHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
      child: Row(
        children: List.generate(3, (index) {
          bool isActive = index <= _currentStep;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : Colors.white12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildBasicInfoStep();
      case 1:
        return _buildStatsStep();
      case 2:
        return _buildContactInfoStep();
      default:
        return Container();
    }
  }

  Widget _buildBasicInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Basic Info', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        _buildTextField(label: 'Full Name', onSaved: (v) => _fullName = v ?? ''),
        const SizedBox(height: 16),
        _buildTextField(label: 'Location', onSaved: (v) => _location = v ?? ''),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildDropdown(label: 'Sport', value: _sport, items: ['Basketball', 'Football', 'Soccer', 'Volleyball'], onChanged: (v) => setState(() => _sport = v!))),
            const SizedBox(width: 16),
            Expanded(child: _buildDropdown(label: 'Position', value: _position, items: ['Point Guard', 'Shooting Guard', 'Small Forward', 'Power Forward', 'Center'], onChanged: (v) => setState(() => _position = v!))),
          ],
        ),
        const SizedBox(height: 16),
        _buildDropdown(label: 'Preferred Foot/Hand', value: _foot, items: ['Right', 'Left', 'Both'], onChanged: (v) => setState(() => _foot = v!)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildTextField(label: 'Class/Grad Year', hint: '2024', onSaved: (v) => _gradYear = v ?? '')),
            const SizedBox(width: 16),
            Expanded(child: _buildTextField(label: 'GPA', hint: '3.8', onSaved: (v) => _gpa = v ?? '')),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildTextField(label: 'Height', hint: '6\'2"', onSaved: (v) => _height = v ?? '')),
            const SizedBox(width: 16),
            Expanded(child: _buildTextField(label: 'Weight', hint: '185 lbs', onSaved: (v) => _weight = v ?? '')),
          ],
        ),
        const SizedBox(height: 16),
        _buildTextField(label: 'Bio', hint: 'Describes your game strengths and what makes you stand out...', maxLines: 4, onSaved: (v) => _bio = v ?? ''),
      ],
    );
  }

  Widget _buildStatsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Your Stats', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Add measurable stats relevant to your position.', style: TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 24),
        ...List.generate(_stats.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _buildTextField(label: 'Label', hint: 'e.g. 40-yd Dash', initialValue: _stats[index]['label'], onChanged: (v) => _stats[index]['label'] = v),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _buildTextField(label: 'Value', hint: '4.5s', initialValue: _stats[index]['value'], onChanged: (v) => _stats[index]['value'] = v),
                ),
                IconButton(
                  padding: const EdgeInsets.only(top: 24),
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                  onPressed: () => _removeStat(index),
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: _addStat,
          icon: const Icon(Icons.add, color: AppColors.primary),
          label: const Text('Add Another Stat', style: TextStyle(color: AppColors.primary)),
        ),
      ],
    );
  }

  Widget _buildContactInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Contact Info', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        _buildTextField(
          label: 'Email', hint: 'athlete@example.com', 
          controller: _emailController,
          autofillHints: const [AutofillHints.email, AutofillHints.username],
        ),
        const SizedBox(height: 16),
        _buildTextField(
          label: 'Phone Number', hint: '(555) 123-4567', 
          controller: _phoneController,
          autofillHints: const [AutofillHints.telephoneNumber],
        ),
        const SizedBox(height: 16),
        _buildTextField(
          label: 'Password', hint: '••••••••', obscureText: true, 
          controller: _passwordController,
          autofillHints: const [AutofillHints.newPassword],
        ),
      ],
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.backgroundDark,
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _isLoading ? null : () {
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();
              if (_currentStep < 2) {
                setState(() => _currentStep++);
              } else {
                _publishProfile();
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isLoading 
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(
            _currentStep < 2 ? 'Next' : 'Publish Profile',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    String hint = '',
    String? initialValue,
    int maxLines = 1,
    bool obscureText = false,
    TextEditingController? controller,
    List<String>? autofillHints,
    void Function(String?)? onSaved,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        AutofillGroup(
          child: TextFormField(
            controller: controller,
            autofillHints: autofillHints,
            initialValue: initialValue,
            maxLines: maxLines,
            obscureText: obscureText,
            onSaved: onSaved,
            onChanged: onChanged,
            style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: AppColors.cardDark,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
          ),
        ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          dropdownColor: AppColors.cardDark,
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.white)))).toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.cardDark,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
          ),
        ),
      ],
    );
  }
}
