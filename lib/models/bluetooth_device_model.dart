import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BluetoothDeviceModel {
  final BluetoothDevice device;
  final String name;
  final String id;
  final int rssi;
  final DeviceType deviceType;

  BluetoothDeviceModel({
    required this.device,
    required this.name,
    required this.id,
    required this.rssi,
    required this.deviceType,
  });

  double get distance {
    // Формула для расчета расстояния на основе RSSI
    // RSSI = -10n * log10(d) + A
    // где A = -59 (мощность сигнала на расстоянии 1 метр)

    const measuredPower = -59;

    if (rssi == 0) {
      return -1.0;
    }

    final ratio = rssi * 1.0 / measuredPower;

    if (ratio < 1.0) {
      return pow(ratio, 10).toDouble();
    } else {
      final distance = (0.89976) * pow(ratio, 7.7095) + 0.111;
      return distance;
    }
  }

  num pow(num x, num exponent) {
    return x.toDouble() == 0 ? 0 : x.toDouble() * x.toDouble();
  }

  String get displayName {
    if (name.isNotEmpty) return name;
    return 'Unknown Device';
  }
}

enum DeviceType {
  iPhone,
  iPad,
  airPods,
  appleWatch,
  mac,
  appleTV,
  beats,
  homePod,
  unknown,
}

extension DeviceTypeExtension on DeviceType {
  String get icon {
    switch (this) {
      case DeviceType.iPhone:
        return '📱';
      case DeviceType.iPad:
        return '📱';
      case DeviceType.airPods:
        return '🎧';
      case DeviceType.appleWatch:
        return '⌚';
      case DeviceType.mac:
        return '💻';
      case DeviceType.appleTV:
        return '📺';
      case DeviceType.beats:
        return '🎧';
      case DeviceType.homePod:
        return '🔊';
      case DeviceType.unknown:
        return '📡';
    }
  }

  String get displayName {
    switch (this) {
      case DeviceType.iPhone:
        return 'iPhone';
      case DeviceType.iPad:
        return 'iPad';
      case DeviceType.airPods:
        return 'AirPods';
      case DeviceType.appleWatch:
        return 'Apple Watch';
      case DeviceType.mac:
        return 'Mac';
      case DeviceType.appleTV:
        return 'Apple TV';
      case DeviceType.beats:
        return 'Beats';
      case DeviceType.homePod:
        return 'HomePod';
      case DeviceType.unknown:
        return 'Устройство';
    }
  }
}

DeviceType detectDeviceType(String name, List<int> manufacturerData) {
  final lowerName = name.toLowerCase();

  // Определение по имени
  if (lowerName.contains('iphone')) return DeviceType.iPhone;
  if (lowerName.contains('ipad')) return DeviceType.iPad;
  if (lowerName.contains('airpods') || lowerName.contains('air pods'))
    return DeviceType.airPods;
  if (lowerName.contains('watch')) return DeviceType.appleWatch;
  if (lowerName.contains('macbook') ||
      lowerName.contains('imac') ||
      lowerName.contains('mac')) return DeviceType.mac;
  if (lowerName.contains('apple tv')) return DeviceType.appleTV;
  if (lowerName.contains('beats')) return DeviceType.beats;
  if (lowerName.contains('homepod')) return DeviceType.homePod;

  // Определение по manufacturer data (Apple Company Identifier: 0x004C)
  if (manufacturerData.isNotEmpty && manufacturerData.length >= 2) {
    // Проверяем на Apple устройства
    if (manufacturerData[0] == 0x4C && manufacturerData[1] == 0x00) {
      if (manufacturerData.length > 2) {
        final type = manufacturerData[2];
        if (type == 0x07 || type == 0x0F) return DeviceType.airPods;
        if (type == 0x01) return DeviceType.iPhone;
        if (type == 0x09) return DeviceType.appleWatch;
      }
    }
  }

  return DeviceType.unknown;
}
