import 'dart:io';

/// Native (mobile) connectivity check using raw socket connection.
Future<bool> checkConnectionNative() async {
  try {
    final socket = await Socket.connect('8.8.8.8', 53,
        timeout: const Duration(milliseconds: 1500));
    await socket.close();
    return true;
  } catch (_) {
    try {
      final socket = await Socket.connect('1.1.1.1', 53,
          timeout: const Duration(milliseconds: 1500));
      await socket.close();
      return true;
    } catch (_) {
      try {
        final lookup = await InternetAddress.lookup('example.com')
            .timeout(const Duration(milliseconds: 1500));
        if (lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty) {
          return true;
        }
      } catch (_) {}
      return false;
    }
  }
}
