import 'package:flutter/material.dart';
import '../../main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ScoutSignupScreen extends StatefulWidget {
  const ScoutSignupScreen({super.key});

  @override
  State<ScoutSignupScreen> createState() => _ScoutSignupScreenState();
}

class _ScoutSignupScreenState extends State<ScoutSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _organizationController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _organizationController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      setState(() {
        _isLoading = true;
      });
      
      try {
        UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        
        await FirebaseFirestore.instance.collection('scouts').doc(userCredential.user!.uid).set({
          'displayName': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'organization': _organizationController.text.trim(),
          'role': 'scout',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'savedIds': [],
          'statuses': {},
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
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                const Text(
                  'Scout / Coach Signup',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create your account to browse athletes',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                const SizedBox(height: 40),
                _buildTextField(
                  label: 'Full Name',
                  hint: 'John Doe',
                  controller: _nameController,
                  autofillHints: const [AutofillHints.name],
                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  label: 'Email',
                  hint: 'john@example.com',
                  keyboardType: TextInputType.emailAddress,
                  controller: _emailController,
                  autofillHints: const [AutofillHints.email, AutofillHints.username],
                  validator: (val) => val == null || !val.contains('@') ? 'Invalid email' : null,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  label: 'Organization / Team',
                  hint: 'FC Barcelona Academy',
                  controller: _organizationController,
                  autofillHints: const [AutofillHints.organizationName],
                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  label: 'Password',
                  hint: '••••••••',
                  obscureText: true,
                  controller: _passwordController,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (val) => val == null || val.length < 6 ? 'Too short' : null,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  label: 'Confirm Password',
                  hint: '••••••••',
                  obscureText: true,
                  controller: _confirmPasswordController,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (val) => val != _passwordController.text ? 'Passwords do not match' : null,
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    List<String>? autofillHints,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        AutofillGroup(
          child: TextFormField(
            controller: controller,
            autofillHints: autofillHints,
            obscureText: obscureText,
            keyboardType: keyboardType,
            validator: validator,
            style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: AppColors.cardDark,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
            ),
          ),
        ),
      ],
    );
  }
}
