import 'package:flutter/foundation.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/app_storage.dart';
import 'bank_matching_service.dart';
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

/// Safe diagnostic log entry without sensitive details (no full SMS, no OTP, no acct numbers)
class SmsDiagnosticLog {
  final DateTime timestamp;
  final String reasonCode;
  final String safeMessage;
  final double? amount;

  const SmsDiagnosticLog({
    required this.timestamp,
    required this.reasonCode,
    required this.safeMessage,
    this.amount,
  });

  @override
  String toString() =>
      '[${timestamp.toIso8601String()}] [$reasonCode] $safeMessage ${amount != null ? "(Amount: $amount)" : ""}';
}

class SmsParserService {
  final TransactionService transactionService;
  final BankMatchingService bankMatchingService = BankMatchingService();
  final SmsQuery _query = SmsQuery();

  // Diagnostics log buffer (holds last 100 safe events for inspection)
  final List<SmsDiagnosticLog> _diagnostics = [];

  SmsParserService(this.transactionService);

  List<SmsDiagnosticLog> get recentDiagnostics => List.unmodifiable(_diagnostics);

  void _logDiagnostic(String reasonCode, String safeMessage, [double? amount]) {
    final entry = SmsDiagnosticLog(
      timestamp: DateTime.now(),
      reasonCode: reasonCode,
      safeMessage: safeMessage,
      amount: amount,
    );
    if (_diagnostics.length >= 100) {
      _diagnostics.removeAt(0);
    }
    _diagnostics.add(entry);
    debugPrint('[SpendSmart SMS] $entry');
  }

  /// Request SMS reading permission from user
  Future<bool> requestSmsPermission() async {
    final status = await Permission.sms.request();
    if (!status.isGranted) {
      _logDiagnostic('SMS_PERMISSION_UNAVAILABLE', 'SMS read permission was denied by user');
    }
    return status.isGranted;
  }

  /// Check if SMS permission is already granted
  Future<bool> hasSmsPermission() async {
    return await Permission.sms.isGranted;
  }

  /// Check if SMS matches user's selected bank via BankMatchingService
  bool matchesSelectedBank(String sender, String body, String selectedBank) {
    final result = bankMatchingService.matchBank(
      sender: sender,
      body: body,
      selectedBank: selectedBank,
    );
    return result.matched;
  }

  /// Check if the SMS represents a financial DEBIT transaction
  bool isDebitTransaction(String body) {
    final lower = body.toLowerCase();

    // 1. Strictly ignore OTP, authentication, login attempts, passwords
    if (lower.contains('otp') ||
        lower.contains('one time password') ||
        lower.contains('verification code') ||
        lower.contains('security code') ||
        lower.contains('login attempt') ||
        lower.contains('statement password') ||
        lower.contains('do not share') ||
        lower.contains('secret code') ||
        lower.contains('to authenticate') ||
        lower.contains('valid for ')) {
      return false;
    }

    // 2. Strictly ignore promotions, loan offers, credit card limit offers
    if (lower.contains('pre-approved') ||
        lower.contains('apply now') ||
        lower.contains('click here') ||
        lower.contains('avail loan') ||
        lower.contains('special offer') ||
        lower.contains('congratulations') ||
        lower.contains('limit increase') ||
        lower.contains('reward points') ||
        lower.contains('cashback of up to')) {
      return false;
    }

    // 3. Strictly ignore failed, declined, timed out, cancelled transactions
    if (lower.contains('declined') ||
        lower.contains('failed') ||
        lower.contains('unsuccessful') ||
        lower.contains('cancelled') ||
        lower.contains('timed out') ||
        lower.contains('insufficient funds')) {
      return false;
    }

    // 4. Strictly ignore scheduled auto-debits, future mandates, payment requests
    if (lower.contains('mandate created') ||
        lower.contains('will be debited') ||
        lower.contains('scheduled on') ||
        lower.contains('request to pay') ||
        lower.contains('due on') ||
        lower.contains('bill generated') ||
        lower.contains('minimum amount due')) {
      return false;
    }

    // 5. Strictly ignore credits, refunds, reversals, deposits
    if (lower.contains('credited') ||
        lower.contains('credit of') ||
        lower.contains('is credited') ||
        lower.contains('deposited') ||
        lower.contains('received rs') ||
        lower.contains('received inr') ||
        lower.contains('received ₹') ||
        lower.contains('cr to a/c') ||
        lower.contains('cr to') ||
        lower.contains('cr.') ||
        lower.contains('refund of') ||
        lower.contains('reversal of') ||
        lower.contains('refund processed') ||
        lower.contains('amount added to')) {
      return false;
    }

    // 6. Must contain recognized debit indicators
    final debitKeywords = [
      'debited',
      'debit of',
      'spent',
      'paid',
      'payment of',
      'withdrawn',
      'purchase of',
      'txn of',
      'transaction of',
      'transferred rs',
      'transferred inr',
      'transferred ₹',
      'transferred to',
      'sent rs',
      'sent inr',
      'sent ₹',
      'sent to',
      'dr to',
      'dr.',
    ];

    for (final kw in debitKeywords) {
      if (lower.contains(kw)) return true;
    }

    return false;
  }

  /// Extract numeric transaction amount
  /// Supports: Rs. 250, Rs.250.00, INR 450, INR 1,500.50, ₹250.00, ₹ 500, etc.
  /// Prioritizes debit-linked amounts and ignores account/card numbers or balance strings.
  double? extractAmount(String body) {
    // 1. High priority: Amount directly paired with debit verb or action
    final priorityRegexes = [
      RegExp(r'(?:debited\s*(?:by|for|with|from)?\s*(?:rs\.?|inr|₹)?)\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
      RegExp(r'(?:spent\s*(?:rs\.?|inr|₹)?)\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
      RegExp(r'(?:paid\s*(?:rs\.?|inr|₹)?)\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
      RegExp(r'(?:(?:txn|transaction)\s*of\s*(?:rs\.?|inr|₹)?)\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
      RegExp(r'(?:(?:sent|transferred)\s*(?:rs\.?|inr|₹)?)\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
      RegExp(r'(?:purchase\s*of\s*(?:rs\.?|inr|₹)?)\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
      RegExp(r'([\d,]+(?:\.\d{1,2})?)\s*(?:debited|spent|paid|withdrawn)', caseSensitive: false),
    ];

    for (final reg in priorityRegexes) {
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

    // 2. Secondary check: Standard currency tokens (Rs, INR, ₹), ensuring it's not preceded by balance/limit/card words
    final currencyRegex = RegExp(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false);
    final allMatches = currencyRegex.allMatches(body);

    for (final match in allMatches) {
      final matchStart = match.start;
      final precedingText = body.substring(0, matchStart).toLowerCase();

      // Check if this match is likely an available balance, card limit, or account balance
      final isBalance = precedingText.endsWith('bal ') ||
          precedingText.endsWith('bal: ') ||
          precedingText.endsWith('avl bal ') ||
          precedingText.endsWith('avl bal: ') ||
          precedingText.endsWith('balance ') ||
          precedingText.endsWith('balance: ') ||
          precedingText.endsWith('limit ') ||
          precedingText.endsWith('limit: ');

      if (!isBalance) {
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
  /// Does not invent fictional merchants when unidentified.
  String extractMerchant(String body) {
    final lower = body.toLowerCase();

    // Known merchants commonly used in India
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
      'rapido',
      'airtel',
      'jio',
      'bescom',
      'fuel',
      'petrol pump',
    ];

    for (final m in knownMerchants) {
      if (lower.contains(m)) {
        return m.toUpperCase();
      }
    }

    // Pattern matching after 'at', 'to', 'vpa', 'towards', 'info/'
    final patterns = [
      RegExp(r'(?:at|to|towards|vpa|info\/)\s+([A-Za-z0-9\s\.\-_&@]{2,25})(?:\s+on|\s+ref|\s+dated|\s+avl|\s+bal|\s+via|\.|$|,)', caseSensitive: false),
    ];

    for (final p in patterns) {
      final match = p.firstMatch(body);
      if (match != null && match.groupCount >= 1) {
        final candidate = match.group(1)?.trim();
        if (candidate != null &&
            candidate.length >= 2 &&
            !candidate.toLowerCase().contains('rs') &&
            !candidate.toLowerCase().contains('inr') &&
            !candidate.toLowerCase().contains('account') &&
            !candidate.toLowerCase().contains('bank')) {
          return candidate.toUpperCase();
        }
      }
    }

    // If no distinct merchant identified, return neutral label without inventing fake merchants
    return 'BANK DEBIT';
  }

  /// Extract transaction date and time from SMS text with fallback to SMS timestamp
  DateTime extractTransactionDateTime(String body, DateTime smsReceivedDate) {
    try {
      // 1. Check for explicit date in SMS text
      // Supports formats: DD-MM-YYYY, DD/MM/YYYY, DD.MM.YYYY, DD-Mon-YYYY, DD Mon YYYY, DD-MM-YY, DD/MM/YY
      final dateRegex = RegExp(r'(\d{1,2})[-/. ](\d{1,2}|[A-Za-z]{3})[-/. ](\d{2,4})');
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

          // Check for time (e.g., 08:35 PM, 20:35, 13:00)
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
      // Fallback to SMS received timestamp
    }

    return smsReceivedDate;
  }

  /// Parse a single SMS message into a ParsedTransaction if valid, or record diagnostic reason
  ParsedTransaction? parseSms(
    SmsMessage message,
    String selectedBank,
    DateTime trackingStartDate,
  ) {
    final sender = message.address ?? '';
    final body = message.body ?? '';
    final smsDate = message.date ?? DateTime.now();

    // 1. Bank check using BankMatchingService
    final bankResult = bankMatchingService.matchBank(
      sender: sender,
      body: body,
      selectedBank: selectedBank,
    );

    if (!bankResult.matched) {
      _logDiagnostic('SENDER_NOT_MATCHED', bankResult.diagnosticReason ?? 'Sender did not match selected bank');
      return null;
    }

    // 2. Debit check
    if (!isDebitTransaction(body)) {
      _logDiagnostic('NOT_DEBIT_TRANSACTION', 'Message is not a debit transaction (credit, OTP, or non-financial)');
      return null;
    }

    // 3. Amount check
    final amount = extractAmount(body);
    if (amount == null || amount <= 0) {
      _logDiagnostic('AMOUNT_EXTRACTION_FAILED', 'Could not extract valid financial amount from SMS');
      return null;
    }

    // 4. Date & Time extraction
    final txDateTime = extractTransactionDateTime(body, smsDate);

    // 5. Tracking period check: must be >= beginning of trackingStartDate and <= future buffer
    final trackingDayStart = DateTime(trackingStartDate.year, trackingStartDate.month, trackingStartDate.day);
    if (txDateTime.isBefore(trackingDayStart)) {
      _logDiagnostic(
        'BEFORE_TRACKING_START',
        'Transaction date is earlier than tracking start date',
        amount,
      );
      return null;
    }

    if (txDateTime.isAfter(DateTime.now().add(const Duration(days: 1)))) {
      _logDiagnostic('DATE_EXTRACTION_FAILED', 'Extracted transaction date is in future', amount);
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
    if (!granted) {
      _logDiagnostic('SMS_PERMISSION_UNAVAILABLE', 'Cannot sync inbox: SMS permission is not granted');
      return 0;
    }

    String? selectedBank = await AppStorage.getSelectedBank();
    String? userId = await AppStorage.getUserId();
    DateTime? storedTrackingStart = await AppStorage.getTrackingStartDate();

    // Fallback: If bank or user not in local storage, attempt to sync from /profile/init
    if (selectedBank == null || selectedBank.trim().isEmpty || userId == null) {
      try {
        final client = ApiClient();
        final initRes = await client.get('/profile/init');
        if (initRes is Map<String, dynamic> && initRes['data'] != null) {
          final data = initRes['data'] as Map<String, dynamic>;
          final fetchedUserId = data['id'] as String?;
          final fetchedBank = data['selected_bank'] as String?;
          final fetchedStart = data['tracking_start'] as String?;

          if (fetchedUserId != null) {
            userId = fetchedUserId;
            await AppStorage.setUserId(fetchedUserId);
          }
          if (fetchedBank != null && fetchedBank.isNotEmpty) {
            selectedBank = fetchedBank;
            await AppStorage.setSelectedBank(fetchedBank);
          }
          if (fetchedStart != null) {
            storedTrackingStart = DateTime.tryParse(fetchedStart);
            await AppStorage.setTrackingStartDate(fetchedStart);
          }
        }
      } catch (e) {
        debugPrint('[SpendSmart SMS] Profile init fallback error: $e');
      }
    }

    if (selectedBank == null || selectedBank.trim().isEmpty) {
      _logDiagnostic('SELECTED_BANK_MISSING', 'Cannot sync inbox: User has not selected a bank in onboarding');
      return 0;
    }

    final trackingStart = storedTrackingStart ?? DateTime.now().subtract(const Duration(days: 30));
    // Normalize to beginning of the tracking day (00:00:00) so same-day transactions are preserved
    final trackingDayStart = DateTime(trackingStart.year, trackingStart.month, trackingStart.day);

    // Fetch messages from inbox
    List<SmsMessage> messages = [];
    try {
      messages = await _query.querySms(
        kinds: [SmsQueryKind.inbox],
        count: 100,
      );
    } catch (e) {
      _logDiagnostic('SMS_QUERY_FAILED', 'Failed to read inbox from device: $e');
      return 0;
    }

    int savedCount = 0;

    for (final msg in messages) {
      final parsed = parseSms(msg, selectedBank, trackingDayStart);
      if (parsed != null) {
        try {
          final res = await transactionService.createTransaction({
            'user_id': userId,
            'amount': parsed.amount,
            'merchant': parsed.merchant,
            'transaction_type': parsed.transactionType,
            'transaction_date': parsed.transactionDate.toIso8601String(),
            'source': 'sms',
            'sms_body': parsed.rawSms,
          });

          if (res is Map<String, dynamic> && res['data']?['is_duplicate'] == true) {
            _logDiagnostic('DUPLICATE_TRANSACTION', 'Transaction already exists in database', parsed.amount);
          } else {
            _logDiagnostic('TRANSACTION_SAVED', 'Extracted valid debit transaction for ${parsed.merchant}', parsed.amount);
            savedCount++;
          }
        } catch (e) {
          _logDiagnostic('BACKEND_REQUEST_FAILED', 'Backend request failed: $e', parsed.amount);
        }
      }
    }

    return savedCount;
  }
}
