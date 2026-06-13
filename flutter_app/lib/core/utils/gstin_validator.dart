// lib/core/utils/gstin_validator.dart

/// GSTIN Validation utility
/// GSTIN format: 2 digits (state code) + 10 chars (PAN) + 1 digit (entity) + Z + check digit
/// Example: 27AABCU9603R1ZX
class GstinValidator {
  GstinValidator._();

  static const String _gstinPattern =
      r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$';

  static final RegExp _gstinRegex = RegExp(_gstinPattern);

  static const Set<String> _validStateCodes = {
    '01', '02', '03', '04', '05', '06', '07', '08', '09', '10',
    '11', '12', '13', '14', '15', '16', '17', '18', '19', '20',
    '21', '22', '23', '24', '26', '27', '28', '29', '30', '31',
    '32', '33', '34', '35', '36', '37', '38', '97', '99',
  };

  /// Validate GSTIN format
  static GstinValidationResult validate(String? gstin) {
    if (gstin == null || gstin.isEmpty) {
      return const GstinValidationResult(
        isValid: false,
        error: 'GSTIN is required',
      );
    }

    final cleaned = gstin.trim().toUpperCase();

    if (cleaned.length != 15) {
      return const GstinValidationResult(
        isValid: false,
        error: 'GSTIN must be exactly 15 characters',
      );
    }

    if (!_gstinRegex.hasMatch(cleaned)) {
      return const GstinValidationResult(
        isValid: false,
        error: 'Invalid GSTIN format. Expected: NNAAAANNNNAANZAN',
      );
    }

    final stateCode = cleaned.substring(0, 2);
    if (!_validStateCodes.contains(stateCode)) {
      return GstinValidationResult(
        isValid: false,
        error: 'Invalid state code: $stateCode',
      );
    }

    // Validate checksum
    if (!_isChecksumValid(cleaned)) {
      return const GstinValidationResult(
        isValid: false,
        error: 'Invalid GSTIN checksum',
      );
    }

    return GstinValidationResult(
      isValid: true,
      stateCode: stateCode,
      pan: cleaned.substring(2, 12),
      entityNumber: cleaned.substring(12, 13),
    );
  }

  /// Extract state code from GSTIN
  static String? extractStateCode(String gstin) {
    if (gstin.length >= 2) return gstin.substring(0, 2);
    return null;
  }

  /// Extract PAN from GSTIN
  static String? extractPan(String gstin) {
    if (gstin.length >= 12) return gstin.substring(2, 12);
    return null;
  }

  /// Check if two GSTINs are from same state (intra-state)
  static bool isSameState(String gstin1, String gstin2) {
    if (gstin1.length < 2 || gstin2.length < 2) return false;
    return gstin1.substring(0, 2) == gstin2.substring(0, 2);
  }

  /// Validate PAN number
  static bool isValidPan(String pan) {
    final panRegex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');
    return panRegex.hasMatch(pan.toUpperCase());
  }

  /// GSTIN Luhn-like checksum validation
  static bool _isChecksumValid(String gstin) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    int sum = 0;

    for (int i = 0; i < 14; i++) {
      int val = charset.indexOf(gstin[i]);
      if (i % 2 != 0) val *= 2;
      sum += val ~/ 36 + val % 36;
    }

    final checkChar = charset[(36 - (sum % 36)) % 36];
    return checkChar == gstin[14];
  }
}

class GstinValidationResult {
  final bool isValid;
  final String? error;
  final String? stateCode;
  final String? pan;
  final String? entityNumber;

  const GstinValidationResult({
    required this.isValid,
    this.error,
    this.stateCode,
    this.pan,
    this.entityNumber,
  });
}

