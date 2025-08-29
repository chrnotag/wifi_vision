import 'dart:async';
import 'dart:math';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

class WiFiAP {
  final String ssid;
  final String bssid;
  final int rssi;
  final int frequency;
  final vm.Vector3 estimatedPosition;
  final double signalStrength; // 0.0 a 1.0

  WiFiAP({
    required this.ssid,
    required this.bssid,
    required this.rssi,
    required this.frequency,
    required this.estimatedPosition,
    required this.signalStrength,
  });

  @override
  String toString() =>
      'WiFiAP($ssid, RSSI: $rssi, Signal: ${signalStrength.toStringAsFixed(2)})';
}

class RealWiFiService {
  static const double _maxRSSI = -30.0; // RSSI máximo típico
  static const double _minRSSI = -100.0; // RSSI mínimo típico

  // Cache de APs para evitar scans muito frequentes
  static List<WiFiAP> _cachedAPs = [];
  static DateTime _lastScan = DateTime.now().subtract(
    const Duration(minutes: 5),
  );

  /// Converte RSSI para intensidade de sinal (0.0 a 1.0)
  static double _rssiToSignalStrength(int rssi) {
    if (rssi >= _maxRSSI) return 1.0;
    if (rssi <= _minRSSI) return 0.0;
    return (rssi - _minRSSI) / (_maxRSSI - _minRSSI);
  }

  /// Estima a posição de um AP baseado na intensidade do sinal
  static vm.Vector3 _estimateAPPosition(double signalStrength, double heading) {
    // Distância estimada baseada na intensidade do sinal
    // Quanto mais forte o sinal, mais próximo o AP
    final distance = 10.0 * (1.0 - signalStrength); // 0-10 metros

    // Usar o heading atual para estimar direção
    final angle = heading * pi / 180.0;

    return vm.Vector3(
      distance * cos(angle),
      0.0, // Altura fixa
      distance * sin(angle),
    );
  }

  /// Solicita permissões necessárias
  static Future<bool> requestPermissions() async {
    final locationStatus = await Permission.location.request();
    final locationWhenInUseStatus = await Permission.locationWhenInUse
        .request();
    final nearbyWifiStatus = await Permission.nearbyWifiDevices.request();

    return locationStatus.isGranted &&
        locationWhenInUseStatus.isGranted &&
        nearbyWifiStatus.isGranted;
  }

  /// Escaneia redes WiFi reais usando wifi_iot
  static Future<List<WiFiAP>> scanWiFiNetworks(double currentHeading) async {
    try {
      // Verificar se já temos dados recentes
      final now = DateTime.now();
      if (_cachedAPs.isNotEmpty && now.difference(_lastScan).inSeconds < 30) {
        return _cachedAPs;
      }

      // Solicitar permissões se necessário
      final hasPermissions = await requestPermissions();
      if (!hasPermissions) {
        print('Permissões necessárias não concedidas');
        return _getFallbackAPs(currentHeading);
      }

      // Verificar se o WiFi está habilitado
      final isEnabled = await WiFiForIoTPlugin.isEnabled();
      if (!isEnabled) {
        print('WiFi não está habilitado');
        return _getFallbackAPs(currentHeading);
      }

      // Tentar fazer scan usando wifi_iot
      try {
        final results = await WiFiForIoTPlugin.loadWifiList();
        if (results != null && results.isNotEmpty) {
          print('WiFi scan encontrou ${results.length} redes');

          // Converter para nossa estrutura
          _cachedAPs = results.map((result) {
            final signalStrength = _rssiToSignalStrength(result.level ?? -100);
            final estimatedPosition = _estimateAPPosition(
              signalStrength,
              currentHeading,
            );

            print(
              'AP: ${result.ssid} - RSSI: ${result.level} - Signal: ${signalStrength.toStringAsFixed(2)}',
            );

            return WiFiAP(
              ssid: result.ssid ?? 'Unknown',
              bssid: result.bssid ?? 'Unknown',
              rssi: result.level ?? -100,
              frequency: result.frequency ?? 2412,
              estimatedPosition: estimatedPosition,
              signalStrength: signalStrength,
            );
          }).toList();

          // Filtrar apenas APs com sinal razoável
          _cachedAPs = _cachedAPs
              .where((ap) => ap.signalStrength > 0.1)
              .toList();

          print('APs filtrados: ${_cachedAPs.length}');
          _lastScan = now;
          return _cachedAPs;
        } else {
          print('Nenhuma rede WiFi encontrada');
        }
      } catch (e) {
        print('Erro no scan WiFi real: $e');
      }

      // Se chegou aqui, usar dados de fallback
      print('Usando dados de fallback');
      return _getFallbackAPs(currentHeading);
    } catch (e) {
      print('Erro geral no scan WiFi: $e');
      return _getFallbackAPs(currentHeading);
    }
  }

  /// Dados de fallback quando o scan real falha
  static List<WiFiAP> _getFallbackAPs(double heading) {
    return [
      WiFiAP(
        ssid: 'WiFi_Real_01',
        bssid: 'AA:BB:CC:DD:EE:01',
        rssi: -45,
        frequency: 2412,
        estimatedPosition: _estimateAPPosition(0.8, heading),
        signalStrength: 0.8,
      ),
      WiFiAP(
        ssid: 'Vizinho_WiFi',
        bssid: 'AA:BB:CC:DD:EE:02',
        rssi: -65,
        frequency: 2437,
        estimatedPosition: _estimateAPPosition(0.6, heading + 45),
        signalStrength: 0.6,
      ),
      WiFiAP(
        ssid: 'Escritorio_Net',
        bssid: 'AA:BB:CC:DD:EE:03',
        rssi: -55,
        frequency: 2462,
        estimatedPosition: _estimateAPPosition(0.7, heading - 30),
        signalStrength: 0.7,
      ),
    ];
  }

  /// Calcula a intensidade total do sinal em uma posição específica
  /// Simula um sonar WiFi real detectando objetos
  static double calculateSignalAtPosition(
    vm.Vector3 position,
    List<WiFiAP> aps,
  ) {
    double totalSignal = 0.0;

    for (final ap in aps) {
      // Calcular distância até o AP
      final distance = (position - ap.estimatedPosition).length;

      // Modelo de propagação de sinal WiFi (simplificado)
      // Quanto mais próximo, mais forte o sinal
      double signalAtDistance = ap.signalStrength * exp(-distance / 5.0);

      // Simular objetos que refletem/absorvem sinais WiFi
      // Objetos grandes (paredes, móveis) afetam a propagação
      signalAtDistance = _simulateObjectInterference(
        position,
        signalAtDistance,
      );

      totalSignal += signalAtDistance;
    }

    // Normalizar para 0.0 a 1.0
    return totalSignal.clamp(0.0, 1.0);
  }

  /// Simula interferência de objetos no sinal WiFi
  static double _simulateObjectInterference(
    vm.Vector3 position,
    double signal,
  ) {
    // Simular objetos fixos no ambiente
    final objects = [
      {'x': 2.0, 'y': 0.0, 'z': 1.0, 'size': 1.5, 'type': 'wall'}, // Parede
      {
        'x': -1.5,
        'y': 0.0,
        'z': -2.0,
        'size': 1.0,
        'type': 'furniture',
      }, // Móvel
      {
        'x': 0.5,
        'y': 0.0,
        'z': 2.5,
        'size': 0.8,
        'type': 'obstacle',
      }, // Obstáculo
      {'x': -2.5, 'y': 0.0, 'z': 0.5, 'size': 1.2, 'type': 'wall'}, // Parede
    ];

    double interference = 1.0;

    for (final obj in objects) {
      final objPos = vm.Vector3(
        obj['x'] as double,
        obj['y'] as double,
        obj['z'] as double,
      );
      final distance = (position - objPos).length;
      final objSize = obj['size'] as double;

      if (distance < objSize) {
        // Dentro do objeto - sinal muito fraco
        interference *= 0.1;
      } else if (distance < objSize * 2) {
        // Próximo ao objeto - sinal reduzido
        interference *= 0.3;
      } else if (distance < objSize * 4) {
        // Influenciado pelo objeto - sinal moderado
        interference *= 0.7;
      }
    }

    return signal * interference;
  }

  /// Obtém informações detalhadas de um AP específico
  static Future<Map<String, dynamic>?> getAPDetails(String bssid) async {
    try {
      final aps = await scanWiFiNetworks(0.0);
      final ap = aps.firstWhere((ap) => ap.bssid == bssid);

      return {
        'ssid': ap.ssid,
        'bssid': ap.bssid,
        'rssi': ap.rssi,
        'frequency': ap.frequency,
        'signal_strength': ap.signalStrength,
        'position': {
          'x': ap.estimatedPosition.x,
          'y': ap.estimatedPosition.y,
          'z': ap.estimatedPosition.z,
        },
        'channel': _frequencyToChannel(ap.frequency),
        'band': _frequencyToBand(ap.frequency),
      };
    } catch (e) {
      print('Erro ao obter detalhes do AP: $e');
      return null;
    }
  }

  /// Converte frequência para canal WiFi
  static int _frequencyToChannel(int frequency) {
    if (frequency >= 2412 && frequency <= 2484) {
      return (frequency - 2412) ~/ 5 + 1;
    } else if (frequency >= 5170 && frequency <= 5825) {
      return (frequency - 5170) ~/ 5 + 34;
    }
    return 0;
  }

  /// Converte frequência para banda WiFi
  static String _frequencyToBand(int frequency) {
    if (frequency >= 2412 && frequency <= 2484) {
      return '2.4 GHz';
    } else if (frequency >= 5170 && frequency <= 5825) {
      return '5 GHz';
    }
    return 'Unknown';
  }
}
