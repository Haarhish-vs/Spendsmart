import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/transactions/services/bank_matching_service.dart';
import 'package:mobile/features/transactions/services/sms_parser_service.dart';
import 'package:mobile/features/transactions/services/transaction_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SmsParserService parser;
  late BankMatchingService bankMatcher;

  setUp(() {
    parser = SmsParserService(TransactionService(ApiClient()));
    bankMatcher = BankMatchingService();
  });

  group('1. Bank Identification & Selected Bank Filtering Tests', () {
    test('HDFC Bank selected -> accepts HDFC, strictly ignores SBI, ICICI, Axis', () {
      expect(parser.matchesSelectedBank('VK-HDFCBK-S', 'A/c debited by Rs 250 at Swiggy', 'HDFC Bank'), isTrue);
      expect(parser.matchesSelectedBank('AD-HDFCBK', 'A/c debited by Rs 250 at Swiggy', 'HDFC Bank'), isTrue);
      expect(parser.matchesSelectedBank('BP-SBIINB-T', 'A/c debited by Rs 250 at Swiggy', 'HDFC Bank'), isFalse);
      expect(parser.matchesSelectedBank('JM-ICICIB', 'A/c debited by Rs 250 at Swiggy', 'HDFC Bank'), isFalse);
      expect(parser.matchesSelectedBank('VM-AXISBK', 'A/c debited by Rs 250 at Swiggy', 'HDFC Bank'), isFalse);
    });

    test('SBI selected -> accepts SBI, strictly ignores HDFC, ICICI, Kotak', () {
      expect(parser.matchesSelectedBank('BP-SBIINB-T', 'A/c debited by Rs 500 at Zomato', 'SBI'), isTrue);
      expect(parser.matchesSelectedBank('IM-SBIUPI', 'UPI debit of Rs 150', 'SBI'), isTrue);
      expect(parser.matchesSelectedBank('VK-HDFCBK-S', 'A/c debited by Rs 500 at Zomato', 'SBI'), isFalse);
      expect(parser.matchesSelectedBank('JM-ICICIB', 'A/c debited by Rs 500 at Zomato', 'SBI'), isFalse);
      expect(parser.matchesSelectedBank('AD-KOTAKB', 'A/c debited by Rs 500 at Zomato', 'SBI'), isFalse);
    });

    test('ICICI Bank selected -> accepts ICICI, strictly ignores others', () {
      expect(parser.matchesSelectedBank('JM-ICICIB', 'A/c debited by Rs 300 at Amazon', 'ICICI Bank'), isTrue);
      expect(parser.matchesSelectedBank('VK-HDFCBK-S', 'A/c debited by Rs 300 at Amazon', 'ICICI Bank'), isFalse);
      expect(parser.matchesSelectedBank('BP-SBIINB-T', 'A/c debited by Rs 300 at Amazon', 'ICICI Bank'), isFalse);
    });

    test('Cross-bank mention rejection: SBI message mentioning HDFC transfer is not matched to HDFC', () {
      final match = bankMatcher.matchBank(
        sender: 'BP-SBIINB-T',
        body: 'Your SBI A/c XX9999 debited by Rs 1000 for transfer to HDFC A/c',
        selectedBank: 'HDFC Bank',
      );
      expect(match.matched, isFalse);
      expect(match.diagnosticReason, contains('SBI'));
    });
  });

  group('2. Debit Transaction Identification & Rejections', () {
    test('Valid debit messages pass debit check', () {
      expect(parser.isDebitTransaction('Your HDFC Bank A/c XX1234 is debited by Rs.250.00 at SWIGGY'), isTrue);
      expect(parser.isDebitTransaction('Rs.450 spent on card XX9876 at Zomato on 10-10-2026'), isTrue);
      expect(parser.isDebitTransaction('Paid INR 1,200.00 at DMART using UPI'), isTrue);
      expect(parser.isDebitTransaction('Txn of Rs 99.00 done at Uber on 10-10-2026'), isTrue);
      expect(parser.isDebitTransaction('Withdrawn Rs.2000 from ATM on 10-10-2026'), isTrue);
    });

    test('Credit, deposit, and refund messages are ignored', () {
      expect(parser.isDebitTransaction('Your A/c XX1234 is credited with Rs. 5000.00 on 10-10-2026 by salary deposit.'), isFalse);
      expect(parser.isDebitTransaction('Refund of Rs. 250.00 processed for your Swiggy order'), isFalse);
      expect(parser.isDebitTransaction('Received INR 1000 from friend via UPI'), isFalse);
      expect(parser.isDebitTransaction('Deposited Rs.10000 into your account'), isFalse);
    });

    test('OTP, authentication, and login alerts are ignored', () {
      expect(parser.isDebitTransaction('Your OTP for HDFC Bank NetBanking login is 482910. Do not share with anyone.'), isFalse);
      expect(parser.isDebitTransaction('Use verification code 839201 to authenticate your transaction of Rs 500.'), isFalse);
      expect(parser.isDebitTransaction('Statement password for your HDFC Bank account is DOBDDMM.'), isFalse);
    });

    test('Promotional and loan offers are ignored', () {
      expect(parser.isDebitTransaction('Congratulations! You are pre-approved for a personal loan of Rs 5,00,000. Apply now.'), isFalse);
      expect(parser.isDebitTransaction('Special offer: Get flat Rs 100 discount on your next flight. Click here.'), isFalse);
    });

    test('Failed, declined, and future mandate messages are ignored', () {
      expect(parser.isDebitTransaction('Your payment of Rs. 500 at Swiggy has failed due to technical issues.'), isFalse);
      expect(parser.isDebitTransaction('Transaction of Rs. 250 declined due to insufficient funds.'), isFalse);
      expect(parser.isDebitTransaction('Mandate created: Rs 500 will be debited on 15-10-2026.'), isFalse);
    });
  });

  group('3. Amount Extraction Tests', () {
    test('Extracts amounts with ₹ (rupee symbol), Rs., and INR formats', () {
      expect(parser.extractAmount('Debited with ₹250.00 at SWIGGY'), equals(250.0));
      expect(parser.extractAmount('Debited by ₹ 1,500.50 at Amazon'), equals(1500.5));
      expect(parser.extractAmount('Spent Rs.450.00 at Zomato'), equals(450.0));
      expect(parser.extractAmount('Paid INR 99.00 at Uber'), equals(99.0));
      expect(parser.extractAmount('Txn of Rs 1200 at Dmart'), equals(1200.0));
    });

    test('Does not confuse balance or account numbers with transaction amount', () {
      const sms = 'A/c XX1234 debited by Rs.250.00 on 10-10-2026. Avl Bal: Rs.14,250.00';
      final amount = parser.extractAmount(sms);
      expect(amount, equals(250.0));
      expect(amount, isNot(equals(14250.0)));
    });
  });

  group('4. Merchant Extraction Tests', () {
    test('Identifies known merchants accurately in uppercase', () {
      expect(parser.extractMerchant('Debited by Rs.250.00 at SWIGGY on 10-10-2026'), equals('SWIGGY'));
      expect(parser.extractMerchant('Paid INR 180.00 at Uber via UPI'), equals('UBER'));
      expect(parser.extractMerchant('Spent ₹420.00 at Amazon India'), equals('AMAZON'));
      expect(parser.extractMerchant('Paid Rs 500 at Starbucks'), equals('STARBUCKS'));
    });

    test('Returns clean neutral label instead of inventing fictional merchant when unknown', () {
      const sms = 'A/c XX1234 debited by Rs.500.00 on 10-10-2026 ref 1234567890.';
      final merchant = parser.extractMerchant(sms);
      expect(merchant, equals('BANK DEBIT'));
    });
  });

  group('5. Date & Time Parsing Tests', () {
    test('Extracts explicit date and time with AM/PM format', () {
      const sms = 'Your HDFC Bank A/c XX1234 is debited by Rs.250.00 at SWIGGY on 10-10-2026 at 08:35 PM.';
      final extracted = parser.extractTransactionDateTime(sms, DateTime(2026, 10, 10, 10, 0, 0));

      expect(extracted.year, equals(2026));
      expect(extracted.month, equals(10));
      expect(extracted.day, equals(10));
      expect(extracted.hour, equals(20));
      expect(extracted.minute, equals(35));
    });

    test('Extracts date and 24-hour time format', () {
      const sms = 'Debited by Rs.450.00 at Zomato on 11-10-2026 14:15';
      final extracted = parser.extractTransactionDateTime(sms, DateTime(2026, 10, 11, 8, 0, 0));

      expect(extracted.year, equals(2026));
      expect(extracted.month, equals(10));
      expect(extracted.day, equals(11));
      expect(extracted.hour, equals(14));
      expect(extracted.minute, equals(15));
    });

    test('Falls back to SMS received timestamp when explicit date is absent in SMS body', () {
      const sms = 'A/c debited by Rs.100 at Metro.';
      final receivedDate = DateTime(2026, 10, 11, 15, 30, 0);
      final extracted = parser.extractTransactionDateTime(sms, receivedDate);

      expect(extracted, equals(receivedDate));
    });
  });

  group('6. Tracking Start Period & Rejection Diagnostics', () {
    test('Old SMS before tracking start date is rejected and logs diagnostic', () {
      final trackingStart = DateTime(2026, 10, 11, 12, 0, 0);

      // SMS from yesterday (10 Oct 2026)
      final oldMessage = SmsMessage.fromJson({
        'address': 'VK-HDFCBK-S',
        'body': 'Your HDFC Bank account is debited by Rs.250.00 at SWIGGY on 10-10-2026 at 08:35 PM.',
        'date': DateTime(2026, 10, 10, 20, 35, 0).millisecondsSinceEpoch,
      });

      final parsed = parser.parseSms(oldMessage, 'HDFC Bank', trackingStart);
      expect(parsed, isNull);

      // Verify diagnostic logged
      final recentLogs = parser.recentDiagnostics;
      expect(recentLogs.any((l) => l.reasonCode == 'BEFORE_TRACKING_START'), isTrue);
    });

    test('Valid SMS received after tracking start date is accepted', () {
      final trackingStart = DateTime(2026, 10, 11, 12, 0, 0);

      // SMS from today after tracking start (11 Oct 2026 at 15:30)
      final validMessage = SmsMessage.fromJson({
        'address': 'VK-HDFCBK-S',
        'body': 'Your HDFC Bank account is debited by Rs.250.00 at SWIGGY on 11-10-2026 at 03:30 PM.',
        'date': DateTime(2026, 10, 11, 15, 30, 0).millisecondsSinceEpoch,
      });

      final parsed = parser.parseSms(validMessage, 'HDFC Bank', trackingStart);
      expect(parsed, isNotNull);
      expect(parsed!.amount, equals(250.0));
      expect(parsed.merchant, equals('SWIGGY'));
      expect(parsed.bank, equals('HDFC Bank'));
    });

    test('SMS from a different bank logs SENDER_NOT_MATCHED diagnostic', () {
      final trackingStart = DateTime(2026, 10, 1, 0, 0, 0);

      final sbiMessage = SmsMessage.fromJson({
        'address': 'BP-SBIINB-T',
        'body': 'A/c debited by Rs.300 at McDonald on 11-10-2026 at 01:00 PM.',
        'date': DateTime(2026, 10, 11, 13, 0, 0).millisecondsSinceEpoch,
      });

      final parsed = parser.parseSms(sbiMessage, 'HDFC Bank', trackingStart);
      expect(parsed, isNull);

      final recentLogs = parser.recentDiagnostics;
      expect(recentLogs.any((l) => l.reasonCode == 'SENDER_NOT_MATCHED'), isTrue);
    });
  });
}
