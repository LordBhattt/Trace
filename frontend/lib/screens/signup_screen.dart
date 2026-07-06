import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();

  bool loading = false;
  bool showPass = false;

  static const Color bg = Color(0xFF0C2C2E);
  static const Color gold = Color(0xFFD4AF37);
  static const Color champagne = Color(0xFFF4E4C1);

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => loading = true);

    try {
      final res = await ApiService.signup(
        _name.text.trim(),
        _email.text.trim(),
        _phone.text.trim(),
        _password.text.trim(),
      );

      if (res["success"] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("token", res["token"]);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        _showError(res["message"] ?? "Signup failed");
      }
    } catch (e) {
      _showError("Something went wrong. Try again.");
    }

    setState(() => loading = false);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),

                // Header
                const Text(
                  "Create Account",
                  style: TextStyle(
                    color: champagne,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Sign up to continue",
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 40),

                _inputField(
                  label: "Full Name",
                  controller: _name,
                  icon: Icons.person,
                ),
                const SizedBox(height: 18),

                _inputField(
                  label: "Email",
                  controller: _email,
                  icon: Icons.email_outlined,
                  validator: (v) {
                    if (v!.isEmpty) return "Required";
                    if (!v.contains("@")) return "Enter valid email";
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                _inputField(
                  label: "Phone",
                  controller: _phone,
                  icon: Icons.phone,
                ),
                const SizedBox(height: 18),

                _passwordField(),

                const SizedBox(height: 40),

                // Sign Up Button
                ElevatedButton(
                  onPressed: loading ? null : _signup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gold,
                    foregroundColor: bg,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          "Sign Up",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                ),

                const SizedBox(height: 25),

                // Already have account?
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Already have an account? ",
                      style: TextStyle(color: Colors.white70),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                      },
                      child: const Text(
                        "Login",
                        style: TextStyle(
                          color: gold,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _inputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator ?? (v) => v!.isEmpty ? "Required" : null,
      style: const TextStyle(color: champagne),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        prefixIcon: Icon(icon, color: champagne),
        filled: true,
        fillColor: const Color(0xFF14242F),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: gold.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(14),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: gold),
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  Widget _passwordField() {
    return TextFormField(
      controller: _password,
      obscureText: !showPass,
      validator: (v) => v!.length < 6 ? "At least 6 characters" : null,
      style: const TextStyle(color: champagne),
      decoration: InputDecoration(
        labelText: "Password",
        labelStyle: const TextStyle(color: Colors.white60),
        prefixIcon: const Icon(Icons.lock_outline, color: champagne),
        suffixIcon: IconButton(
          icon: Icon(
            showPass ? Icons.visibility : Icons.visibility_off,
            color: champagne,
          ),
          onPressed: () => setState(() => showPass = !showPass),
        ),
        filled: true,
        fillColor: const Color(0xFF14242F),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: gold.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(14),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: gold),
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}
