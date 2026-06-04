import 'package:url_launcher/url_launcher.dart';

Future<bool> openPrivacyPolicyPage() {
  final url = Uri.base.resolve('/privacy.html');
  return launchUrl(url, webOnlyWindowName: '_self');
}
