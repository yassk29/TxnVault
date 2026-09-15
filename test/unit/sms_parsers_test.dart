import 'package:flutter_test/flutter_test.dart';
import 'package:txnvault/core/sms/parser/parsed_transaction.dart';
import 'package:txnvault/core/sms/parser/parser_registry.dart';

void main() {
  final registry = ParserRegistry();
  // Only used for HSBC's year-less debit-card-spend template.
  final receivedAt = DateTime(2026, 9, 12);

  test('HSBC UPI credit', () {
    final result = registry.parse(
      'JM-HSBCIN-S',
      'Your HSBC Acc XXXXXX7006 is credited for INR 1.00 on 12-Sep-26 from '
          'yassk29@slc. UPI Ref No 625554614687',
      receivedAt,
    );
    expect(result.status, SmsParseStatus.parsed);
    final txn = result.transaction!;
    expect(txn.amount, 1.00);
    expect(txn.direction, TransactionDirection.credit);
    expect(txn.bankName, 'HSBC');
    expect(txn.paymentMethodType, PaymentMethodType.upi);
    expect(txn.cardOrAccountLastFour, '7006');
    expect(txn.counterparty, 'yassk29@slc');
    expect(txn.referenceId, '625554614687');
    expect(txn.transactionDate, DateTime(2026, 9, 12));
  });

  test('HSBC debit card spend (no year in SMS)', () {
    final result = registry.parse(
      'JM-HSBCIN-S',
      'HSBC:Thank you for using HSBC Debit Card XXXXX8975 for INR 1,564.15 '
          'on 12SEP at THEHAMPTONS .Your available bal is INR 993.43 .To '
          'report fraudulent transaction call 18002673456 (local) Or '
          '+914061268007 (overseas).',
      receivedAt,
    );
    expect(result.status, SmsParseStatus.parsed);
    final txn = result.transaction!;
    expect(txn.amount, 1564.15);
    expect(txn.direction, TransactionDirection.debit);
    expect(txn.paymentMethodType, PaymentMethodType.debitCard);
    expect(txn.cardOrAccountLastFour, '8975');
    expect(txn.counterparty, 'THEHAMPTONS');
    expect(txn.availableBalanceOrLimit, 993.43);
    expect(txn.transactionDate, DateTime(2026, 9, 12));
  });

  test('HSBC bill pay debit', () {
    final result = registry.parse(
      'JM-HSBCIN-S',
      'INR 1192.39 is paid from HSBC account XXXXXX7006 to HSBC Bill pay on '
          '08-Sep-26 with ref 625113034012. If this is not done by you, call '
          '18002673456 to report.',
      receivedAt,
    );
    expect(result.status, SmsParseStatus.parsed);
    final txn = result.transaction!;
    expect(txn.amount, 1192.39);
    expect(txn.direction, TransactionDirection.debit);
    expect(txn.cardOrAccountLastFour, '7006');
    expect(txn.counterparty, 'HSBC Bill pay');
    expect(txn.referenceId, '625113034012');
    expect(txn.transactionDate, DateTime(2026, 9, 8));
  });

  test('RBL credit card spend', () {
    final result = registry.parse(
      'JM-RBLCRD-S',
      'INR958.54 spent at IRCTC TICKETING on RBL Bank credit card (7045) on '
          '12-09-2026.AVL limit- INR67,310.12. Not you? Call 02262327777',
      receivedAt,
    );
    expect(result.status, SmsParseStatus.parsed);
    final txn = result.transaction!;
    expect(txn.amount, 958.54);
    expect(txn.direction, TransactionDirection.debit);
    expect(txn.cardOrAccountLastFour, '7045');
    expect(txn.counterparty, 'IRCTC TICKETING');
    expect(txn.transactionDate, DateTime(2026, 9, 12));
    expect(txn.availableBalanceOrLimit, 67310.12);
  });

  test('RBL credit card bill payment received', () {
    final result = registry.parse(
      'JM-RBLCRD-S',
      'Payment of INR 5163.00 received on RBL Bank Credit Card XX45 on '
          '08-09-2026, Avl Limit INR 70722.58. View - '
          'https://acl.cc/RBLBNK/K5Aq9A13',
      receivedAt,
    );
    expect(result.status, SmsParseStatus.parsed);
    final txn = result.transaction!;
    expect(txn.amount, 5163.00);
    expect(txn.direction, TransactionDirection.credit);
    expect(txn.cardOrAccountLastFour, 'XX45');
  });

  test('RBL promotional loan offer is recognized but not a transaction', () {
    // Real message from JK-RBLCRD-P (note the "-P" promotional route vs "-S"
    // transactional route) - RblParser's canHandle claims it since it's from
    // RBLCRD, but none of its transaction patterns match, so it's ignored
    // rather than wrongly parsed.
    final result = registry.parse(
      'JK-RBLCRD-P',
      'Shopping plans or surprise bills? Rs.50000.0 loan on RBL Bank Credit '
          'Card (xx45) can cover it - all with a few taps.',
      receivedAt,
    );
    expect(result.status, SmsParseStatus.ignored);
    expect(result.transaction, isNull);
  });

  test('SBI P2P transfer credit', () {
    final result = registry.parse(
      'JD-SBIUPI-S',
      'Dear SBI User, your A/c X6424-credited by Rs.20220 on 14Aug26 '
          'transfer from ABHISHEK KOTADIYA Ref No 622614447868 -SBI',
      receivedAt,
    );
    expect(result.status, SmsParseStatus.parsed);
    final txn = result.transaction!;
    expect(txn.amount, 20220);
    expect(txn.direction, TransactionDirection.credit);
    expect(txn.counterparty, 'ABHISHEK KOTADIYA');
    expect(txn.transactionDate, DateTime(2026, 8, 14));
  });

  test('SBI VREF credit', () {
    final result = registry.parse(
      'AD-CBSSBI-S',
      'Your A/C XXXXX736424 has credit for VREF 36922736424 401348 03SEP2 '
          'of Rs 5,760.00 on 07/09/26. Avl Bal Rs 7,892.02.-SBI',
      receivedAt,
    );
    expect(result.status, SmsParseStatus.parsed);
    final txn = result.transaction!;
    expect(txn.amount, 5760.00);
    expect(txn.direction, TransactionDirection.credit);
    expect(txn.transactionDate, DateTime(2026, 9, 7));
    expect(txn.availableBalanceOrLimit, 7892.02);
  });

  test('SBI generic transaction successful (no date in SMS)', () {
    final result = registry.parse(
      'JD-SBIUPI-S',
      'Transaction of Rs. 5163.00 for RBL Bank Credit C... with reference '
          'no. SB416251C46F44B8MFE6 is Successful-SBI',
      receivedAt,
    );
    expect(result.status, SmsParseStatus.parsed);
    final txn = result.transaction!;
    expect(txn.amount, 5163.00);
    expect(txn.direction, TransactionDirection.debit);
    expect(txn.referenceId, 'SB416251C46F44B8MFE6');
    expect(txn.transactionDate, receivedAt);
  });

  test(
      'regression: SBI message mentioning "RBL Bank Credit C..." routes to '
      'SBI, not RBL', () {
    // This exact scenario broke when RblParser's canHandle checked body
    // text for "RBL" - it wrongly claimed this SBI-signed message before
    // SbiParser (later in the registry) got a chance to, since the SMS
    // itself mentions RBL only as a truncated third-party reference.
    // canHandle now matches on the sender's DLT code instead.
    final result = registry.parse(
      'JD-SBIUPI-S',
      'Transaction of Rs. 5163.00 for RBL Bank Credit C... with reference '
          'no. SB416251C46F44B8MFE6 is Successful-SBI',
      receivedAt,
    );
    expect(result.status, SmsParseStatus.parsed);
    expect(result.transaction!.bankName, 'SBI');
  });

  test('slice UPI sent', () {
    final result = registry.parse(
      'VA-SLCBNK-S',
      'Rs. 70 sent from a/c xx7959 on 11-Sep-26 to KHEEMESH CHANDRA (UPI '
          'Ref: 625469751235). Not you? Call 08048329999 - slice',
      receivedAt,
    );
    expect(result.status, SmsParseStatus.parsed);
    final txn = result.transaction!;
    expect(txn.amount, 70);
    expect(txn.direction, TransactionDirection.debit);
    expect(txn.counterparty, 'KHEEMESH CHANDRA');
    expect(txn.referenceId, '625469751235');
  });

  test('slice credit card spend', () {
    final result = registry.parse(
      'VA-SLCEIT-S',
      'Rs. 100 spent on your credit card xx7174 at Ramesh paneru on '
          '04-Sep-26 (UPI Ref: 624787144001). Not you? Call 080-4832-9999 '
          '- slice',
      receivedAt,
    );
    expect(result.status, SmsParseStatus.parsed);
    final txn = result.transaction!;
    expect(txn.amount, 100);
    expect(txn.direction, TransactionDirection.debit);
    expect(txn.paymentMethodType, PaymentMethodType.creditCard);
    expect(txn.counterparty, 'Ramesh paneru');
  });

  test('slice UPI received', () {
    final result = registry.parse(
      'VA-SLCBNK-S',
      'Rs. 4,000 received in slice A/c xx7959 on 10-Sep-26 from KHEEMESH '
          'CHANDRA via UPI (Ref ID: 129378969312). Avl. Bal. Rs. 8,081.28 '
          '- slice',
      receivedAt,
    );
    expect(result.status, SmsParseStatus.parsed);
    final txn = result.transaction!;
    expect(txn.amount, 4000);
    expect(txn.direction, TransactionDirection.credit);
    expect(txn.counterparty, 'KHEEMESH CHANDRA');
    expect(txn.availableBalanceOrLimit, 8081.28);
  });

  test('slice UPI AutoPay debit', () {
    final result = registry.parse(
      'VA-SLCBNK-S',
      'Successfully paid Rs.1 from slice a/c XX7959 to E Eighteen Com '
          'Limited on 06-Sep-26 via UPI AutoPay. UMN - '
          '01a07363db897cb0825ab83d3a3f14d8@slc - slice',
      receivedAt,
    );
    expect(result.status, SmsParseStatus.parsed);
    final txn = result.transaction!;
    expect(txn.amount, 1);
    expect(txn.direction, TransactionDirection.debit);
    expect(txn.counterparty, 'E Eighteen Com Limited');
    expect(txn.transactionDate, DateTime(2026, 9, 6));
  });

  test('slice UPI AutoPay debit from savings a/c', () {
    final result = registry.parse(
      'VA-SLCBNK-S',
      'Successfully paid Rs.2 from slice savings a/c XX7959 to Google on '
          '02-May-26 via UPI AutoPay. UMN - '
          '019de804132a7db3b233a59ad6dcd72b@slc - slice(NESFB)',
      receivedAt,
    );
    expect(result.status, SmsParseStatus.parsed);
    expect(result.transaction!.amount, 2);
  });

  test('IDFC FIRST credit card spend', () {
    final result = registry.parse(
      'CP-IDFCFB-S',
      'Delicious Purchase! INR 499.00 spent on your IDFC FIRST Bank Credit '
          'Card ending XX3663 at RAJASTHALI on 30 AUG 2026 at 03:45 PM Avbl '
          'Limit: INR 341865.91 If not done by you, call 180010888 for '
          'dispute or to block your card SMS CCBLOCK 3663 to 5676732',
      receivedAt,
    );
    expect(result.status, SmsParseStatus.parsed);
    final txn = result.transaction!;
    expect(txn.amount, 499.00);
    expect(txn.direction, TransactionDirection.debit);
    expect(txn.cardOrAccountLastFour, '3663');
    expect(txn.counterparty, 'RAJASTHALI');
    expect(txn.transactionDate, DateTime(2026, 8, 30, 15, 45));
  });

  test('IDFC FIRST credit card bill payment received', () {
    final result = registry.parse(
      'CP-IDFCFB-S',
      'Thank you for payment of INR 7,635.09 towards your FIRST Select '
          'Credit Card XX3663 on 07 Sep 2026. IDFC FIRST Bank',
      receivedAt,
    );
    expect(result.status, SmsParseStatus.parsed);
    final txn = result.transaction!;
    expect(txn.amount, 7635.09);
    expect(txn.direction, TransactionDirection.credit);
    expect(txn.cardOrAccountLastFour, '3663');
    expect(txn.transactionDate, DateTime(2026, 9, 7));
  });

  test('ICICI credit card spend', () {
    final result = registry.parse(
      'JD-ICICIT-S',
      'INR 408.00 spent using ICICI Bank Card XX3009 on 16-Aug-26 on AMAZON '
          'PAY IN G. Avl Limit: INR 1,22,888.77. If not you, call 1800 '
          '2662/SMS BLOCK 3009 to 9215676766.',
      receivedAt,
    );
    expect(result.status, SmsParseStatus.parsed);
    final txn = result.transaction!;
    expect(txn.amount, 408.00);
    expect(txn.cardOrAccountLastFour, '3009');
    expect(txn.counterparty, 'AMAZON PAY IN G');
    expect(txn.availableBalanceOrLimit, 122888.77);
  });

  test('HDFC credit card spend', () {
    final result = registry.parse(
      'AD-HDFCBK-S',
      'Spent Rs.326 On HDFC Bank Card 3804 At BLINKIT On '
          '2026-09-05:21:08:37.Not You? To Block+Reissue Call '
          '18002586161/SMS BLOCK CC 3804 to 7308080808',
      receivedAt,
    );
    expect(result.status, SmsParseStatus.parsed);
    final txn = result.transaction!;
    expect(txn.amount, 326);
    expect(txn.cardOrAccountLastFour, '3804');
    expect(txn.counterparty, 'BLINKIT');
    expect(txn.transactionDate, DateTime(2026, 9, 5, 21, 8, 37));
  });

  test('IndusInd credit card spend', () {
    final result = registry.parse(
      'VM-INDUSB',
      'INR 71.64 spent on IndusInd Card XX0986 on 11-04-2026 09:19:45 am at '
          'DMRC. Avl Lmt: INR 102,928.36. To dispute, call '
          '18602677777/SMS BLOCK 0986 to 5676757',
      receivedAt,
    );
    expect(result.status, SmsParseStatus.parsed);
    final txn = result.transaction!;
    expect(txn.amount, 71.64);
    expect(txn.cardOrAccountLastFour, '0986');
    expect(txn.counterparty, 'DMRC');
    expect(txn.transactionDate, DateTime(2026, 4, 11, 9, 19, 45));
    expect(txn.availableBalanceOrLimit, 102928.36);
  });

  test('Federal Bank UPI debit', () {
    final result = registry.parse(
      'TX-FEDBNK',
      'Rs 5169.32 debited via UPI on 05-12-2024 19:00:25 to VPA '
          'northeastsmallf678832.rzp@rxairtel.Ref No 434056447727.Small '
          'txns?Use UPI Lite!-Federal Bank',
      receivedAt,
    );
    expect(result.status, SmsParseStatus.parsed);
    final txn = result.transaction!;
    expect(txn.amount, 5169.32);
    expect(txn.direction, TransactionDirection.debit);
    expect(txn.counterparty, 'northeastsmallf678832.rzp@rxairtel');
    expect(txn.referenceId, '434056447727');
    expect(txn.transactionDate, DateTime(2024, 12, 5, 19, 0, 25));
  });

  test('Federal Bank UPI debit (from your A/c phrasing)', () {
    final result = registry.parse(
      'TX-FEDBNK',
      'Rs 1000.00 debited from your A/c via UPI on 06-05-2024 15:23:24 to '
          'VPA 00000036922736424@SBIN0060353.ifsc.npci.Ref No '
          '412762335781.Small txns?Use UPI Lite!-Federal Bank',
      receivedAt,
    );
    expect(result.status, SmsParseStatus.parsed);
    expect(result.transaction!.amount, 1000.00);
  });

  test('Federal Bank IMPS credit', () {
    final result = registry.parse(
      'VM-FEDBNK',
      'Rs.316000 credited to your A/c XX2172 via IMPS on 16JUN2024 '
          '10:48:12. (IMPS Ref no-416810603307) BAL-Rs.321634.31 -Federal '
          'Bank',
      receivedAt,
    );
    expect(result.status, SmsParseStatus.parsed);
    final txn = result.transaction!;
    expect(txn.amount, 316000);
    expect(txn.direction, TransactionDirection.credit);
    expect(txn.cardOrAccountLastFour, '2172');
    expect(txn.referenceId, '416810603307');
    expect(txn.transactionDate, DateTime(2024, 6, 16, 10, 48, 12));
    expect(txn.availableBalanceOrLimit, 321634.31);
  });

  test('Federal Bank FEDNET debit', () {
    final result = registry.parse(
      'CP-FEDBNK',
      'Dear Customer, Thank you for using FEDNET.Rs.15174.37 debited from '
          'your A/c XX2172 on 13OCT2024 16:01:16. BAL-Rs.48651.90-Federal '
          'Bank',
      receivedAt,
    );
    expect(result.status, SmsParseStatus.parsed);
    final txn = result.transaction!;
    expect(txn.amount, 15174.37);
    expect(txn.direction, TransactionDirection.debit);
    expect(txn.transactionDate, DateTime(2024, 10, 13, 16, 1, 16));
  });

  test('Federal Bank card spend', () {
    final result = registry.parse(
      'TX-FEDBNK',
      'Rs 96256.52 spent@Dreamplug  on 14AUG24 13:49.BAL:Rs 8667.36.'
          'Dispute/Not you?Click https://fbl.ai/a/dp /call '
          '18004251199/SMS NO 2172 to 9895088888-Federal Bank',
      receivedAt,
    );
    expect(result.status, SmsParseStatus.parsed);
    final txn = result.transaction!;
    expect(txn.amount, 96256.52);
    expect(txn.counterparty, 'Dreamplug');
    expect(txn.transactionDate, DateTime(2024, 8, 14));
  });

  test('Federal Bank UPI AutoPay mandate executed', () {
    final result = registry.parse(
      'JG-FEDBNK',
      'Dear Customer, Your mandate with ref no- '
          'a0365ebd6e54468e9b6052407de01371@pingpay registered against '
          'SAAVN for Rs 2.00 successfully executed on 01-07-2024 21:41:07. '
          'TXN Ref No -418329060742- Federal Bank',
      receivedAt,
    );
    expect(result.status, SmsParseStatus.parsed);
    final txn = result.transaction!;
    expect(txn.amount, 2.00);
    expect(txn.direction, TransactionDirection.debit);
    expect(txn.counterparty, 'SAAVN');
    expect(txn.transactionDate, DateTime(2024, 7, 1, 21, 41, 7));
  });

  test('Federal Bank mandate creation is an autopay reference, not a '
      'transaction', () {
    final result = registry.parse(
      'JG-FEDBNK',
      'Dear Customer, You have successfully created a mandate on SAAVN for '
          'a ASPRESENTED frequency starting from 01-07-2024 for a maximum '
          'amount of Rs 89.00 Mandate Ref No- '
          'a0365ebd6e54468e9b6052407de01371@pingpay - Federal Bank',
      receivedAt,
    );
    expect(result.status, SmsParseStatus.autopayReference);
    expect(result.transaction, isNull);
    final event = result.autopayEvent!;
    expect(event.eventType, AutopayEventType.created);
    expect(event.merchantName, 'SAAVN');
    expect(event.amount, 89.00);
    expect(event.eventDate, DateTime(2024, 7, 1));
  });

  test('slice UPI AutoPay created', () {
    final result = registry.parse(
      'VA-SLCBNK-S',
      "UPI AutoPay successfully created towards NETWORK18 MEDIA and "
          "INVESTMENTS LIMITED from 06 Sep '26 to 31 Dec '50 for Rs. 149 "
          "with QUARTERLY frequency. 01a07363db897cb0825ab83d3a3f14d8@slc. "
          "If not you, call 080-4832-9999 - slice",
      receivedAt,
    );
    expect(result.status, SmsParseStatus.autopayReference);
    expect(result.transaction, isNull);
    final event = result.autopayEvent!;
    expect(event.eventType, AutopayEventType.created);
    expect(event.merchantName, 'NETWORK18 MEDIA and INVESTMENTS LIMITED');
    expect(event.amount, 149);
    expect(event.eventDate, DateTime(2026, 9, 6));
  });

  test('slice UPI AutoPay revoked', () {
    final result = registry.parse(
      'VA-SLCBNK-S',
      'UPI AutoPay for NETWORK18 MEDIA and INVESTMENTS LIMITED from slice '
          'a/c XX7959 for Rs. 149 is revoked. UMN - '
          '01a07363db897cb0825ab83d3a3f14d8',
      receivedAt,
    );
    expect(result.status, SmsParseStatus.autopayReference);
    expect(result.transaction, isNull);
    final event = result.autopayEvent!;
    expect(event.eventType, AutopayEventType.revoked);
    expect(event.merchantName, 'NETWORK18 MEDIA and INVESTMENTS LIMITED');
    expect(event.amount, 149);
  });

  test('RBL credit card bill payment is tagged as a repayment', () {
    final result = registry.parse(
      'JM-RBLCRD-S',
      'Payment of INR 5163.00 received on RBL Bank Credit Card XX45 on '
          '08-09-2026, Avl Limit INR 70722.58. View - '
          'https://acl.cc/RBLBNK/K5Aq9A13',
      receivedAt,
    );
    expect(result.transaction!.category, TransactionKind.repayment);
  });

  test('IDFC FIRST credit card bill payment is tagged as a repayment', () {
    final result = registry.parse(
      'CP-IDFCFB-S',
      'Thank you for payment of INR 7,635.09 towards your FIRST Select '
          'Credit Card XX3663 on 07 Sep 2026. IDFC FIRST Bank',
      receivedAt,
    );
    expect(result.transaction!.category, TransactionKind.repayment);
  });

  test('SBI generic transaction successful is tagged as a repayment', () {
    final result = registry.parse(
      'JD-SBIUPI-S',
      'Transaction of Rs. 5163.00 for RBL Bank Credit C... with reference '
          'no. SB416251C46F44B8MFE6 is Successful-SBI',
      receivedAt,
    );
    expect(result.transaction!.category, TransactionKind.repayment);
  });

  test('IPO fund blocked is an autopay-style "created" reference event', () {
    final result = registry.parse(
      'AD-NSEIPO-S',
      'Dear ILBXXXXX0E IPO Kanohar Electricals Limited : App no '
          'GROWW9b19b1e88fb UPI ID yassk29@slc for Rs 72680.00 received. '
          'Please check for UPI-mandate',
      receivedAt,
    );
    expect(result.status, SmsParseStatus.autopayReference);
    final event = result.autopayEvent!;
    expect(event.eventType, AutopayEventType.created);
    expect(event.merchantName, 'Kanohar Electricals Limited');
    expect(event.amount, 72680.00);
    expect(event.referenceId, 'GROWW9b19b1e88fb');
  });

  test('IPO fund unblocked (non-allotment) - MUFGIN phrasing', () {
    final result = registry.parse(
      'TM-MUFGIN-S',
      'Informed your Bnk. to unblk Rs. 72680.00 for KANOHAR IPO applno '
          'GROWW9B19B1E88FB due to non-allotment. Pls contact your bank if '
          'req. MUFGIN',
      receivedAt,
    );
    expect(result.status, SmsParseStatus.autopayReference);
    final event = result.autopayEvent!;
    expect(event.eventType, AutopayEventType.revoked);
    expect(event.merchantName, 'KANOHAR');
    expect(event.amount, 72680.00);
    expect(event.referenceId, 'GROWW9B19B1E88FB');
  });

  test('IPO fund unblocked (non-allotment) - BSSIPO phrasing with "aplno"',
      () {
    final result = registry.parse(
      'JD-BSSIPO-S',
      'Informed your Bank to unblk Rs. 14999 for HTEL IPO aplno '
          'GROWW65e99aa81a6 due to non-allotment. Pls contact your bank if '
          'req.',
      receivedAt,
    );
    expect(result.status, SmsParseStatus.autopayReference);
    expect(result.autopayEvent!.amount, 14999);
    expect(result.autopayEvent!.merchantName, 'HTEL');
  });

  test('IPO fund unblocked (non-allotment) - KFINCR phrasing with "unblock"',
      () {
    final result = registry.parse(
      'VK-KFINCR-S',
      'Your bank is instructed to unblock Rs. 45000.00 for TEMPSENS IPO '
          'applno. GROWW328d618936a due to non-allotment. Please contact',
      receivedAt,
    );
    expect(result.status, SmsParseStatus.autopayReference);
    expect(result.autopayEvent!.amount, 45000.00);
    expect(result.autopayEvent!.merchantName, 'TEMPSENS');
  });

  test('IPO fund unblocked (non-allotment) - LNKRTA "has been instructed"',
      () {
    final result = registry.parse(
      'AX-LNKRTA',
      'Your bank has been instructed to unblock Rs. 15000.00 for TATATECH '
          'IPO applno TATA124384655429 due to non-allotment. Please contact',
      receivedAt,
    );
    expect(result.status, SmsParseStatus.autopayReference);
    expect(result.autopayEvent!.merchantName, 'TATATECH');
    expect(result.autopayEvent!.referenceId, 'TATA124384655429');
  });

  test('IPO shares allotted is a real transaction (debit)', () {
    final result = registry.parse(
      'AD-NSEIPO',
      'Dear ILBXXXXX0E IPO DAM Capital Advisors Limited: 53 shares allotted '
          'at Rs 283.00 for App no GROWW84847528. Refer registered email id '
          'for details- NSEIL',
      receivedAt,
    );
    expect(result.status, SmsParseStatus.parsed);
    final txn = result.transaction!;
    expect(txn.direction, TransactionDirection.debit);
    expect(txn.amount, 283.00 * 53);
    expect(txn.counterparty, 'DAM Capital Advisors Limited');
  });

  test('unrelated SMS is left unmatched', () {
    final result = registry.parse(
      'AIRTEL',
      'Your OTP for login is 483920. Do not share it with anyone.',
      receivedAt,
    );
    expect(result.status, SmsParseStatus.unmatched);
    expect(result.transaction, isNull);
  });
}
