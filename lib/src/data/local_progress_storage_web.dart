import 'package:web/web.dart' as web;

bool get isAvailable {
  try {
    web.window.localStorage;
    return true;
  } on Object {
    return false;
  }
}

String? getString(String key) => web.window.localStorage.getItem(key);

void setString(String key, String value) {
  web.window.localStorage.setItem(key, value);
}

void remove(String key) {
  web.window.localStorage.removeItem(key);
}
