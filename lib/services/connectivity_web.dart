/// Web stub for native connectivity check.
/// On web, we don't use Socket.connect (dart:io not available).
/// Browser handles offline natively.
Future<bool> checkConnectionNative() async {
  return true;
}
