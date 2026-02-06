import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'models/center_material.dart' show CenterMaterialEntry, getMaterialIcon, kMaterialTypes;
import 'providers/center_auth_provider.dart';
import 'services/center_firestore_service.dart';
import 'widgets/address_map_picker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const CenterWebApp());
}

class CenterWebApp extends StatelessWidget {
  const CenterWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CenterAuthProvider(),
      child: MaterialApp(
        title: 'KitaKitar Center',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        home: const _RootShell(),
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    const primary = Color(0xFF0D9488);
    const secondary = Color(0xFF065F46);

    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: secondary,
        brightness: brightness,
      ),
      useMaterial3: true,
    );

    return base.copyWith(
      scaffoldBackgroundColor:
          brightness == Brightness.light ? const Color(0xFFF0FDF4) : null,
      textTheme: base.textTheme.apply(
        fontFamily: 'Roboto',
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

enum _AuthMode { login, register, forgot }
/// Root shell that switches between auth and dashboard, опираясь на CenterAuthProvider.
class _RootShell extends StatefulWidget {
  const _RootShell();

  @override
  State<_RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<_RootShell> {
  _AuthMode _authMode = _AuthMode.login;

  void _switchAuthMode(_AuthMode mode) {
    setState(() {
      _authMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<CenterAuthProvider>(context);

    if (!auth.isAuthenticated) {
      switch (_authMode) {
        case _AuthMode.login:
          return LoginPage(
            onGoToRegister: () => _switchAuthMode(_AuthMode.register),
            onGoToForgot: () => _switchAuthMode(_AuthMode.forgot),
          );
        case _AuthMode.register:
          return RegisterCenterPage(
            onGoToLogin: () => _switchAuthMode(_AuthMode.login),
          );
        case _AuthMode.forgot:
          return ForgotPasswordPage(
            onBackToLogin: () => _switchAuthMode(_AuthMode.login),
          );
      }
    }

    return DashboardShell(
      onLogout: () => auth.signOut(),
    );
  }
}

/// -----------------------
/// AUTH SCREENS
/// -----------------------

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.onGoToRegister,
    required this.onGoToForgot,
  });

  final VoidCallback onGoToRegister;
  final VoidCallback onGoToForgot;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter email and password')),
      );
      return;
    }

    final auth = Provider.of<CenterAuthProvider>(context, listen: false);
    final success = await auth.signInWithEmail(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!success && mounted && auth.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = Provider.of<CenterAuthProvider>(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D9488), Color(0xFF065F46), Color(0xFF1E3A2F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 16,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(32),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _LogoHeader(
                      title: 'KitaKitar Center',
                      subtitle: 'Admin panel for recycling centers',
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Log in to your center',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _EmailField(controller: _emailController),
                    const SizedBox(height: 12),
                    _PasswordField(
                      controller: _passwordController,
                      obscure: _obscurePassword,
                      onToggleObscure: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: auth.isLoading ? null : _handleLogin,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: auth.isLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Sign in'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: widget.onGoToForgot,
                      child: const Text('Forgot password?'),
                    ),
                    const Divider(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Don't have a center yet?"),
                        TextButton(
                          onPressed: widget.onGoToRegister,
                          child: const Text('Create account'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterCenterPage extends StatefulWidget {
  const RegisterCenterPage({
    super.key,
    required this.onGoToLogin,
  });

  final VoidCallback onGoToLogin;

  @override
  State<RegisterCenterPage> createState() => _RegisterCenterPageState();
}

class _RegisterCenterPageState extends State<RegisterCenterPage> {
  final _centerNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _managerNameController = TextEditingController();
  final _managerPhoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  double? _lat;
  double? _lng;
  bool _isSubmitting = false;
  /// type -> (minKg, maxKg, pricePerKg); только выбранные материалы.
  final Map<String, ({double minKg, double maxKg, double pricePerKg})> _materials = {};

  @override
  void dispose() {
    _centerNameController.dispose();
    _addressController.dispose();
    _managerNameController.dispose();
    _managerPhoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onLocationSelected(double lat, double lng, String address) {
    setState(() {
      _lat = lat;
      _lng = lng;
      _addressController.text = address;
    });
  }

  Future<void> _submit() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a point on the map and/or enter an address.'),
        ),
      );
      return;
    }
    if (_lat == null || _lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter an address (suggestions as you type) or tap on the map.'),
        ),
      );
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }
    final centerName = _centerNameController.text.trim();
    final managerName = _managerNameController.text.trim();
    final managerPhone = _managerPhoneController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (centerName.isEmpty || managerName.isEmpty || managerPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fill in center name and manager details.'),
        ),
      );
      return;
    }
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter email and password for the center account.'),
        ),
      );
      return;
    }
    if (_materials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one accepted material type.'),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final auth = Provider.of<CenterAuthProvider>(context, listen: false);
      final success = await auth.registerWithEmail(email, password);

      if (!success || auth.user == null) {
        setState(() {
          _isSubmitting = false;
        });
        if (auth.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(auth.error!)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to register the center.')),
          );
        }
        return;
      }

      final user = auth.user!;
      final firestore = CenterFirestoreService();

      final materialsList = _materials.entries.map((e) {
        final label = kMaterialTypes.firstWhere((t) => t['type'] == e.key)['label'] ?? e.key;
        return CenterMaterialEntry(
          type: e.key,
          label: label,
          minWeightKg: e.value.minKg,
          maxWeightKg: e.value.maxKg,
          pricePerKg: e.value.pricePerKg,
        );
      }).toList();

      await firestore.createCenter(
        centerId: user.uid,
        name: centerName,
        address: address,
        lat: _lat!,
        lng: _lng!,
        managerName: managerName,
        managerPhone: managerPhone,
        managerEmail: user.email ?? email,
        materials: materialsList,
      );

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Center registered successfully.')),
      );
      // После успешной регистрации auth.isAuthenticated уже true,
      // _RootShell автоматически переведёт пользователя в Dashboard.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D9488), Color(0xFF065F46), Color(0xFF1E3A2F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Card(
              elevation: 16,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(32),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const _LogoHeader(
                              title: 'Register center',
                              subtitle:
                                  'Join KitaKitar network and start accepting recyclable materials.',
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Why join?',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            const _BulletPoint(
                              text:
                                  'Configure accepted materials, weight ranges and pricing.',
                            ),
                            const _BulletPoint(
                              text:
                                  'Generate one-time QR codes for every accepted load.',
                            ),
                            const _BulletPoint(
                              text:
                                  'Track statistics and points for your center in real time.',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(left: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Center details',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            _LabeledTextField(
                              controller: _centerNameController,
                              label: 'Center name',
                              hint: 'Green Earth Recycling',
                            ),
                            const SizedBox(height: 16),
                            AddressMapPicker(
                              initialAddress: _addressController.text.isEmpty
                                  ? null
                                  : _addressController.text,
                              initialLat: _lat,
                              initialLng: _lng,
                              onLocationSelected: _onLocationSelected,
                              height: 220,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Manager',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _LabeledTextField(
                                    controller: _managerNameController,
                                    label: 'Name',
                                    hint: 'John Smith',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _LabeledTextField(
                                    controller: _managerPhoneController,
                                    label: 'Phone',
                                    hint: '+998 90 123 45 67',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Accepted materials',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Select types and set min/max weight (kg) and price per kg (0 = free).',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...kMaterialTypes.map((mat) {
                              final type = mat['type']!;
                              final label = mat['label']!;
                              final isSelected = _materials.containsKey(type);
                              final params = _materials[type] ?? (minKg: 0.5, maxKg: 100.0, pricePerKg: 0.0);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _MaterialRow(
                                  icon: getMaterialIcon(type),
                                  label: label,
                                  selected: isSelected,
                                  minKg: isSelected ? params.minKg : 0.5,
                                  maxKg: isSelected ? params.maxKg : 100.0,
                                  pricePerKg: isSelected ? params.pricePerKg : 0.0,
                                  onChanged: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _materials[type] = (minKg: 0.5, maxKg: 100.0, pricePerKg: 0.0);
                                      } else {
                                        _materials.remove(type);
                                      }
                                    });
                                  },
                                  onMinChanged: (v) {
                                    setState(() {
                                      final p = _materials[type]!;
                                      _materials[type] = (minKg: v, maxKg: p.maxKg, pricePerKg: p.pricePerKg);
                                    });
                                  },
                                  onMaxChanged: (v) {
                                    setState(() {
                                      final p = _materials[type]!;
                                      _materials[type] = (minKg: p.minKg, maxKg: v, pricePerKg: p.pricePerKg);
                                    });
                                  },
                                  onPriceChanged: (v) {
                                    setState(() {
                                      final p = _materials[type]!;
                                      _materials[type] = (minKg: p.minKg, maxKg: p.maxKg, pricePerKg: v);
                                    });
                                  },
                                ),
                              );
                            }),
                            const SizedBox(height: 16),
                            Text(
                              'Account',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            _LabeledTextField(
                              controller: _emailController,
                              label: 'Email',
                              hint: 'center@example.com',
                            ),
                            const SizedBox(height: 12),
                            _LabeledTextField(
                              controller: _passwordController,
                              label: 'Password',
                              hint: '••••••••',
                              obscure: true,
                            ),
                            const SizedBox(height: 12),
                            _LabeledTextField(
                              controller: _confirmPasswordController,
                              label: 'Confirm password',
                              hint: '••••••••',
                              obscure: true,
                            ),
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: _isSubmitting ? null : _submit,
                              style: FilledButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text('Create center account'),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: widget.onGoToLogin,
                              child: const Text('Already have account? Log in'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ForgotPasswordPage extends StatelessWidget {
  const ForgotPasswordPage({
    super.key,
    required this.onBackToLogin,
  });

  final VoidCallback onBackToLogin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D9488), Color(0xFF065F46), Color(0xFF1E3A2F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 16,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(32),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _LogoHeader(
                      title: 'Reset password',
                      subtitle:
                          'Enter your email, we will send reset instructions.',
                    ),
                    const SizedBox(height: 24),
                    const _EmailField(),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'If an account exists, reset link will be sent.',
                            ),
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Send reset link'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: onBackToLogin,
                      child: const Text('Back to login'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// -----------------------
/// DASHBOARD SHELL
/// -----------------------

enum _DashboardPage { dashboard, profile, newIntake, qrCodes, history }

class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  _DashboardPage _page = _DashboardPage.dashboard;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _Sidebar(
            current: _page,
            onSelect: (p) => setState(() => _page = p),
            onLogout: widget.onLogout,
          ),
          Expanded(
            child: Container(
              color: const Color(0xFFF1F5F9),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _buildPage(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage() {
    switch (_page) {
      case _DashboardPage.dashboard:
        return const _DashboardPageView();
      case _DashboardPage.profile:
        return const _ProfilePageView();
      case _DashboardPage.newIntake:
        return const _NewIntakePageView();
      case _DashboardPage.qrCodes:
        return const _QrCodesPageView();
      case _DashboardPage.history:
        return const _HistoryPageView();
    }
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.current,
    required this.onSelect,
    required this.onLogout,
  });

  final _DashboardPage current;
  final ValueChanged<_DashboardPage> onSelect;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      color: Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D9488), Color(0xFF065F46)],
                    ),
                  ),
                  child: const Icon(
                    Icons.loop_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KitaKitar',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      'Center admin',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _SidebarItem(
                  icon: Icons.space_dashboard_outlined,
                  label: 'Dashboard',
                  selected: current == _DashboardPage.dashboard,
                  onTap: () => onSelect(_DashboardPage.dashboard),
                ),
                _SidebarItem(
                  icon: Icons.storefront_outlined,
                  label: 'Center profile',
                  selected: current == _DashboardPage.profile,
                  onTap: () => onSelect(_DashboardPage.profile),
                ),
                _SidebarItem(
                  icon: Icons.add_circle_outline,
                  label: 'New intake',
                  selected: current == _DashboardPage.newIntake,
                  onTap: () => onSelect(_DashboardPage.newIntake),
                ),
                _SidebarItem(
                  icon: Icons.qr_code_2_outlined,
                  label: 'QR codes',
                  selected: current == _DashboardPage.qrCodes,
                  onTap: () => onSelect(_DashboardPage.qrCodes),
                ),
                _SidebarItem(
                  icon: Icons.history_rounded,
                  label: 'History',
                  selected: current == _DashboardPage.history,
                  onTap: () => onSelect(_DashboardPage.history),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: OutlinedButton.icon(
              onPressed: onLogout,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade600,
                side: BorderSide(color: Colors.red.shade200),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign out'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: selected
                ? colorScheme.primary.withOpacity(0.12)
                : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: selected ? colorScheme.primary : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? colorScheme.primary : Colors.grey.shade600,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color:
                      selected ? colorScheme.primary : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// -----------------------
/// DASHBOARD PAGES (UI ONLY)
/// -----------------------

class _DashboardPageView extends StatelessWidget {
  const _DashboardPageView();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome back!',
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Your recycling center overview',
          style: textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: const [
            _StatCard(
              title: 'Total intakes',
              value: '0',
              icon: Icons.insert_drive_file_outlined,
              color: Color(0xFF0D9488),
            ),
            _StatCard(
              title: 'Total weight',
              value: '0.0 kg',
              icon: Icons.scale_outlined,
              color: Color(0xFF10B981),
            ),
            _StatCard(
              title: 'Points issued',
              value: '0',
              icon: Icons.stars_rounded,
              color: Color(0xFFF59E0B),
            ),
            _StatCard(
              title: 'Claimed QR codes',
              value: '0',
              icon: Icons.qr_code_2_outlined,
              color: Color(0xFF8B5CF6),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Center(
              child: Text(
                'Recent intakes and analytics will appear here\n'
                '(connect to Firestore `/transactions` later).',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium
                    ?.copyWith(color: Colors.grey.shade500),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfilePageView extends StatelessWidget {
  const _ProfilePageView();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Center profile',
            style:
                textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Update center information and manager contacts.',
            style: textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: const [
                  _SectionTitle('Center information'),
                  SizedBox(height: 12),
                  _LabeledTextField(
                    label: 'Center name',
                    hint: 'Green Earth Recycling',
                  ),
                  SizedBox(height: 12),
                  _LabeledTextField(
                    label: 'Address',
                    hint: 'City, street, building...',
                    icon: Icons.location_on_outlined,
                  ),
                  SizedBox(height: 24),
                  _SectionTitle('Manager'),
                  SizedBox(height: 12),
                  _LabeledTextField(
                    label: 'Manager name',
                    hint: 'John Smith',
                  ),
                  SizedBox(height: 12),
                  _LabeledTextField(
                    label: 'Manager phone',
                    hint: '+998 90 123 45 67',
                  ),
                  SizedBox(height: 24),
                  _SectionTitle('Accepted materials (read-only placeholder)'),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ChipTag(label: 'Plastic • \$1.2/kg'),
                      _ChipTag(label: 'Glass • \$0.8/kg'),
                      _ChipTag(label: 'Paper • free'),
                    ],
                  ),
                  SizedBox(height: 24),
                  _PrimarySaveButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewIntakePageView extends StatelessWidget {
  const _NewIntakePageView();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'New intake',
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Register fact of waste acceptance and generate QR code.',
          style: textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _SectionTitle('Material'),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: const [
                            _MaterialPill(icon: '🥤', label: 'Plastic'),
                            _MaterialPill(icon: '📄', label: 'Paper'),
                            _MaterialPill(icon: '🍾', label: 'Glass'),
                            _MaterialPill(icon: '🥫', label: 'Metal'),
                            _MaterialPill(icon: '📱', label: 'Electronics'),
                            _MaterialPill(icon: '🔋', label: 'Batteries'),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const _SectionTitle('Actual weight'),
                        const SizedBox(height: 12),
                        const _LabeledTextField(
                          label: 'Weight (kg)',
                          hint: 'Enter actual weight, e.g. 3.5',
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Min / max per material and dynamic hints can be connected\n'
                          'to Firestore `/centers/{centerId}/materials` later.',
                          style: textTheme.bodySmall
                              ?.copyWith(color: Colors.grey.shade500),
                        ),
                        const SizedBox(height: 24),
                        const _PrimarySaveButton(
                          label: 'Generate QR code',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 2,
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _SectionTitle('QR code preview'),
                        const SizedBox(height: 12),
                        Container(
                          height: 220,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            color: Colors.grey.shade100,
                          ),
                          child: Center(
                            child: Text(
                              'QR preview will be rendered here\n'
                              '(connect `qr_flutter` and `/qr_codes` later).',
                              textAlign: TextAlign.center,
                              style: textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Client scans this QR in mobile app to receive points.\n'
                          'Each QR should be one-time and linked to `/transactions`.',
                          style: textTheme.bodySmall
                              ?.copyWith(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QrCodesPageView extends StatelessWidget {
  const _QrCodesPageView();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QR codes',
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Track pending and claimed QR codes.',
          style: textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle('Pending QR codes'),
                        const SizedBox(height: 12),
                        Expanded(
                          child: Center(
                            child: Text(
                              'List of not-yet-scanned QR codes\n'
                              '(Firestore `/qr_codes` where `used == false`).',
                              textAlign: TextAlign.center,
                              style: textTheme.bodyMedium?.copyWith(
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle('Claimed QR codes'),
                        const SizedBox(height: 12),
                        Expanded(
                          child: Center(
                            child: Text(
                              'History of already used QR codes\n'
                              '(Firestore `/qr_codes` where `used == true`).',
                              textAlign: TextAlign.center,
                              style: textTheme.bodyMedium?.copyWith(
                                color: Colors.grey.shade500,
                              ),
                            ),
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
      ],
    );
  }
}

class _HistoryPageView extends StatelessWidget {
  const _HistoryPageView();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Intake history',
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'All transactions for this center.',
          style: textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Table with `/transactions` will be here.\n'
                  'You can show material, weight, points, status and date.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium
                      ?.copyWith(color: Colors.grey.shade500),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// -----------------------
/// SMALL REUSABLE WIDGETS
/// -----------------------

class _MaterialRow extends StatefulWidget {
  const _MaterialRow({
    required this.icon,
    required this.label,
    required this.selected,
    required this.minKg,
    required this.maxKg,
    required this.pricePerKg,
    required this.onChanged,
    required this.onMinChanged,
    required this.onMaxChanged,
    required this.onPriceChanged,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final double minKg;
  final double maxKg;
  final double pricePerKg;
  final ValueChanged<bool> onChanged;
  final ValueChanged<double> onMinChanged;
  final ValueChanged<double> onMaxChanged;
  final ValueChanged<double> onPriceChanged;

  @override
  State<_MaterialRow> createState() => _MaterialRowState();
}

class _MaterialRowState extends State<_MaterialRow> {
  late TextEditingController _minController;
  late TextEditingController _maxController;
  late TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    _minController = TextEditingController(text: _formatNum(widget.minKg));
    _maxController = TextEditingController(text: _formatNum(widget.maxKg));
    _priceController = TextEditingController(text: _formatNum(widget.pricePerKg));
  }

  @override
  void didUpdateWidget(_MaterialRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.minKg != widget.minKg) _minController.text = _formatNum(widget.minKg);
    if (oldWidget.maxKg != widget.maxKg) _maxController.text = _formatNum(widget.maxKg);
    if (oldWidget.pricePerKg != widget.pricePerKg) _priceController.text = _formatNum(widget.pricePerKg);
  }

  static String _formatNum(double v) => v == v.roundToDouble() ? '${v.toInt()}' : v.toString();

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF0D9488).withOpacity(0.08) : null,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? const Color(0xFF0D9488).withOpacity(0.3) : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: selected,
                onChanged: (v) => widget.onChanged(v ?? false),
                activeColor: const Color(0xFF0D9488),
              ),
              Icon(
                widget.icon,
                size: 22,
                color: selected ? const Color(0xFF0D9488) : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      ),
                ),
              ),
            ],
          ),
          if (selected) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 72,
                  child: TextField(
                    controller: _minController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Min kg',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    onChanged: (v) => widget.onMinChanged(double.tryParse(v.replaceAll(',', '.')) ?? 0),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 72,
                  child: TextField(
                    controller: _maxController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Max kg',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    onChanged: (v) => widget.onMaxChanged(double.tryParse(v.replaceAll(',', '.')) ?? 0),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 88,
                  child: TextField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Price/kg',
                      hintText: '0=free',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    onChanged: (v) => widget.onPriceChanged(double.tryParse(v.replaceAll(',', '.')) ?? 0),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LogoHeader extends StatelessWidget {
  const _LogoHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Color(0xFF0D9488), Color(0xFF065F46)],
            ),
          ),
          child: const Icon(
            Icons.recycling_rounded,
            color: Colors.white,
            size: 34,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style:
              textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

class _EmailField extends StatelessWidget {
  const _EmailField({this.controller});

  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    return _LabeledTextField(
      controller: controller,
      label: 'Email',
      hint: 'center@example.com',
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    this.controller,
    required this.obscure,
    required this.onToggleObscure,
  });

  final TextEditingController? controller;
  final bool obscure;
  final VoidCallback onToggleObscure;

  @override
  Widget build(BuildContext context) {
    return _LabeledTextField(
      controller: controller,
      label: 'Password',
      hint: '••••••••',
      obscure: obscure,
    );
  }
}

class _LabeledTextField extends StatelessWidget {
  const _LabeledTextField({
    required this.label,
    required this.hint,
    this.icon,
    this.obscure = false,
    this.keyboardType,
    this.controller,
  });

  final String label;
  final String hint;
  final IconData? icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon != null ? Icon(icon) : null,
          ),
        ),
      ],
    );
  }
}

class _BulletPoint extends StatelessWidget {
  const _BulletPoint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, size: 18, color: Color(0xFF10B981)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      width: 220,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.12),
              color.withOpacity(0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

class _ChipTag extends StatelessWidget {
  const _ChipTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor: const Color(0xFFE0F2F1),
      labelStyle: Theme.of(context)
          .textTheme
          .bodySmall
          ?.copyWith(color: const Color(0xFF0D9488)),
    );
  }
}

class _PrimarySaveButton extends StatelessWidget {
  const _PrimarySaveButton({this.label = 'Save changes'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: FilledButton.icon(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$label (UI only, wire to backend later)'),
            ),
          );
        },
        icon: const Icon(Icons.check_rounded),
        label: Text(label),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _MaterialPill extends StatelessWidget {
  const _MaterialPill({required this.icon, required this.label});

  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final selectedColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: selectedColor.withOpacity(0.08),
        border: Border.all(color: selectedColor.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: selectedColor,
            ),
          ),
        ],
      ),
    );
  }
}
