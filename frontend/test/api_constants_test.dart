import 'package:flutter_test/flutter_test.dart';
import 'package:professor_os/core/network/api_constants.dart';

void main() {
  test('uses an explicit API base URL when configured', () {
    expect(
      ApiConstants.resolveBaseUrl(
        configured: 'https://api.example.com/api/v1',
        isWeb: true,
        webOrigin: 'https://app.example.com',
      ),
      'https://api.example.com/api/v1',
    );
  });

  test('uses the current browser origin for web deployments by default', () {
    expect(
      ApiConstants.resolveBaseUrl(
        configured: '',
        isWeb: true,
        webOrigin: 'https://professor-os-production-65b2.up.railway.app',
      ),
      'https://professor-os-production-65b2.up.railway.app/api/v1',
    );
  });

  test('keeps localhost as the native development fallback', () {
    expect(
      ApiConstants.resolveBaseUrl(
        configured: '',
        isWeb: false,
      ),
      'http://localhost:8000/api/v1',
    );
  });
}
