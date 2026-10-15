import 'dart:async';
import 'dart:typed_data';
import 'package:quick_usb/quick_usb.dart';
import '../models/printer_model.dart';

typedef LogCallback = void Function(String message);

class EpsonUsbService {
  UsbDevice? _device;
  UsbEndpoint? _endpointOut;
  UsbEndpoint? _endpointIn;

  Future<bool> init() async {
    try {
      await QuickUsb.init();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> dispose() async {
    try {
      if (_device != null) {
        await QuickUsb.closeDevice();
      }
      await QuickUsb.exit();
    } catch (_) {}
  }

  /// Memindai perangkat USB dan menyambungkan ke printer Epson (VID: 0x04B8)
  Future<bool> connectToPrinter({
    required int vendorId,
    required LogCallback onLog,
  }) async {
    try {
      final deviceList = await QuickUsb.getDeviceList();
      onLog('[USB] Ditemukan ${deviceList.length} perangkat USB yang tercolok.');

      UsbDevice? epsonDevice;
      for (final dev in deviceList) {
        onLog('[USB] Check VID: 0x${dev.vendorId.toRadixString(16).padLeft(4, '0')}, PID: 0x${dev.productId.toRadixString(16).padLeft(4, '0')}');
        if (dev.vendorId == vendorId) {
          epsonDevice = dev;
          break;
        }
      }

      if (epsonDevice == null) {
        onLog('[USB] Tidak ada printer Epson yang terdeteksi dengan VID 0x${vendorId.toRadixString(16)}.');
        return false;
      }

      _device = epsonDevice;
      onLog('[USB] Meminta izin akses USB (Android USB Host permission popup)...');
      final hasPermission = await QuickUsb.hasPermission(epsonDevice);
      if (!hasPermission) {
        await QuickUsb.requestPermission(epsonDevice);
      }

      onLog('[USB] Membuka koneksi perangkat...');
      await QuickUsb.openDevice(epsonDevice);

      final configuration = await QuickUsb.getConfiguration(0);
      onLog('[USB] Mengklaim antarmuka USB (Interface 0)...');
      await QuickUsb.claimInterface(configuration.interfaces[0]);

      // Cari Bulk OUT dan Bulk IN endpoint
      final endpoints = configuration.interfaces[0].endpoints;
      for (final ep in endpoints) {
        if (ep.direction == UsbEndpoint.directionOut) {
          _endpointOut = ep;
        } else if (ep.direction == UsbEndpoint.directionIn) {
          _endpointIn = ep;
        }
      }

      onLog('[USB] Endpoint Out: 0x${_endpointOut?.endpointNumber.toRadixString(16)}, In: 0x${_endpointIn?.endpointNumber.toRadixString(16)}');
      return _endpointOut != null && _endpointIn != null;
    } catch (e) {
      onLog('[USB_ERR] Gagal menghubungkan: $e');
      return false;
    }
  }

  /// Membaca nilai Waste Ink Pad Counter dari printer via paket ESC/P-R
  Future<Map<String, int>> readWasteInkCounter({
    required EpsonPrinterModel model,
    required LogCallback onLog,
  }) async {
    if (_endpointOut == null || _endpointIn == null) {
      throw Exception('Endpoint USB belum siap.');
    }

    // 1. Kirim Handshake ESC/P-R EJL (Enter Job Language)
    final ejlInit = Uint8List.fromList([
      0x1b, 0x01, // ESC + SOH
      0x40, 0x45, 0x4a, 0x4c, 0x20, 0x31, 0x32, 0x38, 0x34, 0x2e, 0x34, 0x0a, // @EJL 1284.4

      0x40, 0x45, 0x4a, 0x4c, 0x20, 0x0a, // @EJL 

    ]);

    onLog('[TX] Mengirim EJL Init: ${_bytesToHex(ejlInit)}');
    await QuickUsb.bulkTransferOut(_endpointOut!, ejlInit);
    await Future.delayed(const Duration(milliseconds: 150));

    // 2. Kirim Perintah Masuk Remote Mode Epson (REMOTE1) & Query Counter
    // Header ESC ( R + 'REMOTE1' + Query DT / IQ command
    final queryPacket = Uint8List.fromList([
      0x1b, 0x28, 0x52, 0x08, 0x00, 0x00, // ESC ( R len=8
      0x52, 0x45, 0x4d, 0x4f, 0x54, 0x45, 0x31, // REMOTE1
      0x44, 0x54, 0x01, 0x00, 0x00, // DT Query Command (0x44 0x54)
    ]);

    onLog('[TX] Mengirim Query Counter Command: ${_bytesToHex(queryPacket)}');
    await QuickUsb.bulkTransferOut(_endpointOut!, queryPacket);
    await Future.delayed(const Duration(milliseconds: 250));

    // 3. Baca respon balasan dari Bulk IN
    onLog('[RX] Menunggu respon dari Bulk IN endpoint...');
    final response = await QuickUsb.bulkTransferIn(_endpointIn!, 64);
    onLog('[RX] Diterima ${response.length} bytes: ${_bytesToHex(response)}');

    int mainPoints = 0;
    int platenPoints = 0;

    if (response.isNotEmpty) {
      // Menguraikan offset respon counter Epson EEPROM
      // Byte 16-17 biasanya berisi counter points (Big Endian atau Little Endian sesuai model)
      if (response.length >= 20) {
        mainPoints = (response[16] << 8) | response[17];
        if (model.hasPlatenPad && response.length >= 22) {
          platenPoints = (response[18] << 8) | response[19];
        }
      } else {
        // Fallback reading format
        mainPoints = (response[response.length - 2] << 8) | response[response.length - 1];
      }
    }

    return {
      'mainPoints': mainPoints,
      'platenPoints': platenPoints,
    };
  }

  /// Mengirim instruksi Reset Waste Ink Pad (Inisialisasi EEPROM ke 0)
  Future<bool> resetWasteInkCounter({
    required EpsonPrinterModel model,
    required LogCallback onLog,
  }) async {
    if (_endpointOut == null || _endpointIn == null) {
      throw Exception('Endpoint USB belum siap.');
    }

    // Paket Reset: Masuk REMOTE1 lalu eksekusi EEPROM write 0x00 0x00 ke register pad
    final resetPacket = Uint8List.fromList([
      0x1b, 0x28, 0x52, 0x0a, 0x00, 0x00, // ESC ( R
      0x52, 0x45, 0x4d, 0x4f, 0x54, 0x45, 0x31, // REMOTE1
      0x44, 0x54, 0x02, 0x00, 0x00, 0x00, 0x00, // DT Reset: clear counter bytes
      0x1b, 0x00, 0x00, 0x00, // Exit remote mode
    ]);

    onLog('[TX] Mengirim Reset Payload: ${_bytesToHex(resetPacket)}');
    final written = await QuickUsb.bulkTransferOut(_endpointOut!, resetPacket);
    onLog('[TX] ${written} bytes terkirim ke printer.');

    await Future.delayed(const Duration(milliseconds: 300));

    // Periksa respon konfirmasi dari printer
    final ack = await QuickUsb.bulkTransferIn(_endpointIn!, 16);
    onLog('[RX] Konfirmasi Printer: ${_bytesToHex(ack)}');

    return ack.isNotEmpty || written > 0;
  }

  String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
  }
}
