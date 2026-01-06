import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ConnectivityService {
  static Future<String> diagnoseGoogleAi() async {
    final results = <String>[];
    results.add(
      'Iniciando diagnóstico para generativelanguage.googleapis.com...',
    );

    try {
      const host = 'generativelanguage.googleapis.com';
      final addresses = await InternetAddress.lookup(host);
      results.add(
        '✅ DNS resolveu para: ${addresses.map((a) => a.address).join(', ')}',
      );
    } catch (e) {
      results.add('❌ Falha no DNS: $e');
    }

    try {
      final response = await http.get(
        Uri.parse('https://generativelanguage.googleapis.com/'),
      );
      results.add('✅ Conexão HTTP (Root): Status ${response.statusCode}');
    } catch (e) {
      results.add('❌ Falha na conexão HTTP: $e');
    }

    if (!kIsWeb) {
      try {
        final socket = await Socket.connect(
          'generativelanguage.googleapis.com',
          443,
          timeout: const Duration(seconds: 5),
        );
        results.add('✅ Socket TCP conectado à porta 443');
        await socket.close();
      } catch (e) {
        results.add('❌ Falha no Socket TCP: $e');
      }
    }

    return results.join('\n');
  }
}
