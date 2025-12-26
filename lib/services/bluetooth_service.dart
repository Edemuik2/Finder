import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/bluetooth_device_model.dart';

class BluetoothService extends ChangeNotifier {
  final Map<String, BluetoothDeviceModel> _devices = {};
  bool _isScanning = false;
  bool _isBluetoothOn = false;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _bluetoothStateSubscription;

  BluetoothService() {
    _initialize();
  }

  List<BluetoothDeviceModel> get devices =>
      _devices.values.toList()..sort((a, b) => b.rssi.compareTo(a.rssi));

  bool get isScanning => _isScanning;
  bool get isBluetoothOn => _isBluetoothOn;

  Future<void> _initialize() async {
    _bluetoothStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      _isBluetoothOn = state == BluetoothAdapterState.on;
      notifyListeners();
    });

    final state = await FlutterBluePlus.adapterState.first;
    _isBluetoothOn = state == BluetoothAdapterState.on;
    notifyListeners();
  }

  Future<bool> requestPermissions() async {
    try {
      // Запрашиваем Bluetooth разрешения
      if (await Permission.bluetoothScan.isDenied) {
        final result = await Permission.bluetoothScan.request();
        debugPrint('Bluetooth Scan permission: $result');
      }

      if (await Permission.bluetoothConnect.isDenied) {
        final result = await Permission.bluetoothConnect.request();
        debugPrint('Bluetooth Connect permission: $result');
      }

      // Запрашиваем местоположение (требуется для Bluetooth на iOS)
      if (await Permission.locationWhenInUse.isDenied) {
        final result = await Permission.locationWhenInUse.request();
        debugPrint('Location permission: $result');
      }

      final bluetoothScan = await Permission.bluetoothScan.isGranted;
      final bluetoothConnect = await Permission.bluetoothConnect.isGranted;
      final location = await Permission.locationWhenInUse.isGranted;

      debugPrint(
          'Permissions - Scan: $bluetoothScan, Connect: $bluetoothConnect, Location: $location');

      return bluetoothScan && bluetoothConnect && location;
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      return false;
    }
  }

  Future<void> startScanning() async {
    if (_isScanning) return;

    debugPrint('Starting Bluetooth scan...');

    final hasPermissions = await requestPermissions();
    if (!hasPermissions) {
      debugPrint('ERROR: Permissions not granted');
      return;
    }

    if (!_isBluetoothOn) {
      debugPrint('ERROR: Bluetooth is off');
      return;
    }

    _devices.clear();
    _isScanning = true;
    notifyListeners();

    try {
      debugPrint('Calling FlutterBluePlus.startScan()...');

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: false,
      );

      debugPrint('Scan started successfully');

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        debugPrint('Scan results: ${results.length} devices found');

        for (ScanResult result in results) {
          final device = result.device;
          final name = result.advertisementData.advName.isNotEmpty
              ? result.advertisementData.advName
              : device.platformName;

          debugPrint(
              'Found device: $name (${device.remoteId}) RSSI: ${result.rssi}');

          if (name.isEmpty) continue;

          final manufacturerData =
              result.advertisementData.manufacturerData.isNotEmpty
                  ? result.advertisementData.manufacturerData.values.first
                  : <int>[];

          final deviceType = detectDeviceType(name, manufacturerData);

          _devices[device.remoteId.toString()] = BluetoothDeviceModel(
            device: device,
            name: name,
            id: device.remoteId.toString(),
            rssi: result.rssi,
            deviceType: deviceType,
          );
        }
        notifyListeners();
      });

      // Ждем завершения сканирования
      await Future.delayed(const Duration(seconds: 15));
      await stopScanning();
    } catch (e) {
      debugPrint('ERROR scanning: $e');
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<void> stopScanning() async {
    await _scanSubscription?.cancel();
    _scanSubscription = null;

    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      debugPrint('Error stopping scan: $e');
    }

    _isScanning = false;
    notifyListeners();
  }

  Stream<int> getRssiStream(BluetoothDevice device) async* {
    while (true) {
      try {
        await FlutterBluePlus.startScan(
          timeout: const Duration(milliseconds: 500),
          androidUsesFineLocation: true,
        );

        await for (final results in FlutterBluePlus.scanResults) {
          for (final result in results) {
            if (result.device.remoteId == device.remoteId) {
              yield result.rssi;
              await FlutterBluePlus.stopScan();
              break;
            }
          }
        }

        await Future.delayed(const Duration(milliseconds: 300));
      } catch (e) {
        debugPrint('Error getting RSSI: $e');
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _bluetoothStateSubscription?.cancel();
    stopScanning();
    super.dispose();
  }
}
