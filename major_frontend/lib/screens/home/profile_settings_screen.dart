import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../auth/auth_screens.dart';
import 'selection_pages.dart';
import 'dart:convert';
import 'dart:io';
import 'location_selection_page.dart';
import '../../widgets/app_theme_widgets.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProfileSettingsScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final VoidCallback onUpdate;

  const ProfileSettingsScreen({
    super.key,
    required this.userData,
    required this.onUpdate,
  });

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();
  late TextEditingController _bioController;
  late FocusNode _bioFocusNode;
  late Map<String, dynamic> _currentData;
  late Map<String, dynamic> _initialData;
  bool _isLoading = false;
  bool _isActionLoading = false;
  bool _showValidationErrors = false;
  File? _profileImageFile;
  File? _coverImageFile;

  @override
  void initState() {
    super.initState();
    _bioFocusNode = FocusNode();
    _initialData = Map.from(widget.userData);
    _currentData = Map.from(widget.userData);
    _bioController = TextEditingController(text: _currentData['bio'] ?? '');
    _bioController.addListener(() => setState(() {}));
  }

  bool get _isDirty {
    if (_profileImageFile != null || _coverImageFile != null) return true;
    if (_bioController.text != (_initialData['bio'] ?? '')) return true;
    
    // Check if any other relevant field changed
    final fieldsToCheck = [
      'location_label', 'gender', 'age', 'experience', 'height', 'weight', 
      'looking_for', 'preferences', 'training_level', 'workout_frequency', 'availability',
      'fullName'
    ];
    
    for (var field in fieldsToCheck) {
      if (jsonEncode(_initialData[field]) != jsonEncode(_currentData[field])) {
        return true;
      }
    }
    
    return false;
  }

  @override
  void dispose() {
    _bioController.dispose();
    _bioFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickAndCropImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: image.path,
      uiSettings: [
        AndroidUiSettings(
            toolbarTitle: 'Crop Profile Picture',
            toolbarColor: const Color(0xFF1B1B1B),
            toolbarWidgetColor: Colors.white,
            statusBarColor: const Color(0xFF1B1B1B),
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            aspectRatioPresets: [
              CropAspectRatioPreset.square,
            ],
            cropStyle: CropStyle.circle,
            showCropGrid: false,
            hideBottomControls: true,
            backgroundColor: const Color(0xFF1B1B1B),
            activeControlsWidgetColor: const Color(0xFFB497FF),
        ),
        IOSUiSettings(
          title: 'Crop Profile Picture',
          aspectRatioPresets: [
            CropAspectRatioPreset.square,
          ],
          cropStyle: CropStyle.circle,
          hidesNavigationBar: true,
        ),
      ],
    );

    if (croppedFile != null) {
      setState(() {
        _profileImageFile = File(croppedFile.path);
      });
    }
  }

  Future<void> _pickAndCropCoverImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: image.path,
      uiSettings: [
        AndroidUiSettings(
            toolbarTitle: 'Crop Cover Photo',
            toolbarColor: const Color(0xFF1B1B1B),
            toolbarWidgetColor: Colors.white,
            statusBarColor: const Color(0xFF1B1B1B),
            aspectRatioPresets: [
              CropAspectRatioPreset.ratio16x9,
            ],
            initAspectRatio: CropAspectRatioPreset.ratio16x9,
            backgroundColor: const Color(0xFF1B1B1B),
            activeControlsWidgetColor: const Color(0xFFB497FF),
            hideBottomControls: true,
        ),
        IOSUiSettings(
          title: 'Crop Cover Photo',
          aspectRatioPresets: [
            CropAspectRatioPreset.ratio16x9,
          ],
        ),
      ],
    );

    if (croppedFile != null) {
      setState(() {
        _coverImageFile = File(croppedFile.path);
      });
    }
  }

  Future<void> _saveAllProfile() async {
    // Check if any text/data fields changed
    bool textDataChanged = false;
    if (_bioController.text != (_initialData['bio'] ?? '')) textDataChanged = true;
    
    final fieldsToCheck = [
      'location_label', 'gender', 'age', 'experience', 'height', 'weight', 
      'looking_for', 'preferences', 'training_level', 'workout_frequency', 'availability',
      'fullName'
    ];
    
    for (var field in fieldsToCheck) {
      if (jsonEncode(_initialData[field]) != jsonEncode(_currentData[field])) {
        textDataChanged = true;
        break;
      }
    }
    
    bool onlyVisualsChanged = !textDataChanged && (_profileImageFile != null || _coverImageFile != null);

    if (!onlyVisualsChanged) {
      // Validation
      final List<String> missingFields = [];
      if (_bioController.text.isEmpty) missingFields.add('bio');
      if (_currentData['location_label'] == null) missingFields.add('location');
      if (_currentData['gender'] == null) missingFields.add('gender');
      if (_currentData['age'] == null) missingFields.add('age');
      if (_currentData['experience'] == null) missingFields.add('experience');
      if (_currentData['height'] == null) missingFields.add('height');
      if (_currentData['weight'] == null) missingFields.add('weight');
      if (_currentData['looking_for'] == null) missingFields.add('looking_for');
      
      var prefsRaw = _currentData['preferences'];
      if (prefsRaw == null || (prefsRaw is List && prefsRaw.isEmpty)) missingFields.add('preferences');
      
      if (_currentData['training_level'] == null) missingFields.add('training_level');
      if (_currentData['workout_frequency'] == null) missingFields.add('workout_frequency');
      
      var availRaw = _currentData['availability'];
      if (availRaw == null || (availRaw is List && availRaw.isEmpty)) missingFields.add('availability');

      if (missingFields.isNotEmpty) {
        setState(() => _showValidationErrors = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all highlighted fields')),
        );
        return;
      }
    }

    setState(() => _isActionLoading = true);

    // Upload pictures if changed
    if (_profileImageFile != null) {
      final error = await _authService.uploadProfilePicture(_profileImageFile!.path);
      if (error != null) {
        setState(() => _isActionLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload profile picture: $error')));
        }
        return;
      }
    }

    if (_coverImageFile != null) {
      final error = await _authService.uploadCoverPhoto(_coverImageFile!.path);
      if (error != null) {
        setState(() => _isActionLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload cover photo: $error')));
        }
        return;
      }
    }

    final dataToSave = Map<String, dynamic>.from(_currentData);
    dataToSave['bio'] = _bioController.text;
    
    // Explicitly set setup as completed if we're here and it's NOT visuals only 
    // (since we validated all required fields)
    if (!onlyVisualsChanged) {
      dataToSave['is_setup_completed'] = 1;
    }

    String? error;
    if (!onlyVisualsChanged) {
      error = await _authService.updateProfile(dataToSave);
    }
    
    if (error == null) {
      // Fetch latest profile state to get correct picture URLs
      final updatedProfile = await _authService.getUserProfile();
      if (updatedProfile != null) {
        dataToSave['profilePictureUrl'] = updatedProfile['profilePictureUrl'];
        dataToSave['coverPhotoUrl'] = updatedProfile['coverPhotoUrl'];
        // Ensure other UI components relying on current data get these
        _currentData['profilePictureUrl'] = updatedProfile['profilePictureUrl'];
        _currentData['coverPhotoUrl'] = updatedProfile['coverPhotoUrl'];
      }
    }

    setState(() => _isActionLoading = false);

    if (error == null) {
      // Small delay to ensure DB write is fully committed before parent re-fetches
      await Future.delayed(const Duration(milliseconds: 200));
      widget.onUpdate();
      setState(() {
        _initialData = Map.from(dataToSave);
        _currentData = Map.from(dataToSave);
        _profileImageFile = null;
        _coverImageFile = null;
        _showValidationErrors = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved successfully')),
        );
        Navigator.pop(context);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error')),
        );
      }
    }
  }

  void _showDiscardDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2E),
        title: Text('Discard Changes?', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('You have unsaved changes. Do you want to discard them?', style: GoogleFonts.poppins(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Keep Editing', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back
            },
            child: Text('Discard', style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _navigateToSelection(Widget page) async {
    FocusScope.of(context).requestFocus(FocusNode());
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );

    FocusScope.of(context).requestFocus(FocusNode());

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _currentData.addAll(result);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDirty,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _showDiscardDialog();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1B1B1B),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1B1B1B),
          elevation: 0,
          surfaceTintColor: const Color(0xFF1B1B1B),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              if (_isDirty) {
                _showDiscardDialog();
              } else {
                Navigator.pop(context);
              }
            },
          ),
          title: Text(
            'Your profile',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
          actions: [
            if (_isDirty)
              TextButton(
                onPressed: _saveAllProfile,
                child: Text(
                  'Save',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFB497FF),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
          ],
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).requestFocus(FocusNode()),
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 30),
                    _buildSectionHeader('About me'),
                    _buildBioField(),
                    const SizedBox(height: 24),
                    _buildSectionHeader('Location'),
                    _buildSimpleCard(
                      _currentData['location_label'] ?? 'Not Selected',
                      () => _navigateToSelection(LocationSelectionPage(
                        initialData: _currentData,
                        onUpdate: (val) {
                          setState(() {
                            _currentData.addAll(val);
                          });
                        },
                      )),
                      isValid: _currentData['location_label'] != null,
                    ),
                    const SizedBox(height: 24),
                    _buildSectionHeader('Fitness & Body Info:'),
                    _buildFitnessInfoCard(),
                    const SizedBox(height: 24),
                    _buildSectionHeader('Looking For'),
                    _buildSimpleCard(
                      _currentData['looking_for'] ?? 'Not Selected',
                      () => _navigateToSelection(LookingForSelectionPage(
                        initialValue: _currentData['looking_for'],
                      )),
                      isValid: _currentData['looking_for'] != null,
                    ),
                    const SizedBox(height: 24),
                    _buildSectionHeader('Preferences'),
                    _buildPreferencesCard(),
                    const SizedBox(height: 24),
                    _buildSectionHeader('Training Level'),
                    _buildSimpleCard(
                      _currentData['training_level'] ?? 'Not Selected',
                      () => _navigateToSelection(TrainingLevelSelectionPage(
                        initialValue: _currentData['training_level'],
                      )),
                      isValid: _currentData['training_level'] != null,
                    ),
                    const SizedBox(height: 24),
                    _buildSectionHeader('Day Per Week'),
                    _buildSimpleCard(
                      _currentData['workout_frequency']?.toString() ?? 'Not Selected',
                      () => _navigateToSelection(FrequencySelectionPage(
                        initialValue: (_currentData['workout_frequency'] ?? 3).toInt(),
                      )),
                      isValid: _currentData['workout_frequency'] != null,
                    ),
                    const SizedBox(height: 24),
                    _buildSectionHeader('Schedule / Availability'),
                    _buildAvailabilityCard(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
              if (_isLoading || _isActionLoading)
                Container(
                  color: Colors.black54,
                  child: const Center(child: PremiumLoading(size: 50)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final profilePic = _currentData['profilePictureUrl'];
    final coverPic = _currentData['coverPhotoUrl'];
    final name = _currentData['fullName'] ?? 'User';
    final email = _currentData['email'] ?? '';

    return Center(
      child: Column(
        children: [
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: const Color(0xFF2E2E2E),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Cover Photo
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: _coverImageFile != null
                        ? Image.file(
                            _coverImageFile!,
                            fit: BoxFit.cover,
                          )
                        : (coverPic != null && coverPic.isNotEmpty)
                            ? CachedNetworkImage(
                                key: ValueKey(coverPic),
                                imageUrl: coverPic,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(color: const Color(0xFF2E2E2E)),
                                errorWidget: (context, url, error) => const Icon(Icons.error),
                              )
                            : Container(color: const Color(0xFF2E2E2E)),

                  ),
                ),
                // Cover Photo Edit Button
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: _pickAndCropCoverImage,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                    ),
                  ),
                ),
                // Profile Photo
                Positioned(
                  bottom: -40,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: _pickAndCropImage,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFF1B1B1B),
                              shape: BoxShape.circle,
                            ),
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF2E2E2E),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: _profileImageFile != null
                                  ? Image.file(
                                      _profileImageFile!,
                                      fit: BoxFit.cover,
                                    )
                                  : (profilePic != null && profilePic.isNotEmpty) 
                                      ? CachedNetworkImage(
                                          key: ValueKey(profilePic),
                                          imageUrl: profilePic,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => Container(color: const Color(0xFF2E2E2E)),
                                          errorWidget: (context, url, error) => const Icon(Icons.person, size: 50, color: Colors.grey),
                                        )
                                      : const Icon(Icons.person, size: 50, color: Colors.grey),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0xFFB497FF),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.edit, color: Colors.white, size: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 56),
          const SizedBox(height: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showEditNameDialog(name),
                child: const Icon(Icons.edit, color: Colors.white70, size: 20),
              ),
            ],
          ),
          if (email.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              email,
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
          // Removed Birthday section
        ],
      ),
    );
  }

  void _showEditNameDialog(String currentName) {
    final TextEditingController nameController = TextEditingController(text: currentName);
    AppDialog.show(
      context: context,
      title: 'Edit Name',
      subtitle: 'Enter your full name to update your profile.',
      content: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextField(
          controller: nameController,
          autofocus: true,
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
          decoration: const InputDecoration(
            hintText: 'Full Name',
            hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
            border: InputBorder.none,
          ),
          onChanged: (text) {
            setState(() {
              _currentData['fullName'] = text;
            });
          },
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          color: const Color(0xFFB497FF),
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildBioField() {
    final bool isInvalid = _bioController.text.isEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          TextField(
            controller: _bioController,
            focusNode: _bioFocusNode,
            autofocus: false,
            maxLines: 4,
            maxLength: 500,
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Tell us something about yourself...',
              hintStyle: TextStyle(color: Colors.grey),
              counterText: '',
            ),
            onChanged: (text) => setState(() {}),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_bioController.text.length}/500',
                style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
              ),
              if (_showValidationErrors && isInvalid)
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFitnessInfoCard() {
    final bool genderInvalid = _currentData['gender'] == null;
    final bool ageInvalid = _currentData['age'] == null;
    final bool expInvalid = _currentData['experience'] == null;
    final bool heightInvalid = _currentData['height'] == null;
    final bool weightInvalid = _currentData['weight'] == null;

    final bool isAnyInvalid = genderInvalid || ageInvalid || expInvalid || heightInvalid || weightInvalid;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _buildInfoRow(Icons.person_outline, 'Gender', _currentData['gender'] ?? 'Man', () {
            _navigateToSelection(GenderSelectionPage(initialValue: _currentData['gender']));
          }, isInvalid: genderInvalid),
          _buildDivider(),
          _buildInfoRow(
            Icons.cake_outlined, 
            'Age', 
            _currentData['age']?.toString() ?? 'Not Selected', 
            () {
              _navigateToSelection(AgeSelectionPage(
                initialValue: _currentData['age'] != null ? int.tryParse(_currentData['age'].toString()) : null,
              ));
            },
            isInvalid: ageInvalid
          ),
          _buildDivider(),
          _buildInfoRow(
            Icons.history, 
            'Experience', 
            _currentData['experience'] != null 
                ? '${_currentData['experience']} ${_currentData['experience'] == 1 ? 'Year' : 'Years'}'
                : 'Not Selected', 
            () {
              _navigateToSelection(ExperienceSelectionPage(initialValue: _currentData['experience']));
            },
            isInvalid: expInvalid
          ),
          _buildDivider(),
          _buildInfoRow(
            Icons.height, 
            'Height', 
            _currentData['height'] != null 
                ? '${double.tryParse(_currentData['height'].toString())?.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '') ?? _currentData['height']}cm' 
                : 'Not Set', 
            () {
              _navigateToSelection(RulerSelectionPage(
                title: 'Height',
                min: 100,
                max: 250,
                initialValue: (_currentData['height'] ?? 170).toDouble(),
                unit: 'cm',
                isVertical: true,
                onSave: (val, unit) => {'height': val},
              ));
            },
            isInvalid: heightInvalid
          ),
          _buildDivider(),
          _buildInfoRow(
            Icons.monitor_weight_outlined, 
            'Weight', 
            _currentData['weight'] != null 
                ? '${double.tryParse(_currentData['weight'].toString())?.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '') ?? _currentData['weight']}${_currentData['weight_unit'] ?? 'kg'}' 
                : 'Not Set', 
            () {
               _navigateToSelection(RulerSelectionPage(
                title: 'Weight',
                min: 30,
                max: 300,
                initialValue: (_currentData['weight'] ?? 70).toDouble(),
                unit: _currentData['weight_unit'] ?? 'kg',
                isVertical: false,
                isWeight: true, 
                onSave: (val, unit) => {'weight': val, 'weight_unit': unit},
              ));
            },
            isInvalid: weightInvalid
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, VoidCallback onTap, {bool isInvalid = false}) {
    final bool showingError = _showValidationErrors && isInvalid;
    final bool isNotSet = value == 'Not Selected' || value == 'Not Set';
    
    return ListTile(
      leading: Icon(icon, color: Colors.white70, size: 20),
      title: Text(label, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value, 
            style: GoogleFonts.poppins(
              color: isNotSet ? Colors.grey : Colors.white, 
              fontSize: 14
            )
          ),
          if (showingError) ...[
            const SizedBox(width: 8),
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
          ],
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: Color(0xFFB497FF), size: 20),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildSimpleCard(String value, VoidCallback onTap, {bool isValid = true}) {
    final bool showingError = _showValidationErrors && !isValid;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
                  ),
                ),
                if (showingError)
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: Color(0xFFB497FF), size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreferencesCard() {
    var prefsRaw = _currentData['preferences'];
    List<dynamic> prefs = [];
    
    if (prefsRaw != null) {
      if (prefsRaw is String) {
        try {
          prefs = jsonDecode(prefsRaw);
        } catch (e) {
          prefs = [];
        }
      } else if (prefsRaw is List) {
        prefs = prefsRaw;
      }
    }

    final bool isInvalid = prefs.isEmpty;
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _navigateToSelection(PreferenceSelectionPage(
            lookingFor: _currentData['looking_for'],
            initialPreferences: List<String>.from(prefs),
          )),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Expanded(
                  child: prefs.isEmpty 
                    ? Text('Not Selected', style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14))
                    : Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: prefs.map<Widget>((p) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF353535),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            p.toString(),
                            style: GoogleFonts.poppins(color: Colors.white, fontSize: 12),
                          ),
                        )).toList(),
                      ),
                ),
                if (_showValidationErrors && isInvalid)
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                const SizedBox(width: 10),
                const Icon(Icons.chevron_right, color: Color(0xFFB497FF), size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvailabilityCard() {
    List availability = [];
    Map<String, String> timeSpans = {};
    
    final availRaw = _currentData['availability'];
    final timeSpansRaw = _currentData['availability_time_spans'];
    
    if (availRaw != null) {
      if (availRaw is String) {
        try { availability = jsonDecode(availRaw); } catch (_) { availability = []; }
      } else if (availRaw is List) {
        availability = availRaw;
      }
    }

    if (timeSpansRaw != null) {
      if (timeSpansRaw is String) {
        try { 
          final decoded = jsonDecode(timeSpansRaw);
          if (decoded is Map) timeSpans = Map<String, String>.from(decoded);
        } catch (_) {}
      } else if (timeSpansRaw is Map) {
        timeSpans = Map<String, String>.from(timeSpansRaw);
      }
    }

    final bool isInvalid = availability.isEmpty;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _navigateToSelection(AvailabilitySelectionPage(
            initialAvailability: List<String>.from(availability.map((e) => e.toString())),
            initialTimeSpans: timeSpans,
          )),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (availability.isEmpty)
                        Text('Not Selected', style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14))
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: availability.map<Widget>((a) {
                            final span = timeSpans[a.toString()];
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF353535),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white.withOpacity(0.05)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_getIconForOption(a.toString()), color: Colors.white70, size: 14),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        a.toString(),
                                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                      ),
                                      if (span != null)
                                        Text(
                                          span,
                                          style: GoogleFonts.poppins(color: const Color(0xFFB497FF), fontSize: 10),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
                if (_showValidationErrors && isInvalid)
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                const SizedBox(width: 10),
                const Icon(Icons.chevron_right, color: Color(0xFFB497FF), size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconForOption(String option) {
    switch (option) {
      case 'Morning': return Icons.wb_sunny_outlined;
      case 'Afternoon': return Icons.wb_cloudy_outlined;
      case 'Evening': return Icons.wb_twilight;
      case 'Night': return Icons.nightlight_round_outlined;
      default: return Icons.access_time;
    }
  }


  Widget _buildDivider() {
    return Divider(color: Colors.white.withValues(alpha: 0.05), height: 1, indent: 16, endIndent: 16);
  }
}
