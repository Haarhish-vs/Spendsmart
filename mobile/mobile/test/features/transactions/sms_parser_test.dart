import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/transactions/services/sms_parser_service.dart';
import 'package:mobile/features/transactions/services/transaction_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SmsParserService parser;

  setUp(() {
    parser = SmsParserService(TransactionService(ApiClient()));
  });

  group('SMS Parser & Filtering Unit Tests', () {
    test('CASE 3: HDFC selected -> processes HDFC and ignores SBI / ICICI', () {
      // HDFC SMS
      final hdfcMatch = parser.matchesSelectedBank('VK-HDFCBK-S', 'A/c debited by Rs 250 at Swiggy', 'HDFC Bank');
      expect(hdfcMatch, isTrue);

      // SBI SMS
      final sbiMatch = parser.matchesSelectedBank('BP-SBIINB-T', 'A/c debited by Rs 250 at Swiggy', 'HDFC Bank');
      expect(sbiMatch, isFalse);

      // ICICI SMS
      final iciciMatch = parser.matchesSelectedBank('JM-ICICIB', 'A/c debited by Rs 250 at Swiggy', 'HDFC Bank');
      expect(iciciMatch, isFalse);
    });

    test('CASE 4: Credit SMS from selected bank is ignored', () {
      const creditSms = 'Your A/c XX1234 is credited with Rs. 5000.00 on 10-10-2026 by salary deposit.';
      expect(parser.isDebitTransaction(creditSms), isFalse);
    });

    test('CASE 10: Non-financial / OTP SMS is ignored', () {
      const otpSms = 'Your OTP for HDFC Bank NetBanking login is 482910. Do not share with anyone.';
      expect(parser.isDebitTransaction(otpSms), isFalse);
    });

    test('CASE 8: SMS with explicit transaction date and time extracts correctly', () {
      const smsBody = 'Your HDFC Bank A/c XX1234 is debited by Rs.250.00 at SWIGGY on 10-10-2026 at 08:35 PM.';
      final extracted = parser.extractTransactionDateTime(smsBody, DateTime(2026, 10, 10, 10, 0, 0));

      expect(extracted.year, equals(2026));
      expect(extracted.month, equals(10));
      expect(extracted.day, equals(10));
      expect(extracted.hour, equals(20));
      expect(extracted.minute, equals(35));
    });

    test('Amount and Merchant extraction tests', () {
      const sms = 'Your HDFC Bank A/c XX1234 is debited by Rs.450.00 at ZOMATO on 10-10-2026 13:00';
      final amount = parser.extractAmount(sms);
      final merchant = parser.extractMerchant(sms);

      expect(amount, equals(450.0));
      expect(merchant, equals('ZOMATO'));
    });
  });
}
