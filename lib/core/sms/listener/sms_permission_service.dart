import 'package:permission_handler/permission_handler.dart';

class SmsPermissionService {
  Future<bool> isGranted() => Permission.sms.isGranted;

  Future<bool> request() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }
}
