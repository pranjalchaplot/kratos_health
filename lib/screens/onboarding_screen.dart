import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/soma_provider.dart';
import '../models/user_goals.dart';
import '../theme/soma_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Step 1: Expectations & Focus
  String _selectedFocus = 'Peak Athletic Performance';

  // Step 2: User Stats
  final TextEditingController _nameController = TextEditingController(text: 'SOMA Athlete');
  final TextEditingController _weightController = TextEditingController(text: '75');
  final TextEditingController _heightController = TextEditingController(text: '178');
  final TextEditingController _ageController = TextEditingController(text: '24');
  String _activityLevel = 'Moderate (3-4 workouts/wk)';

  // Step 3: Permissions (Digital Wellbeing & Step Tracker)
  bool _isPermissionRequesting = false;
  bool _isPermissionGranted = false;
  bool _isStepPermissionRequesting = false;
  bool _isStepPermissionGranted = false;
  int _digitalLimitHours = 6;

  // Calculated goals state
  late int _calcCalories;
  late int _calcProtein;
  late int _calcCarbs;
  late int _calcFats;
  late int _calcSteps;
  late double _calcWater;
  late double _calcSleep;

  final List<Map<String, dynamic>> _focusOptions = [
    {
      'title': 'Peak Athletic Performance',
      'subtitle': 'Build strength, muscle hypertrophy, and peak power output.',
      'icon': Icons.bolt,
      'defaultCal': 3200,
      'defaultProtein': 180,
    },
    {
      'title': 'Fat Loss & Body Recomp',
      'subtitle': 'Sustain a controlled calorie deficit with high protein retention.',
      'icon': Icons.local_fire_department,
      'defaultCal': 2400,
      'defaultProtein': 175,
    },
    {
      'title': 'Hyper-Focus & Deep Work',
      'subtitle': 'Optimize mental endurance, screen time control, and recovery.',
      'icon': Icons.psychology,
      'defaultCal': 2600,
      'defaultProtein': 150,
    },
    {
      'title': 'General Vitality & Wellbeing',
      'subtitle': 'Balance daily hydration, steps, sleep, and overall wellness.',
      'icon': Icons.favorite,
      'defaultCal': 2500,
      'defaultProtein': 140,
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _recalculateGoals();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _currentStep == 2) {
      _checkAndAutoFetchPermissions();
    }
  }

  Future<void> _checkAndAutoFetchPermissions() async {
    try {
      final provider = context.read<SomaProvider>();
      final screenTimeSuccess = await provider.syncScreenTimeFromDevice();
      final stepSuccess = await provider.syncStepTrackingFromDevice();
      if (mounted) {
        setState(() {
          _isPermissionGranted = screenTimeSuccess;
          _isStepPermissionGranted = stepSuccess;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _nameController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _recalculateGoals() {
    final double weight = double.tryParse(_weightController.text) ?? 75.0;
    final double height = double.tryParse(_heightController.text) ?? 178.0;
    final int age = int.tryParse(_ageController.text) ?? 24;

    // Estimate BMR using Harris-Benedict / Mifflin-St Jeor simplified
    double bmr = (10 * weight) + (6.25 * height) - (5 * age) + 5;
    
    double activityMultiplier = 1.4;
    if (_activityLevel.contains('Light')) {
      activityMultiplier = 1.25;
    } else if (_activityLevel.contains('Heavy')) {
      activityMultiplier = 1.65;
    }

    double tdee = bmr * activityMultiplier;

    if (_selectedFocus == 'Fat Loss & Body Recomp') {
      _calcCalories = (tdee - 400).round();
      _calcProtein = (weight * 2.2).round();
      _calcSteps = 12000;
    } else if (_selectedFocus == 'Peak Athletic Performance') {
      _calcCalories = (tdee + 300).round();
      _calcProtein = (weight * 2.0).round();
      _calcSteps = 10000;
    } else if (_selectedFocus == 'Hyper-Focus & Deep Work') {
      _calcCalories = tdee.round();
      _calcProtein = (weight * 1.8).round();
      _calcSteps = 8000;
    } else {
      _calcCalories = tdee.round();
      _calcProtein = (weight * 1.6).round();
      _calcSteps = 10000;
    }

    _calcFats = ((_calcCalories * 0.25) / 9).round();
    _calcCarbs = ((_calcCalories - (_calcProtein * 4) - (_calcFats * 9)) / 4).round().clamp(100, 600);
    _calcWater = double.parse((weight * 0.045).toStringAsFixed(1)).clamp(2.5, 6.0);
    _calcSleep = 8.0;
  }

  void _nextPage() {
    if (_currentStep < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _requestDigitalWellbeingPermission() async {
    setState(() {
      _isPermissionRequesting = true;
    });

    try {
      final success = await context.read<SomaProvider>().syncScreenTimeFromDevice();
      setState(() {
        _isPermissionGranted = success;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Digital Wellbeing Permission Granted & Usage Synced!'
                  : 'Usage stats queried. Ensure permission is enabled in Android Settings.',
            ),
            backgroundColor: success ? SomaColors.primaryContainer : SomaColors.surfaceContainerHigh,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not sync usage stats: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPermissionRequesting = false;
        });
      }
    }
  }

  Future<void> _requestStepPermission() async {
    setState(() {
      _isStepPermissionRequesting = true;
    });

    try {
      final success = await context.read<SomaProvider>().requestStepPermission();
      setState(() {
        _isStepPermissionGranted = success;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Physical Activity Permission Granted! Auto step counting active.'
                  : 'Step permission not granted. You can still log steps manually or enable it later.',
            ),
            backgroundColor: success ? SomaColors.primaryContainer : SomaColors.surfaceContainerHigh,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not request step permission: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isStepPermissionRequesting = false;
        });
      }
    }
  }

  Future<void> _finishOnboarding() async {
    _recalculateGoals();

    final userGoals = UserGoals(
      caloriesGoal: _calcCalories,
      proteinGoal: _calcProtein,
      carbsGoal: _calcCarbs,
      fatsGoal: _calcFats,
      stepsGoal: _calcSteps,
      waterGoal: _calcWater,
      sleepGoal: _calcSleep,
      digitalGoalHours: _digitalLimitHours,
      weightKg: double.tryParse(_weightController.text) ?? 75.0,
      heightCm: double.tryParse(_heightController.text) ?? 178.0,
      age: int.tryParse(_ageController.text) ?? 24,
      primaryFocus: _selectedFocus,
      userName: _nameController.text.trim().isEmpty ? 'SOMA Athlete' : _nameController.text.trim(),
    );

    await context.read<SomaProvider>().completeOnboarding(userGoals);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SomaColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with progress
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.asset(
                          'asset/icon_data/playstore.png',
                          width: 24,
                          height: 24,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'SOMA',
                        style: TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                          color: SomaColors.primaryContainer,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    'STEP ${_currentStep + 1} OF 4',
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: SomaColors.onSecondaryContainer,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),

            // Progress indicator bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: List.generate(4, (index) {
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(right: index == 3 ? 0 : 8),
                      decoration: BoxDecoration(
                        color: index <= _currentStep
                            ? SomaColors.primaryContainer
                            : SomaColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 12),

            // PageView Content
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentStep = index;
                  });
                  if (index == 2) {
                    _checkAndAutoFetchPermissions();
                  }
                },
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildExpectationsStep(),
                  _buildStatsStep(),
                  _buildDigitalWellbeingStep(),
                  _buildActivationStep(),
                ],
              ),
            ),

            // Bottom Navigation Buttons
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    IconButton(
                      onPressed: _previousPage,
                      icon: const Icon(Icons.arrow_back_ios_new, color: SomaColors.onSurface),
                      style: IconButton.styleFrom(
                        backgroundColor: SomaColors.cardBackground,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: SomaColors.cardBorder),
                        ),
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SomaColors.primaryContainer,
                          foregroundColor: Colors.black,
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () {
                          if (_currentStep == 3) {
                            _finishOnboarding();
                          } else {
                            if (_currentStep == 1) {
                              _recalculateGoals();
                            }
                            _nextPage();
                          }
                        },
                        child: Text(
                          _currentStep == 3
                              ? 'INITIALIZE SOMA ENGINE'
                              : 'CONTINUE TO NEXT STEP',
                          style: const TextStyle(
                            fontFamily: 'Geist',
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- STEP 1: Expectations & Focus ---
  Widget _buildExpectationsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'EXPECTATIONS & FOCUS',
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: SomaColors.primaryContainer,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'What is your primary objective?',
            style: TextStyle(
              fontFamily: 'Geist',
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: SomaColors.onSurface,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select the target profile that aligns with your active goals. We will tailor your daily performance metrics accordingly.',
            style: TextStyle(
              fontFamily: 'Geist',
              fontSize: 14,
              color: SomaColors.secondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          ..._focusOptions.map((opt) {
            final isSelected = _selectedFocus == opt['title'];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedFocus = opt['title'];
                    _recalculateGoals();
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? SomaColors.primaryContainer.withValues(alpha: 0.1)
                        : SomaColors.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? SomaColors.primaryContainer
                          : SomaColors.cardBorder,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? SomaColors.primaryContainer
                              : SomaColors.surfaceContainerHigh,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          opt['icon'] as IconData,
                          color: isSelected ? Colors.black : SomaColors.primaryContainer,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              opt['title'],
                              style: TextStyle(
                                fontFamily: 'Geist',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? SomaColors.primaryContainer
                                    : SomaColors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              opt['subtitle'],
                              style: const TextStyle(
                                fontFamily: 'Geist',
                                fontSize: 12,
                                color: SomaColors.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check_circle,
                          color: SomaColors.primaryContainer,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // --- STEP 2: Current Stats & Physical Baseline ---
  Widget _buildStatsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PHYSICAL BASELINE',
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: SomaColors.primaryContainer,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your Current Stats',
            style: TextStyle(
              fontFamily: 'Geist',
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: SomaColors.onSurface,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter your current physical stats to compute your baseline energy expenditure and macronutrient requirements.',
            style: TextStyle(
              fontFamily: 'Geist',
              fontSize: 14,
              color: SomaColors.secondary,
            ),
          ),
          const SizedBox(height: 20),

          // Name
          _buildTextField('Athlete Name / Alias', _nameController, TextInputType.name, icon: Icons.person),
          const SizedBox(height: 14),

          // Row for Weight, Height, Age
          Row(
            children: [
              Expanded(
                child: _buildTextField('Weight (kg)', _weightController, TextInputType.number, onChanged: (_) => setState(_recalculateGoals)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField('Height (cm)', _heightController, TextInputType.number, onChanged: (_) => setState(_recalculateGoals)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField('Age', _ageController, TextInputType.number, onChanged: (_) => setState(_recalculateGoals)),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Text(
            'Daily Activity Level',
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: SomaColors.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              'Light (Desk job, 1-2 workouts/wk)',
              'Moderate (3-4 workouts/wk)',
              'Heavy (Intense training 5+ days/wk)'
            ].map((level) {
              final isSel = _activityLevel == level;
              return ChoiceChip(
                label: Text(
                  level,
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 12,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    color: isSel ? Colors.black : SomaColors.onSurface,
                  ),
                ),
                selected: isSel,
                selectedColor: SomaColors.primaryContainer,
                backgroundColor: SomaColors.cardBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSel ? SomaColors.primaryContainer : SomaColors.cardBorder,
                  ),
                ),
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _activityLevel = level;
                      _recalculateGoals();
                    });
                  }
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 24),
          // Preview Card for recalculated goals
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SomaColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SomaColors.primaryContainer.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: SomaColors.primaryContainer, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'RECOMMENDED BASELINE TARGETS',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: SomaColors.primaryContainer,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatChip('Calories', '$_calcCalories kcal'),
                    _buildStatChip('Protein', '${_calcProtein}g'),
                    _buildStatChip('Water', '${_calcWater}L'),
                    _buildStatChip('Steps', '$_calcSteps'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- STEP 3: System Permissions & Integrations ---
  Widget _buildDigitalWellbeingStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DEVICE PERMISSIONS & INTEGRATIONS',
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: SomaColors.primaryContainer,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Automated Activity & Discipline',
            style: TextStyle(
              fontFamily: 'Geist',
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: SomaColors.onSurface,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Grant permissions so SOMA can auto-detect your daily steps and screen time without requiring manual entry.',
            style: TextStyle(
              fontFamily: 'Geist',
              fontSize: 14,
              color: SomaColors.secondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // 1. Digital Wellbeing Permission Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SomaColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isPermissionGranted ? SomaColors.primaryContainer : SomaColors.cardBorder,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _isPermissionGranted
                            ? SomaColors.primaryContainer.withValues(alpha: 0.2)
                            : SomaColors.surfaceContainerHigh,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isPermissionGranted ? Icons.verified_user : Icons.phonelink_setup,
                        color: _isPermissionGranted ? SomaColors.primaryContainer : SomaColors.secondary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isPermissionGranted
                                ? 'Digital Wellbeing Connected'
                                : 'Usage Stats Permission',
                            style: const TextStyle(
                              fontFamily: 'Geist',
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: SomaColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isPermissionGranted
                                ? 'App usage syncs automatically into daily dashboard.'
                                : 'Grant access to track daily screen-on time.',
                            style: const TextStyle(
                              fontFamily: 'Geist',
                              fontSize: 12,
                              color: SomaColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isPermissionGranted
                          ? SomaColors.surfaceContainerHigh
                          : SomaColors.primaryContainer,
                      foregroundColor: _isPermissionGranted ? SomaColors.onSurface : Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isPermissionRequesting ? null : _requestDigitalWellbeingPermission,
                    icon: _isPermissionRequesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : Icon(_isPermissionGranted ? Icons.check : Icons.lock_open, size: 18),
                    label: Text(
                      _isPermissionGranted ? 'PERMISSIONS ACTIVE' : 'ALLOW DIGITAL WELLBEING',
                      style: const TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 2. Physical Activity & Step Counter Permission Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SomaColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isStepPermissionGranted ? SomaColors.primaryContainer : SomaColors.cardBorder,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _isStepPermissionGranted
                            ? SomaColors.primaryContainer.withValues(alpha: 0.2)
                            : SomaColors.surfaceContainerHigh,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isStepPermissionGranted ? Icons.directions_walk : Icons.directions_walk_outlined,
                        color: _isStepPermissionGranted ? SomaColors.primaryContainer : SomaColors.secondary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isStepPermissionGranted
                                ? 'Auto Step Counter Active'
                                : 'Physical Activity Permission',
                            style: const TextStyle(
                              fontFamily: 'Geist',
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: SomaColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isStepPermissionGranted
                                ? 'Hardware pedometer counting live steps 24/7.'
                                : 'Allow device pedometer to auto-detect steps.',
                            style: const TextStyle(
                              fontFamily: 'Geist',
                              fontSize: 12,
                              color: SomaColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isStepPermissionGranted
                          ? SomaColors.surfaceContainerHigh
                          : SomaColors.primaryContainer,
                      foregroundColor: _isStepPermissionGranted ? SomaColors.onSurface : Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isStepPermissionRequesting ? null : _requestStepPermission,
                    icon: _isStepPermissionRequesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : Icon(_isStepPermissionGranted ? Icons.check : Icons.directions_run, size: 18),
                    label: Text(
                      _isStepPermissionGranted ? 'STEP COUNTER CONNECTED' : 'ENABLE AUTO STEP TRACKER',
                      style: const TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Text(
            'Target Daily Screen Limit (Hours)',
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: SomaColors.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: SomaColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SomaColors.cardBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.screen_search_desktop, color: SomaColors.primaryContainer),
                const SizedBox(width: 16),
                Expanded(
                  child: Slider(
                    value: _digitalLimitHours.toDouble(),
                    min: 1,
                    max: 12,
                    divisions: 11,
                    activeColor: SomaColors.primaryContainer,
                    inactiveColor: SomaColors.surfaceContainerHigh,
                    label: '$_digitalLimitHours Hours',
                    onChanged: (val) {
                      setState(() {
                        _digitalLimitHours = val.round();
                      });
                    },
                  ),
                ),
                Text(
                  '${_digitalLimitHours}h / day',
                  style: const TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: SomaColors.primaryContainer,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const Center(
            child: Text(
              'Note: You can adjust this or update permissions anytime in Profile Settings.',
              style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 12,
                color: SomaColors.secondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // --- STEP 4: Activation & Confirmation ---
  Widget _buildActivationStep() {
    final name = _nameController.text.trim().isEmpty ? 'SOMA Athlete' : _nameController.text.trim();
    final weight = _weightController.text.trim();
    final height = _heightController.text.trim();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SYSTEM ACTIVATION',
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: SomaColors.primaryContainer,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ready to Dominate',
            style: TextStyle(
              fontFamily: 'Geist',
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: SomaColors.onSurface,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Review your performance blueprint below. Everything is configured and ready for execution.',
            style: TextStyle(
              fontFamily: 'Geist',
              fontSize: 14,
              color: SomaColors.secondary,
            ),
          ),
          const SizedBox(height: 20),

          // Overview Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: SomaColors.cardBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: SomaColors.primaryContainer),
              boxShadow: [
                BoxShadow(
                  color: SomaColors.primaryContainer.withValues(alpha: 0.08),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shield, color: SomaColors.primaryContainer, size: 28),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.toUpperCase(),
                          style: const TextStyle(
                            fontFamily: 'Geist',
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: SomaColors.onSurface,
                          ),
                        ),
                        Text(
                          '$weight kg • $height cm • $_selectedFocus',
                          style: const TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 11,
                            color: SomaColors.primaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(color: SomaColors.cardBorder, height: 28),
                const Text(
                  'DAILY PERFORMANCE TARGETS',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: SomaColors.onSecondaryContainer,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 12),
                _buildSummaryRow('Energy Target', '$_calcCalories kcal / day', Icons.local_fire_department),
                _buildSummaryRow('Protein Target', '$_calcProtein g / day', Icons.fitness_center),
                _buildSummaryRow('Carbs & Fats', '$_calcCarbs g C / $_calcFats g F', Icons.restaurant),
                _buildSummaryRow('Hydration Target', '$_calcWater Liters / day', Icons.water_drop),
                _buildSummaryRow('Daily Activity', '$_calcSteps Steps / day', Icons.directions_walk),
                _buildSummaryRow('Digital Limit', '$_digitalLimitHours Hours Max', Icons.screen_lock_portrait),
                _buildSummaryRow('Screen Sync', _isPermissionGranted ? 'Active & Permitted' : 'Manual / Pending', Icons.phonelink_setup),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: SomaColors.primaryContainer),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Geist',
              fontSize: 13,
              color: SomaColors.secondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: SomaColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String title, String val) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Geist',
            fontSize: 11,
            color: SomaColors.secondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          val,
          style: const TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: SomaColors.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    TextInputType keyboardType, {
    IconData? icon,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: SomaColors.onSecondaryContainer,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: onChanged,
          style: const TextStyle(
            fontFamily: 'Geist',
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: SomaColors.onSurface,
          ),
          decoration: InputDecoration(
            prefixIcon: icon != null ? Icon(icon, color: SomaColors.primaryContainer, size: 20) : null,
            filled: true,
            fillColor: SomaColors.cardBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: SomaColors.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: SomaColors.cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: SomaColors.primaryContainer),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}
