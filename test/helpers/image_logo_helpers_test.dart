import 'package:contact_photos/helpers/image_logo_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ImageLogoHelpers.buildLogosWorldPageUris', () {
    test('includes compact and hyphenated slug variants', () {
      final uris = ImageLogoHelpers.buildLogosWorldPageUris(
        companyName: 'Crumblcookies',
        companyWebsiteUrl: 'https://crumblcookies.com/',
      );

      final uriStrings = uris.map((uri) => uri.toString()).toList();

      expect(
        uriStrings,
        contains('https://logos-world.net/crumblcookies-logo/'),
      );
      expect(
        uriStrings,
        contains('https://logos-world.net/crumbl-cookies-logo/'),
      );
    });
  });
}
