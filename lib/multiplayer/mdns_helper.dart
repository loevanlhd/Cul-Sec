import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:nsd/nsd.dart' as nsd;

/// Petit helper autour du package `nsd` pour la découverte des parties
/// Cul Sec sur le réseau local.
class MdnsHelper {
  MdnsHelper._();

  static const String serviceType = '_culsec._tcp';
  static const String _defaultName = 'Cul Sec';

  // --- Hôte -----------------------------------------------------------

  static Future<nsd.Registration> register({
    required String roomCode,
    required int port,
    String name = _defaultName,
  }) async {
    // On rend le nom unique en y ajoutant le code de la room
    final String uniqueName = '$name - $roomCode';

    final nsd.Service service = nsd.Service(
      name: uniqueName,
      type: serviceType,
      port: port,
      txt: <String, Uint8List>{
        'room': Uint8List.fromList(utf8.encode(roomCode)),
      },
    );
    
    try {
      return await nsd.register(service);
    } catch (e) {
      debugPrint('[mDNS] Échec de l’enregistrement : $e');
      rethrow;
    }
  }

  static Future<void> unregister(nsd.Registration registration) async {
    try {
      await nsd.unregister(registration);
    } catch (_) {}
  }

  // --- Client ---------------------------------------------------------

  static Future<nsd.Discovery> discover() async {
    return nsd.startDiscovery(
      serviceType,
      autoResolve: true,
      ipLookupType: nsd.IpLookupType.any,
    );
  }

  static Future<void> stopDiscovery(nsd.Discovery discovery) async {
    try {
      await nsd.stopDiscovery(discovery);
    } catch (_) {}
  }

  /// Extrait l'adresse IPv4 d'un service découvert.
  static String? ipv4Of(nsd.Service service) {
    final List<InternetAddress>? addresses = service.addresses;
    if (addresses == null || addresses.isEmpty) return null;
    for (final InternetAddress a in addresses) {
      if (a.type == InternetAddressType.IPv4) return a.address;
    }
    return addresses.first.address;
  }

  /// Extrait le code de partie des TXT records.
  static String roomCodeOf(nsd.Service service) {
    final Object? raw = service.txt?['room'];
    if (raw is String) return raw;
    if (raw is Uint8List) return utf8.decode(raw, allowMalformed: true);
    if (raw is List<int>) return utf8.decode(raw, allowMalformed: true);
    return '';
  }
}