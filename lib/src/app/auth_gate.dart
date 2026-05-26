part of 'package:companion_flutter/main.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  AuthSession? _session;
  CompanionApi? _api;

  void _onAuthenticated(CompanionApi api, AuthSession session) {
    setState(() {
      _api = api;
      _session = session;
    });
  }

  void _onSessionChanged(AuthSession session) {
    setState(() => _session = session);
  }

  void _logout() {
    setState(() {
      _api = null;
      _session = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final api = _api;
    if (session != null && api != null) {
      return MainShell(
        api: api,
        session: session,
        onSessionChanged: _onSessionChanged,
        onLogout: _logout,
      );
    }
    return LoginPage(onAuthenticated: _onAuthenticated);
  }
}
