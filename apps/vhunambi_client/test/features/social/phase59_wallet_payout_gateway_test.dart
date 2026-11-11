import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/payout_details_sheet.dart';
import 'package:vhunambi_client/features/social/data/repositories/http_social_repository.dart';
import 'package:vhunambi_client/features/social/presentation/providers/creator_wallet_provider.dart';
import 'package:vhunambi_client/features/social/presentation/providers/social_repository_provider.dart';

class _StubDioAdapter implements HttpClientAdapter {
  _StubDioAdapter(this._handler);

  final Future<ResponseBody> Function(RequestOptions options) _handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return _handler(options);
  }
}

ResponseBody _jsonResponse(Map<String, dynamic> body, {int statusCode = 200}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 59 M59.5: SA Banking Gateway & Payout Rail Convergence', () {
    test(
      'SaBankRegistry supports all 6 canonical SA banks, aliases, & Capitec Pay rules',
      () {
        expect(SaBankRegistry.banks.length, 6);
        expect(SaBankRegistry.universalBranchCodeFor('Capitec'), '470010');
        expect(SaBankRegistry.universalBranchCodeFor('Capitec Bank'), '470010');
        expect(SaBankRegistry.universalBranchCodeFor('FNB'), '250655');
        expect(
          SaBankRegistry.universalBranchCodeFor('First National Bank'),
          '250655',
        );
        expect(
          SaBankRegistry.universalBranchCodeFor('Standard Bank'),
          '051001',
        );
        expect(SaBankRegistry.universalBranchCodeFor('Nedbank'), '198765');
        expect(SaBankRegistry.universalBranchCodeFor('ABSA'), '632005');
        expect(SaBankRegistry.universalBranchCodeFor('Absa Bank'), '632005');
        expect(SaBankRegistry.universalBranchCodeFor('TymeBank'), '678910');

        expect(
          SaBankRegistry.supportsRail('Capitec', PayoutGatewayRail.capitecPay),
          isTrue,
        );
        expect(
          SaBankRegistry.supportsRail('FNB', PayoutGatewayRail.capitecPay),
          isFalse,
        );
        expect(
          SaBankRegistry.supportsRail('FNB', PayoutGatewayRail.ozow),
          isTrue,
        );
        expect(
          SaBankRegistry.supportsRail('TymeBank', PayoutGatewayRail.payFast),
          isTrue,
        );
        expect(
          SaBankRegistry.supportsRail('Nedbank', PayoutGatewayRail.eft),
          isTrue,
        );
      },
    );

    test(
      'HttpSocialRepository routes structured payouts to POST /api/wallet/payout & fetches banks',
      () async {
        final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000/api'));
        Map<String, dynamic>? sentPayload;
        String? requestedPath;

        dio.httpClientAdapter = _StubDioAdapter((options) async {
          requestedPath = options.path;
          if (options.method == 'GET' &&
              options.path.endsWith('/wallet/banks')) {
            return _jsonResponse(<String, dynamic>{
              'success': true,
              'banks': <Map<String, dynamic>>[
                <String, dynamic>{
                  'canonicalName': 'Capitec Bank',
                  'code': 'CAPITEC',
                  'universalBranchCode': '470010',
                  'supportsCapitecPay': true,
                },
              ],
            });
          }
          if (options.method == 'POST' &&
              options.path.endsWith('/wallet/payout')) {
            sentPayload = Map<String, dynamic>.from(options.data as Map);
            return _jsonResponse(<String, dynamic>{
              'success': true,
              'payoutId': 'payout_gateway_001',
              'remainingBalanceZar': 1170.0,
              'status': 'instant_cleared',
              'bankName': 'Capitec Bank',
              'branchCode': '470010',
              'maskedAccount': '****7465',
              'paymentRail': 'capitec_pay',
              'estimatedSettlement': 'Instant (< 60s)',
              'gatewayRef': 'VH-PAY-ABCD1234',
            });
          }
          return _jsonResponse(<String, dynamic>{
            'error': 'Bad request',
          }, statusCode: 400);
        });

        final repo = HttpSocialRepository(
          dio: dio,
          baseUrl: 'http://localhost:3000/api',
        );

        final banks = await repo.fetchSupportedBanks();
        expect(banks.single.canonicalName, 'Capitec Bank');
        expect(banks.single.supportsCapitecPay, isTrue);

        final receipt = await repo.requestPayout(
          creatorId: 'creator_makhadzi',
          amountZar: 250.0,
          accountDetails: 'Capitec - 1092837465',
          bankName: 'Capitec',
          accountHolder: 'Ndugelo Musician',
          accountNumber: '1092837465',
          paymentRail: PayoutGatewayRail.capitecPay,
        );

        expect(requestedPath, endsWith('/wallet/payout'));
        expect(sentPayload?['bankName'], 'Capitec Bank');
        expect(sentPayload?['branchCode'], '470010');
        expect(sentPayload?['paymentRail'], 'capitec_pay');
        expect(receipt.success, isTrue);
        expect(receipt.status, 'instant_cleared');
        expect(receipt.gatewayRef, 'VH-PAY-ABCD1234');
        expect(receipt.remainingBalanceZar, 1170.0);
      },
    );

    test(
      'CreatorWalletNotifier enforces rail/bank compatibility and stores gateway clearance receipt',
      () async {
        final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000/api'));
        dio.httpClientAdapter = _StubDioAdapter((options) async {
          if (options.path.endsWith('/wallet/payout')) {
            return _jsonResponse(<String, dynamic>{
              'success': true,
              'payoutId': 'payout_ozow_002',
              'remainingBalanceZar': 1120.0,
              'status': 'instant_cleared',
              'bankName': 'FNB',
              'branchCode': '250655',
              'maskedAccount': '****3746',
              'paymentRail': 'ozow',
              'estimatedSettlement': 'Instant (< 60s)',
              'gatewayRef': 'VH-PAY-OZOW99',
            });
          }
          return _jsonResponse(<String, dynamic>{});
        });

        final repo = HttpSocialRepository(
          dio: dio,
          baseUrl: 'http://localhost:3000/api',
        );
        final container = ProviderContainer(
          overrides: <Override>[
            socialRepositoryProvider.overrideWithValue(repo),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(creatorWalletProvider.notifier);

        // Invalid rail: Capitec Pay cannot be used for FNB
        final invalid = await notifier.requestBankingPayout(
          amountZar: 100.0,
          bankingDetails: const CreatorBankingDetails(
            bankName: 'FNB',
            accountHolder: 'Ndugelo',
            accountNumber: '62819283746',
            branchCode: '250655',
            paymentRail: PayoutGatewayRail.capitecPay,
          ),
        );
        expect(invalid, isFalse);
        expect(container.read(creatorWalletProvider).creatorEarnedZar, 1420.0);

        // Valid Ozow Instant EFT on FNB succeeds cleanly
        final valid = await notifier.requestBankingPayout(
          amountZar: 300.0,
          bankingDetails: const CreatorBankingDetails(
            bankName: 'FNB',
            accountHolder: 'Ndugelo',
            accountNumber: '62819283746',
            branchCode: '250655',
            paymentRail: PayoutGatewayRail.ozow,
          ),
        );
        expect(valid, isTrue);

        final updated = container.read(creatorWalletProvider);
        expect(updated.creatorEarnedZar, 1120.0);
        expect(updated.lastPayoutReceipt?.gatewayRef, 'VH-PAY-OZOW99');
        expect(updated.lastPayoutReceipt?.paymentRail, PayoutGatewayRail.ozow);
        expect(updated.payoutStatusMessage, contains('Ozow'));
      },
    );

    testWidgets(
      'PayoutDetailsSheet renders all 4 payment rails, auto-fills branch codes, and switches incompatible rails',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const Scaffold(body: PayoutDetailsSheet()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('payout_rail_capitec_pay')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('payout_rail_ozow')), findsOneWidget);
        expect(find.byKey(const Key('payout_rail_payfast')), findsOneWidget);
        expect(find.byKey(const Key('payout_rail_eft')), findsOneWidget);

        // Select Standard Bank -> branch code updates to 051001 automatically
        await tester.tap(find.byKey(const Key('payout_bank_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Standard Bank').last);
        await tester.pumpAndSettle();

        expect(find.text('051001'), findsOneWidget);

        // Select PayFast Instant rail and submit
        await tester.tap(find.byKey(const Key('payout_rail_payfast')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('payout_confirm_btn')));
        await tester.pumpAndSettle();

        final walletState = container.read(creatorWalletProvider);
        expect(walletState.creatorEarnedZar, 0.0);
        expect(walletState.payoutStatusMessage, contains('PayFast'));
      },
    );
  });
}
