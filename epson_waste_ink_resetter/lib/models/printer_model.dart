class EpsonPrinterModel {
  final String id;
  final String name;
  final String series;
  final int vendorId; // 0x04B8
  final int? productId;
  final int maxMainPoints;
  final int maxPlatenPoints;
  final bool hasPlatenPad;
  final int eepromAddress;

  const EpsonPrinterModel({
    required this.id,
    required this.name,
    required this.series,
    this.vendorId = 0x04b8,
    this.productId,
    required this.maxMainPoints,
    this.maxPlatenPoints = 1200,
    required this.hasPlatenPad,
    required this.eepromAddress,
  });

  static const List<EpsonPrinterModel> supportedModels = [
    EpsonPrinterModel(
      id: 'l120',
      name: 'Epson L120',
      series: 'L-Series Desktop Single Function',
      productId: 0x00a5,
      maxMainPoints: 6200,
      hasPlatenPad: false,
      eepromAddress: 0x14,
    ),
    EpsonPrinterModel(
      id: 'l3110',
      name: 'Epson L3110',
      series: 'EcoTank All-in-One',
      productId: 0x1141,
      maxMainPoints: 6346,
      maxPlatenPoints: 1200,
      hasPlatenPad: true,
      eepromAddress: 0x18,
    ),
    EpsonPrinterModel(
      id: 'l3150',
      name: 'Epson L3150',
      series: 'EcoTank Wi-Fi Multi-Function',
      productId: 0x1142,
      maxMainPoints: 6346,
      maxPlatenPoints: 1200,
      hasPlatenPad: true,
      eepromAddress: 0x18,
    ),
    EpsonPrinterModel(
      id: 'l1110',
      name: 'Epson L1110',
      series: 'EcoTank Single Function',
      productId: 0x08d8,
      maxMainPoints: 6346,
      hasPlatenPad: false,
      eepromAddress: 0x18,
    ),
    EpsonPrinterModel(
      id: 'l360',
      name: 'Epson L360',
      series: 'L-Series Multi-Function',
      productId: 0x08b8,
      maxMainPoints: 6200,
      hasPlatenPad: false,
      eepromAddress: 0x14,
    ),
    EpsonPrinterModel(
      id: 'l210',
      name: 'Epson L210 / L220',
      series: 'L-Series Classic',
      productId: 0x08a8,
      maxMainPoints: 6500,
      hasPlatenPad: false,
      eepromAddress: 0x14,
    ),
    EpsonPrinterModel(
      id: 'l380',
      name: 'Epson L380 / L385',
      series: 'L-Series Refined',
      productId: 0x08cf,
      maxMainPoints: 6200,
      hasPlatenPad: false,
      eepromAddress: 0x14,
    ),
    EpsonPrinterModel(
      id: 'l4150',
      name: 'Epson L4150 / L4160',
      series: 'EcoTank Duplex Series',
      productId: 0x1131,
      maxMainPoints: 7200,
      maxPlatenPoints: 1500,
      hasPlatenPad: true,
      eepromAddress: 0x20,
    ),
  ];
}
