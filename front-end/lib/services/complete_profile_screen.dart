import 'package:flutter/material.dart';
import 'package:lokseva/screens/home.dart';
import 'package:lokseva/services/api_service.dart';
import 'package:lokseva/services/user_state.dart';

class CompleteProfileScreen extends StatefulWidget {
  final UserProfileResponse initialProfile;

  const CompleteProfileScreen({
    super.key,
    required this.initialProfile,
  });

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  late TextEditingController _ageController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _medicalHistoryController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _ageController = TextEditingController(
      text: widget.initialProfile.age?.toString() ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.initialProfile.phone ?? '',
    );
    _addressController = TextEditingController(
      text: widget.initialProfile.address ?? '',
    );
    _medicalHistoryController = TextEditingController(
      text: widget.initialProfile.medicalHistory ?? '',
    );
  }

  @override
  void dispose() {
    _ageController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _medicalHistoryController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final _savedProfile = await _apiService.saveUserProfile(
        email: widget.initialProfile.email,
        name: widget.initialProfile.name,
        profilePic: widget.initialProfile.profilePic,
        age: int.tryParse(_ageController.text),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        medicalHistory: _medicalHistoryController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );


      UserState().setUser(_savedProfile);
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (context) => Home(),
      ));

    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Info from Firebase
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: widget.initialProfile.profilePic != null
                            ? NetworkImage(widget.initialProfile.profilePic!)
                            : null,
                        child: widget.initialProfile.profilePic == null
                            ? const Icon(Icons.person, size: 50)
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.initialProfile.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.initialProfile.email,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // Age Field
                _buildTextField(
                  controller: _ageController,
                  label: 'Age',
                  hint: 'Enter your age',
                  icon: Icons.cake,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your age';
                    }
                    final age = int.tryParse(value);
                    if (age == null || age < 1 || age > 120) {
                      return 'Please enter a valid age';
                    }
                    return null;
                  }),
                const SizedBox(height: 20),

                // Phone Field
                _buildTextField(
                  controller: _phoneController,
                  label: 'Phone Number',
                  hint: 'Enter your phone number',
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your phone number';
                    }
                    if (value.length < 10) {
                      return 'Please enter a valid phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Address Field
                _buildTextField(
                  controller: _addressController,
                  label: 'Address',
                  hint: 'Enter your address',
                  icon: Icons.location_on,
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Medical History Field
                _buildTextField(
                  controller: _medicalHistoryController,
                  label: 'Medical History (Optional)',
                  hint: 'E.g., Diabetes, Heart condition, Wheelchair bound',
                  icon: Icons.medical_services,
                  maxLines: 3,
                ),
                const SizedBox(height: 40),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurpleAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                      'Save Profile',
                      style: TextStyle(fontSize: 18))))
              ])))));
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.grey),
        hintStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: Colors.deepPurpleAccent),
        filled: true,
        fillColor: Colors.grey.shade900,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.deepPurpleAccent),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }
}