import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masilpet/src/data/masilpet_backend.dart';

void main() {
  test('Cloudflare backend sends Firebase token and callable payload',
      () async {
    final client = MockClient((request) async {
      expect(
        request.url.toString(),
        'https://masilpet-api.example/v1/applyStepProgress',
      );
      expect(request.method, 'POST');
      expect(request.headers['authorization'], 'Bearer firebase-token');
      expect(request.headers['content-type'], 'application/json');
      expect(
        jsonDecode(request.body),
        {
          'data': {'stepDelta': 1234},
        },
      );
      return http.Response(
        jsonEncode({
          'data': {
            'hatchableCount': 2,
            'appliedStepDelta': 1234,
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final backend = CloudflareMasilPetBackend(
      baseUrl: 'https://masilpet-api.example/',
      client: client,
      tokenProvider: () async => 'firebase-token',
    );

    final result = await backend.applyStepProgress(1234);

    expect(result.hatchableCount, 2);
    expect(result.appliedStepDelta, 1234);
  });

  test('Cloudflare backend maps API errors', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'error': {
            'code': 'failed-precondition',
            'message': 'Daily step progress limit reached.',
            'details': {'remaining': 0},
          },
        }),
        412,
        headers: {'content-type': 'application/json'},
      );
    });
    final backend = CloudflareMasilPetBackend(
      baseUrl: 'https://masilpet-api.example',
      client: client,
      tokenProvider: () async => 'firebase-token',
    );

    await expectLater(
      backend.applyStepProgress(100),
      throwsA(
        isA<MasilPetBackendException>()
            .having((error) => error.code, 'code', 'failed-precondition')
            .having(
              (error) => error.message,
              'message',
              'Daily step progress limit reached.',
            ),
      ),
    );
  });

  test('Cloudflare backend requires a Firebase ID token', () async {
    var requestCount = 0;
    final client = MockClient((request) async {
      requestCount += 1;
      return http.Response('{}', 200);
    });
    final backend = CloudflareMasilPetBackend(
      baseUrl: 'https://masilpet-api.example',
      client: client,
      tokenProvider: () async => null,
    );

    await expectLater(
      backend.ensureUserBootstrap(),
      throwsA(
        isA<MasilPetBackendException>()
            .having((error) => error.code, 'code', 'unauthenticated'),
      ),
    );
    expect(requestCount, 0);
  });
}
