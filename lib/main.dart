import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/epson_usb_service.dart';
import 'models/printer_model.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EpsonResetterApp());
}

class EpsonResetterApp extends StatelessWidget {
  const EpsonResetterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Epson Waste Ink Resetter (AdjProg Native)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0284C7),
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0284C7),
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme),
      ),
      home: const ResetterHomeScreen(),
    );
  }
}

class ResetterHomeScreen extends StatefulWidget {
  const ResetterHomeScreen({super.key});

  @override
  State<ResetterHomeScreen> createState() => _ResetterHomeScreenState();
}

class _ResetterHomeScreenState extends State<ResetterHomeScreen> {
  final EpsonUsbService _usbService = EpsonUsbService();
  
  EpsonPrinterModel _selectedModel = EpsonPrinterModel.supportedModels.first;
  bool _isConnected = false;
  bool _isLoading = false;
  
  int _mainPadPoints = 0;
  double _mainPadPercent = 0.0;
  int _platenPadPoints = 0;
  double _platenPadPercent = 0.0;
  bool _hasChecked = false;
  
  final List<String> _logs = [];
  final ScrollController _logScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initUsb();
  }

  Future<void> _initUsb() async {
    _addLog('[SYS] Menginisialisasi USB Subsystem (quick_usb + libusb)...');
    final success = await _usbService.init();
    if (success) {
      _addLog('[SYS] USB Subsystem siap.');
    } else {
      _addLog('[ERR] Gagal menginisialisasi USB.');
    }
  }

  void _addLog(String text) {
    setState(() {
      final now = DateTime.now();
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      _logs.add('[$timeStr] $text');
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _connectPrinter() async {
    setState(() => _isLoading = true);
    _addLog('[USB] Mencari printer Epson (VID: 0x04B8)...');
    
    try {
      final connected = await _usbService.connectToPrinter(
        vendorId: _selectedModel.vendorId,
        onLog: _addLog,
      );
      
      setState(() {
        _isConnected = connected;
      });
      
      if (connected) {
        _addLog('[USB] Terhubung ke printer Epson! Siap membaca counter.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terhubung ke ${_selectedModel.name}')),
        );
      } else {
        _addLog('[WARN] Printer tidak ditemukan. Pastikan kabel OTG / USB tersambung.');
      }
    } catch (e) {
      _addLog('[ERR] Error koneksi: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkCounter() async {
    if (!_isConnected) {
      _addLog('[WARN] Hubungkan printer terlebih dahulu.');
      return;
    }
    
    setState(() => _isLoading = true);
    _addLog('[ESC/P-R] Mengirim handshake EJL dan perintah query waste pad...');
    
    try {
      final result = await _usbService.readWasteInkCounter(
        model: _selectedModel,
        onLog: _addLog,
      );
      
      setState(() {
        _mainPadPoints = result['mainPoints'] ?? 0;
        _mainPadPercent = (_mainPadPoints / _selectedModel.maxMainPoints * 100).clamp(0, 150);
        _platenPadPoints = result['platenPoints'] ?? 0;
        _platenPadPercent = _selectedModel.hasPlatenPad
            ? (_platenPadPoints / _selectedModel.maxPlatenPoints * 100).clamp(0, 150)
            : 0.0;
        _hasChecked = true;
      });
      
      _addLog('[RESULT] Main Pad: $_mainPadPoints / ${_selectedModel.maxMainPoints} (${_mainPadPercent.toStringAsFixed(1)}%)');
      if (_mainPadPercent >= 100.0) {
        _addLog('[ALERT] Waste Ink Pad PENUH (100%)! Printer memerlukan reset.');
      }
    } catch (e) {
      _addLog('[ERR] Gagal membaca counter: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resetCounter() async {
    if (!_isConnected) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Reset Waste Ink Pad'),
        content: Text(
          'Perintah ini akan menulis ulang EEPROM printer ${_selectedModel.name} dan mereset counter ke 0 point (0%).\n\n'
          'Pastikan bantalan busa tinta fisik sudah dibersihkan atau diganti dengan pembuangan botol luar agar tinta tidak meluber.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Reset Counter'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    setState(() => _isLoading = true);
    _addLog('[RESET] Memulai prosedur reset EEPROM...');
    
    try {
      final success = await _usbService.resetWasteInkCounter(
        model: _selectedModel,
        onLog: _addLog,
      );
      
      if (success) {
        _addLog('[SUCCESS] Counter EEPROM berhasil di-reset ke 0!');
        setState(() {
          _mainPadPoints = 0;
          _mainPadPercent = 0.0;
          _platenPadPoints = 0;
          _platenPadPercent = 0.0;
        });
        
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Reset Selesai! Matikan Printer'),
            content: const Text(
              'Perintah reset berhasil diterima oleh printer.\n\n'
              'LANGKAH PENTING:\n'
              '1. Matikan printer Epson Anda dengan menekan tombol Power.\n'
              '2. Tunggu 5 detik sampai lampu indikator mati sepenuhnya.\n'
              '3. Hidupkan kembali printer Anda.\n'
              '4. Lampu merah akan berhenti berkedip dan printer siap digunakan normal!',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Mengerti'),
              ),
            ],
          ),
        );
      } else {
        _addLog('[ERR] Printer menolak perintah reset atau timeout.');
      }
    } catch (e) {
      _addLog('[ERR] Gagal reset: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOverLimit = _mainPadPercent >= 100.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Epson Resetter (AdjProg Native)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Pindai Ulang USB',
            onPressed: _connectPrinter,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card Pemilihan Model & Koneksi
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Model Printer Epson', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<EpsonPrinterModel>(
                      value: _selectedModel,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: EpsonPrinterModel.supportedModels.map((model) {
                        return DropdownMenuItem(
                          value: model,
                          child: Text('${model.name} (${model.series})'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedModel = val;
                            _hasChecked = false;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: _isLoading ? null : _connectPrinter,
                            icon: Icon(_isConnected ? Icons.usb : Icons.usb_off),
                            label: Text(_isConnected ? 'Terhubung (0x04B8)' : 'Sambungkan USB OTG'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Card Indikator Counter Waste Ink Pad
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(
                  color: isOverLimit ? Colors.red.shade300 : theme.colorScheme.outlineVariant,
                  width: isOverLimit ? 1.5 : 1.0,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Waste Ink Pad Counter', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        if (_hasChecked)
                          Text(
                            isOverLimit ? 'SERVICE REQUIRED' : 'NORMAL',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isOverLimit ? Colors.red : Colors.green,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Main Pad Counter
                    Text('Main Pad Counter: $_mainPadPoints / ${_selectedModel.maxMainPoints} points (${_mainPadPercent.toStringAsFixed(1)}%)'),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (_mainPadPercent / 100).clamp(0.0, 1.0),
                        minHeight: 12,
                        backgroundColor: Colors.grey.shade200,
                        color: isOverLimit ? Colors.red : (_mainPadPercent > 80 ? Colors.orange : Colors.blue),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Platen Pad Counter jika ada
                    if (_selectedModel.hasPlatenPad) ...[
                      Text('Platen Pad Counter: $_platenPadPoints / ${_selectedModel.maxPlatenPoints} points (${_platenPadPercent.toStringAsFixed(1)}%)'),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (_platenPadPercent / 100).clamp(0.0, 1.0),
                          minHeight: 10,
                          backgroundColor: Colors.grey.shade200,
                          color: _platenPadPercent > 100 ? Colors.red : Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Tombol Aksi
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: (_isLoading || !_isConnected) ? null : _checkCounter,
                            icon: const Icon(Icons.search),
                            label: const Text('Check Counter'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: isOverLimit ? Colors.red : null,
                            ),
                            onPressed: (_isLoading || !_isConnected) ? null : _resetCounter,
                            icon: const Icon(Icons.restore),
                            label: const Text('Initialize (Reset)'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Log Console USB
            Card(
              elevation: 0,
              color: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('USB Protocol Terminal (TX / RX)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('libusb / ESC/P-R', style: TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                    const Divider(color: Colors.white24, height: 16),
                    SizedBox(
                      height: 180,
                      child: ListView.builder(
                        controller: _logScrollController,
                        itemCount: _logs.length,
                        itemBuilder: (ctx, i) {
                          final log = _logs[i];
                          Color textColor = Colors.white70;
                          if (log.contains('[ERR]')) textColor = Colors.redAccent;
                          if (log.contains('[SUCCESS]')) textColor = Colors.greenAccent;
                          if (log.contains('[WARN]')) textColor = Colors.amberAccent;
                          if (log.contains('[TX]')) textColor = Colors.cyanAccent;
                          if (log.contains('[RX]')) textColor = Colors.lightGreenAccent;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Text(
                              log,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                color: textColor,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
