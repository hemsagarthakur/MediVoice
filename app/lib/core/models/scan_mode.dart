enum ScanMode {
  prescription,
  medicineStrip;

  String get wireValue => switch (this) {
    ScanMode.prescription => 'prescription',
    ScanMode.medicineStrip => 'medicine_strip',
  };

  String get label => switch (this) {
    ScanMode.prescription => 'Prescription',
    ScanMode.medicineStrip => 'Medicine strip',
  };

  static ScanMode fromWire(Object? value) => switch (value) {
    'prescription' => ScanMode.prescription,
    'medicine_strip' => ScanMode.medicineStrip,
    _ => throw const FormatException('Unsupported scan mode.'),
  };
}

enum ImageInputKind { camera, gallery }
