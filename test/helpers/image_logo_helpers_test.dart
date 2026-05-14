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

    test('filters numbered logos-world asset files from extracted results', () {
      final urls = ImageLogoHelpers.extractLogoImageUrlsFromHtml(
        '''
        <html>
          <body>
            <img alt="logo" src="https://logos-world.net/wp-content/uploads/2024/01/logos-world.net_3.png" />
            <img alt="logo" src="https://logos-world.net/wp-content/uploads/2024/01/crumblcookies-logo.png" />
          </body>
        </html>
        ''',
        Uri.parse('https://logos-world.net/crumblcookies-logo/'),
      );

      expect(
        urls,
        isNot(contains(
          'https://logos-world.net/wp-content/uploads/2024/01/logos-world.net_3.png',
        )),
      );
      expect(
        urls,
        contains(
          'https://logos-world.net/wp-content/uploads/2024/01/crumblcookies-logo.png',
        ),
      );
    });
  });
}
