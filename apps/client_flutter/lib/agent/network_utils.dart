import 'dart:io';
import 'package:flutter/foundation.dart';

Future<String> getLocalIpAddress() async {
  try {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );
    
    // 1. Prioritize physical interfaces (skip virtual ones like docker, wsl, virtualbox, etc.)
    for (final interface in interfaces) {
      final name = interface.name.toLowerCase();
      if (name.contains('docker') || 
          name.contains('virtual') || 
          name.contains('vbox') || 
          name.contains('vmnet') || 
          name.contains('wsl')) {
        continue;
      }
      for (final addr in interface.addresses) {
        if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
          return addr.address;
        }
      }
    }
    
    // 2. Fallback: return the first non-loopback IPv4 address
    for (final interface in interfaces) {
      for (final addr in interface.addresses) {
        if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
          return addr.address;
        }
      }
    }
  } catch (e) {
    debugPrint('获取局域网 IP 发生异常: $e');
  }
  
  return Platform.localHostname; // Final fallback
}
