import 'package:cloud_functions/cloud_functions.dart';

class QRService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<Map<String, dynamic>> scanQRCode(String qrId) async {
    try {
      final callable = _functions.httpsCallable('onQrScan');
      final result = await callable.call({'qrId': qrId});
      return result.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }
}

