import 'package:web/web.dart' as web;

Future<bool> openPrivacyPolicyPage() async {
  web.window.location.assign('/privacy.html');
  return true;
}
