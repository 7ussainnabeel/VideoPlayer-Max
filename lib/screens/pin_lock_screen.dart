import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import '../constants/styles.dart';
import '../providers/media_library_manager.dart';
import '../widgets/glass_background.dart';
import '../widgets/glass_container.dart';

class PinLockScreen extends StatefulWidget {
  final VoidCallback? onUnlocked;
  final bool forceSetupMode;

  const PinLockScreen({
    super.key,
    this.onUnlocked,
    this.forceSetupMode = false,
  });

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  final LocalAuthentication _auth = LocalAuthentication();
  final List<int> _enteredPin = [];
  
  bool _isSetupMode = false;
  String _tempPin = '';
  String _message = 'Enter Passcode';
  bool _canCheckBiometrics = false;

  @override
  void initState() {
    super.initState();
    _isSetupMode = widget.forceSetupMode;
    if (_isSetupMode) {
      _message = 'Set 4-Digit Passcode';
    } else {
      _checkBiometrics();
    }
  }

  Future<void> _checkBiometrics() async {
    try {
      final isSupported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      if (!mounted) return;
      setState(() {
        _canCheckBiometrics = isSupported && canCheck;
      });

      // Automatically authenticate with biometrics if a PIN is already set
      final libManager = Provider.of<MediaLibraryManager>(context, listen: false);
      if (libManager.appLockPin != null && libManager.appLockPin!.isNotEmpty && _canCheckBiometrics) {
        _authenticateWithBiometrics();
      }
    } catch (e) {
      debugPrint("Error checking biometrics: $e");
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    try {
      final didAuthenticate = await _auth.authenticate(
        localizedReason: 'Unlock VideoPlayer Max',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      if (didAuthenticate) {
        _handleUnlockSuccess();
      }
    } on Exception catch (e) {
      debugPrint("Biometric auth exception: $e");
    }
  }

  void _handleUnlockSuccess() {
    final libManager = Provider.of<MediaLibraryManager>(context, listen: false);
    libManager.unlockApp();
    if (widget.onUnlocked != null) {
      widget.onUnlocked!();
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _onKeyPress(int number) {
    if (_enteredPin.length >= 4) return;
    setState(() {
      _enteredPin.add(number);
      
      if (_enteredPin.length == 4) {
        _processPinInput();
      }
    });
  }

  void _onDeletePress() {
    if (_enteredPin.isEmpty) return;
    setState(() {
      _enteredPin.removeLast();
    });
  }

  void _processPinInput() {
    final enteredPinStr = _enteredPin.join();
    final libManager = Provider.of<MediaLibraryManager>(context, listen: false);
    final savedPin = libManager.appLockPin;

    if (_isSetupMode) {
      if (_tempPin.isEmpty) {
        // First step of setup: store temp PIN and prompt for confirmation
        _tempPin = enteredPinStr;
        _enteredPin.clear();
        _message = 'Confirm Passcode';
      } else {
        // Second step of setup: check if PINs match
        if (_tempPin == enteredPinStr) {
          libManager.setAppLockPin(enteredPinStr);
          _handleUnlockSuccess();
        } else {
          // Restart setup
          HapticFeedback.vibrate();
          _tempPin = '';
          _enteredPin.clear();
          _message = 'Passcodes do not match. Set Passcode';
        }
      }
    } else {
      // Unlock Mode
      if (savedPin == enteredPinStr) {
        _handleUnlockSuccess();
      } else {
        HapticFeedback.vibrate();
        _enteredPin.clear();
        _message = 'Incorrect Passcode';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final libManager = Provider.of<MediaLibraryManager>(context);
    final isPinSet = libManager.appLockPin != null && libManager.appLockPin!.isNotEmpty;

    if (!isPinSet && !_isSetupMode) {
      _isSetupMode = true;
      _message = 'Set 4-Digit Passcode';
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Screen Header/Title
                  Column(
                    children: [
                      const Icon(
                        Icons.lock_outline,
                        color: Colors.white,
                        size: 60,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'VideoPlayer Max',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _message,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  // PIN Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      final filled = index < _enteredPin.length;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: filled ? AppStyles.primaryRed : Colors.transparent,
                          border: Border.all(
                            color: Colors.white60,
                            width: 1.5,
                          ),
                        ),
                      );
                    }),
                  ),

                  // Glass Keypad Layout
                  Center(
                    child: GlassContainer(
                      width: MediaQuery.of(context).size.width * 0.85,
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildNumberButton(1),
                              _buildNumberButton(2),
                              _buildNumberButton(3),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildNumberButton(4),
                              _buildNumberButton(5),
                              _buildNumberButton(6),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildNumberButton(7),
                              _buildNumberButton(8),
                              _buildNumberButton(9),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Biometrics / Clear button
                              _canCheckBiometrics && isPinSet
                                  ? _buildIconButton(
                                      icon: Icons.face_retouching_natural,
                                      onPressed: _authenticateWithBiometrics,
                                    )
                                  : const SizedBox(width: 70, height: 70),
                              _buildNumberButton(0),
                              _buildIconButton(
                                icon: Icons.backspace_outlined,
                                onPressed: _onDeletePress,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (Navigator.of(context).canPop())
                Positioned(
                  top: 0,
                  left: 8,
                  child: IconButton(
                    icon: const Icon(CupertinoIcons.back, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumberButton(int number) {
    return SizedBox(
      width: 70,
      height: 70,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
          shape: const CircleBorder(),
          backgroundColor: Colors.white.withValues(alpha: 0.05),
          padding: EdgeInsets.zero,
        ),
        onPressed: () => _onKeyPress(number),
        child: Text(
          '$number',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({required IconData icon, required VoidCallback onPressed}) {
    return SizedBox(
      width: 70,
      height: 70,
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 28),
        onPressed: onPressed,
      ),
    );
  }
}
