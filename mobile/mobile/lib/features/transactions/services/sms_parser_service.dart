import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/utils/app_storage.dart';
import 'transaction_service.dart';

class ParsedTransaction {
  final double amount;
  final String merchant;
  final DateTime transactionDate;
  final String transactionType;
  final String bank;
  final String rawSms;

  ParsedTransaction({
    required this.amount,
    required this.merchant,
    required this.transactionDate,
    required this.transactionType,
    required this.bank,
    required this.rawSms,
  });
}

class SmsParserService {
  final TransactionService transactionService;
  final SmsQuery _query = SmsQuery();

  SmsParserService(this.transactionService);

  // Bank keywords and sender patterns
  static final Map<String, List<String>> _bankSenderKeywords = {
    'HDFC Bank': ['HDFCBK', 'HDFC', 'HDFCB', 'HDFCPB'],
    'SBI': ['SBIINB', 'SBIPSG', 'SBMSMS', 'SBI', 'SBIN', 'STATE BANK'],
    'ICICI Bank': ['ICICIB', 'ICICI', 'ICICIT'],
    'Axis Bank': ['AXISBK', 'AXIS', 'AXISB'],
    'Kotak Mahindra Bank': ['KOTAKB', 'KOTAK', 'KMBL'],
    'Canara Bank': ['CANBNK', 'CANARA', 'CNRB'],
    'Bank of Baroda': ['BOBTXN', 'BARODA', 'BOB'],
    'Punjab National Bank': ['PNBSMS', 'PUNJAB', 'PNB'],
    'Union Bank': ['UBISMS', 'UNION', 'UBI'],
    'Indian Bank': ['IDBMSMS', 'INDIAN', 'INDBNK'],
    'IDBI Bank': ['IDBISMS', 'IDBI'],
    'IndusInd Bank': ['INDSMS', 'INDUS', 'INDUSB'],
    'Yes Bank': ['YESBNK', 'YES', 'YESB'],
    'Federal Bank': ['FEDBNK', 'FEDERAL'],
  };

  /// Request SMS reading permission from user
  Future<bool> requestSmsPermission() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  /// Check if SMS permission is already granted
  Future<bool> hasSmsPermission() async {
    return await Permission.sms.isGranted;
  }

  /// Check if SMS matches user's selected bank
  bool matchesSelectedBank(String sender, String body, String selectedBank) {
    if (selectedBank.toLowerCase() == 'other') return true;

    final keywords = _bankSenderKeywords[selectedBank];
    final upperSender = sender.toUpperCase();
    final upperBody = body.toUpperCase();
    final upperSelected = selectedBank.toUpperCase();

    if (keywords != null) {
      for (final kw in keywords) {
        if (upperSender.contains(kw) || upperBody.contains(kw)) {
          return true;
        }
      }
    }

    return upperSender.contains(upperSelected) || upperBody.contains(upperSelected);
  }

  /// Check if the SMS represents a financial DEBIT transaction
  bool isDebitTransaction(String body) {
    final lower = body.toLowerCase();

    // Ignore OTP, authentication, promotional, and loan spam
    if (lower.contains('otp') ||
        lower.contains('verification code') ||
        lower.contains('one time password') ||
        lower.contains('pre-approved') ||
        lower.contains('apply now') ||
        lower.contains('statement password') ||
        lower.contains('login attempt')) {
      return false;
    }

    // Ignore credits, refunds, and deposits
    if (lower.contains('credited') ||
        lower.contains('credit of') ||
        lower.contains('deposited') ||
        lower.contains('received rs') ||
        lower.contains('refund of')) {
      return false;
    }

    // Must contain debit indicators
    final debitKeywords = [
      'debited',
      'debit of',
      'spent',
      'paid',
      'payment of',
      'withdrawn',
      'sent rs',
      'purchase of',
      'txn of',
      'transferred rs',
      'vpa',
      'dr to',
    ];

    for (final kw in debitKeywords) {
      if (lower.contains(kw)) return true;
    }

    return false;
  }

  /// Extract numeric transaction amount
  double? extractAmount(String body) {
    // Regex for amounts like Rs.250, Rs 1,500.50, INR 450.00, Rs. 99
    final regexes = [
      RegExp(r'(?:rs\.?|inr|inr\.)\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
      RegExp(r'(?:debited\s*(?:by|with)?\s*(?:rs\.?|inr)?)\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
      RegExp(r'(?:spent\s*(?:rs\.?|inr)?)\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
      RegExp(r'(?:paid\s*(?:rs\.?|inr)?)\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
      RegExp(r'([\d,]+(?:\.\d{1,2})?)\s*(?:debited|spent|paid)', caseSensitive: false),
    ];

    for (final reg in regexes) {
      final match = reg.firstMatch(body);
      if (match != null && match.groupCount >= 1) {
        final amountStr = match.group(1)?.replaceAll(',', '').trim();
        if (amountStr != null) {
          final parsed = double.tryParse(amountStr);
          if (parsed != null && parsed > 0 && parsed < 10000000) {
            return parsed;
          }
        }
      }
    }

    return null;
  }

  /// Extract merchant or beneficiary name from SMS
  String extractMerchant(String body) {
    final lower = body.toLowerCase();

    // Check for common Indian merchants
    final knownMerchants = [
      'swiggy',
      'zomato',
      'amazon',
      'flipkart',
      'uber',
      'ola',
      'blinkit',
      'zepto',
      'bigbasket',
      'myntra',
      'nykaa',
      'dmart',
      'tataneu',
      'starbucks',
      'mcdonald',
      'kfc',
      'domino',
      'bookmyshow',
      'netflix',
      'spotify',
      'irctc',
      'makemytrip',
      'paytm',
      'google pay',
      'phonepe',
      'cred',
      'supermarket',
      'fuel',
      'petrol pump',
    ];

    for (final m in knownMerchants) {
      if (lower.contains(m)) {
        return m.toUpperCase();
      }
    }

    // Pattern matching after 'at', 'to', 'vpa', 'towards'
    final patterns = [
      RegExp(r'(?:at|to|towards|vpa|info\/)\s+([A-Za-z0-9\s\.\-_]{2,25})(?:\s+on|\s+ref|\s+dated|\s+avl|\s+bal|\.|$)', caseSensitive: false),
    ];

    for (final p in patterns) {
      final match = p.firstMatch(body);
      if (match != null && match.groupCount >= 1) {
        final candidate = match.group(1)?.trim();
        if (candidate != null &&
            candidate.length >= 2 &&
            !candidate.toLowerCase().contains('rs') &&
            !candidate.toLowerCase().contains('account') &&
            !candidate.toLowerCase().contains('bank')) {
          return candidate.toUpperCase();
        }
      }
    }

    return 'EXPENSE';
  }

  /// Extract transaction date and time from SMS text with fallback to SMS timestamp
  DateTime extractTransactionDateTime(String body, DateTime smsReceivedDate) {
    try {
      // 1. Check for explicit date/time in SMS text (e.g., 09-10-2026 at 08:35 PM, 10-OCT-2026 20:35)
      final dateRegex = RegExp(r'(\d{1,2})[-/.](\d{1,2}|[A-Za-z]{3})[-/.](\d{2,4})');
      final dateMatch = dateRegex.firstMatch(body);

      if (dateMatch != null) {
        final dayStr = dateMatch.group(1);
        final monthStr = dateMatch.group(2);
        final yearStr = dateMatch.group(3);

        if (dayStr != null && monthStr != null && yearStr != null) {
          int day = int.tryParse(dayStr) ?? smsReceivedDate.day;
          int year = int.tryParse(yearStr) ?? smsReceivedDate.year;
          if (year < 100) year += 2000;

          int month = smsReceivedDate.month;
          final monthNum = int.tryParse(monthStr);
          if (monthNum != null && monthNum >= 1 && monthNum <= 12) {
            month = monthNum;
          } else {
            const months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
            final idx = months.indexOf(monthStr.toLowerCase());
            if (idx != -1) month = idx + 1;
          }

          // Check for time (e.g. 08:35 PM or 20:35)
          final timeRegex = RegExp(r'(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(am|pm)?', caseSensitive: false);
          final timeMatch = timeRegex.firstMatch(body);

          int hour = smsReceivedDate.hour;
          int minute = smsReceivedDate.minute;

          if (timeMatch != null) {
            int parsedHour = int.tryParse(timeMatch.group(1) ?? '') ?? hour;
            int parsedMinute = int.tryParse(timeMatch.group(2) ?? '') ?? minute;
            final meridian = timeMatch.group(4)?.toLowerCase();

            if (meridian == 'pm' && parsedHour < 12) parsedHour += 12;
            if (meridian == 'am' && parsedHour == 12) parsedHour = 0;

            hour = parsedHour;
            minute = parsedMinute;
          }

          return DateTime(year, month, day, hour, minute);
        }
      }
    } catch (_) {
      // Fallback
    }

    return smsReceivedDate;
  }

  /// Parse a single SMS message into a ParsedTransaction if valid
  ParsedTransaction? parseSms(SmsMessage message, String selectedBank, DateTime trackingStartDate) {
    final sender = message.address ?? '';
    final body = message.body ?? '';
    final smsDate = message.date ?? DateTime.now();

    // 1. Bank check
    if (!matchesSelectedBank(sender, body, selectedBank)) {
      return null;
    }

    // 2. Debit check
    if (!isDebitTransaction(body)) {
      return null;
    }

    // 3. Amount check
    final amount = extractAmount(body);
    if (amount == null || amount <= 0) {
      return null;
    }

    // 4. Date & Time extraction
    final txDateTime = extractTransactionDateTime(body, smsDate);

    // 5. Tracking period check: must be >= trackingStartDate and <= now
    if (txDateTime.isBefore(trackingStartDate)) {
      return null;
    }
    if (txDateTime.isAfter(DateTime.now().add(const Duration(days: 1)))) {
      return null;
    }

    // 6. Merchant
    final merchant = extractMerchant(body);

    return ParsedTransaction(
      amount: amount,
      merchant: merchant,
      transactionDate: txDateTime,
      transactionType: 'expense',
      bank: selectedBank,
      rawSms: body,
    );
  }

  /// Scan Inbox and sync new valid transactions with the backend
  Future<int> syncInboxTransactions() async {
    final granted = await hasSmsPermission();
    if (!granted) return 0;

    final selectedBank = await AppStorage.getSelectedBank() ?? 'HDFC Bank';
    final trackingStart = await AppStorage.getTrackingStartDate() ?? DateTime.now().subtract(const Duration(days: 30));
    final userId = await AppStorage.getUserId();

    // Fetch messages from inbox
    final messages = await _query.querySms(
      kinds: [SmsQueryKind.inbox],
      count: 100,
    );

    int savedCount = 0;

    for (final msg in messages) {
      final parsed = parseSms(msg, selectedBank, trackingStart);
      if (parsed != null) {
        try {
          await transactionService.createTransaction({
            'user_id': userId,
            'amount': parsed.amount,
            'merchant': parsed.merchant,
            'transaction_type': parsed.transactionType,
            'transaction_date': parsed.transactionDate.toIso8601String(),
            'source': 'sms',
            'sms_body': parsed.rawSms,
          });
          savedCount++;
        } catch (_) {
          // Duplicate or network issue handled gracefully
        }
      }
    }

    return savedCount;
  }
}
