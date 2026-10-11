class BankMatchResult {
  final bool matched;
  final String? bankName;
  final String? diagnosticReason;

  const BankMatchResult({
    required this.matched,
    this.bankName,
    this.diagnosticReason,
  });

  @override
  String toString() => 'BankMatchResult(matched: $matched, bank: $bankName, reason: $diagnosticReason)';
}

class BankMatchingService {
  // Canonical bank names and their recognized sender header keywords
  static final Map<String, List<String>> _bankSenderHeaders = {
    'HDFC Bank': ['HDFCBK', 'HDFC', 'HDFCB', 'HDFCPB', 'HDFCCC', 'HDFCSM'],
    'SBI': ['SBIINB', 'SBIPSG', 'SBMSMS', 'SBIUPI', 'SBISMS', 'SBIN', 'SBIETR', 'ATMSBI', 'SBI'],
    'ICICI Bank': ['ICICIB', 'ICICI', 'ICICIT', 'ICICIS', 'ICICIP'],
    'Axis Bank': ['AXISBK', 'AXISB', 'AXIS', 'AXISIN'],
    'Kotak Mahindra Bank': ['KOTAKB', 'KOTAK', 'KMBL', 'KOTAKM'],
    'Canara Bank': ['CANBNK', 'CANARA', 'CNRB'],
    'Bank of Baroda': ['BOBTXN', 'BARODA', 'BOB', 'BARODAB'],
    'Punjab National Bank': ['PNBSMS', 'PUNJAB', 'PNB', 'PNBBK'],
    'Union Bank': ['UBISMS', 'UNION', 'UBI', 'UNIONB'],
    'Indian Bank': ['IDBMSMS', 'INDIAN', 'INDBNK', 'IBANK'],
    'IDBI Bank': ['IDBISMS', 'IDBIBK', 'IDBI'],
    'IndusInd Bank': ['INDSMS', 'INDUS', 'INDUSB', 'INDB'],
    'Yes Bank': ['YESBNK', 'YES', 'YESB'],
    'Federal Bank': ['FEDBNK', 'FEDERAL', 'FBL'],
  };

  // Canonical bank names and body identifier phrases
  static final Map<String, List<String>> _bankBodyPhrases = {
    'HDFC Bank': ['HDFC BANK', 'HDFC BK', 'HDFC A/C'],
    'SBI': ['STATE BANK OF INDIA', 'SBI', 'SBI UPI', 'SBI A/C'],
    'ICICI Bank': ['ICICI BANK', 'ICICI BK', 'ICICI A/C'],
    'Axis Bank': ['AXIS BANK', 'AXIS BK', 'AXIS A/C'],
    'Kotak Mahindra Bank': ['KOTAK BANK', 'KOTAK MAHINDRA', 'KOTAK A/C'],
    'Canara Bank': ['CANARA BANK', 'CANARA A/C'],
    'Bank of Baroda': ['BANK OF BARODA', 'BOB A/C'],
    'Punjab National Bank': ['PUNJAB NATIONAL BANK', 'PNB A/C'],
    'Union Bank': ['UNION BANK OF INDIA', 'UNION BANK', 'UBI A/C'],
    'Indian Bank': ['INDIAN BANK', 'INDBNK A/C'],
    'IDBI Bank': ['IDBI BANK', 'IDBI A/C'],
    'IndusInd Bank': ['INDUSIND BANK', 'INDUSIND A/C'],
    'Yes Bank': ['YES BANK', 'YES BK'],
    'Federal Bank': ['FEDERAL BANK'],
  };

  /// Normalize any user or database bank string to canonical representation
  static String normalizeBankName(String bank) {
    final lower = bank.trim().toLowerCase();
    if (lower.contains('hdfc')) return 'HDFC Bank';
    if (lower.contains('state bank') || lower == 'sbi') return 'SBI';
    if (lower.contains('icici')) return 'ICICI Bank';
    if (lower.contains('axis')) return 'Axis Bank';
    if (lower.contains('kotak')) return 'Kotak Mahindra Bank';
    if (lower.contains('canara')) return 'Canara Bank';
    if (lower.contains('baroda') || lower == 'bob') return 'Bank of Baroda';
    if (lower.contains('punjab') || lower == 'pnb') return 'Punjab National Bank';
    if (lower.contains('union')) return 'Union Bank';
    if (lower.contains('indian bank')) return 'Indian Bank';
    if (lower.contains('idbi')) return 'IDBI Bank';
    if (lower.contains('indusind')) return 'IndusInd Bank';
    if (lower.contains('yes bank') || lower == 'yes') return 'Yes Bank';
    if (lower.contains('federal')) return 'Federal Bank';
    if (lower == 'other') return 'Other';
    return bank.trim();
  }

  /// Extract the core alphanumeric sender identifier from Indian TRAI format
  /// Examples:
  ///   "VK-HDFCBK-S" -> "HDFCBK"
  ///   "BP-SBIINB-T" -> "SBIINB"
  ///   "JM-ICICIB"   -> "ICICIB"
  ///   "AD-KOTAKB"   -> "KOTAKB"
  static String extractCoreSender(String sender) {
    final clean = sender.trim().toUpperCase();
    if (clean.isEmpty) return '';

    // Standard TRAI header format: 2 letters prefix + hyphen + bank code (+ optional hyphen + suffix)
    final traiRegex = RegExp(r'^[A-Z]{2}-([A-Z0-9]+)(?:-[A-Z0-9]+)?$');
    final match = traiRegex.firstMatch(clean);
    if (match != null && match.group(1) != null) {
      return match.group(1)!;
    }

    // Secondary fallback: split by hyphen
    if (clean.contains('-')) {
      final parts = clean.split('-');
      if (parts.length >= 2 && parts[1].isNotEmpty) {
        return parts[1];
      }
    }

    // Strip non-alphanumeric
    return clean.replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  /// Detect which bank a sender header belongs to (if any)
  static String? detectBankFromSender(String sender) {
    final core = extractCoreSender(sender);
    final upperSender = sender.toUpperCase();

    for (final entry in _bankSenderHeaders.entries) {
      final bankName = entry.key;
      final keywords = entry.value;

      for (final kw in keywords) {
        if (core == kw || core.startsWith(kw) || upperSender.contains(kw)) {
          return bankName;
        }
      }
    }

    return null;
  }

  /// Detect which bank the body text explicitly belongs to (if any)
  static String? detectBankFromBody(String body) {
    final upperBody = body.toUpperCase();

    for (final entry in _bankBodyPhrases.entries) {
      final bankName = entry.key;
      final phrases = entry.value;

      for (final p in phrases) {
        if (upperBody.contains(p)) {
          return bankName;
        }
      }
    }

    return null;
  }

  /// Evaluate if an SMS sender and body matches the user's selected bank
  BankMatchResult matchBank({
    required String sender,
    required String body,
    required String selectedBank,
  }) {
    final normalizedSelected = normalizeBankName(selectedBank);

    if (normalizedSelected.toLowerCase() == 'other') {
      return const BankMatchResult(matched: true, bankName: 'Other');
    }

    final detectedFromSender = detectBankFromSender(sender);
    final detectedFromBody = detectBankFromBody(body);

    // 1. If sender explicitly belongs to a DIFFERENT known bank -> REJECT
    if (detectedFromSender != null && detectedFromSender != normalizedSelected) {
      return BankMatchResult(
        matched: false,
        diagnosticReason:
            'Sender ($sender) belongs to $detectedFromSender, but selected bank is $normalizedSelected',
      );
    }

    // 2. If sender explicitly belongs to the selected bank
    if (detectedFromSender == normalizedSelected) {
      // Check if body contradicts by explicitly stating a different bank
      if (detectedFromBody != null && detectedFromBody != normalizedSelected) {
        return BankMatchResult(
          matched: false,
          diagnosticReason:
              'Sender matches $normalizedSelected but body explicitly references $detectedFromBody',
        );
      }
      return BankMatchResult(matched: true, bankName: normalizedSelected);
    }

    // 3. Sender is non-standard or generic: fallback to explicit body verification
    if (detectedFromBody == normalizedSelected) {
      return BankMatchResult(matched: true, bankName: normalizedSelected);
    }

    if (detectedFromBody != null && detectedFromBody != normalizedSelected) {
      return BankMatchResult(
        matched: false,
        diagnosticReason:
            'Body explicitly references $detectedFromBody, but selected bank is $normalizedSelected',
      );
    }

    // 4. Uncertain match -> reject safely to avoid misattribution
    return BankMatchResult(
      matched: false,
      diagnosticReason:
          'Could not reliably confirm sender ($sender) or content belongs to $normalizedSelected',
    );
  }
}
