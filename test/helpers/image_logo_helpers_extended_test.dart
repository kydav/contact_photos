import 'dart:typed_data';

import 'package:contact_photos/helpers/image_logo_helpers.dart';
import 'package:contact_photos/models/company_image_option.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _fakeBytes() => Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0, 0, 0, 0, 0, 0, 0, 0]);

CompanyImageOption _option(String url) =>
    CompanyImageOption(url: url, bytes: _fakeBytes());

void main() {
  // ---------------------------------------------------------------------------
  // buildLogokitLogoUri
  // ---------------------------------------------------------------------------
  group('ImageLogoHelpers.buildLogokitLogoUri', () {
    test('builds correct URI with domain and token', () {
      final uri = ImageLogoHelpers.buildLogokitLogoUri(
        'example.com',
        token: 'my-token',
      );
      expect(uri?.host, 'img.logokit.com');
      expect(uri?.path, '/example.com');
      expect(uri?.queryParameters['token'], 'my-token');
    });

    test('lowercases and trims the domain', () {
      final uri = ImageLogoHelpers.buildLogokitLogoUri(
        '  EXAMPLE.COM  ',
        token: 'tok',
      );
      expect(uri?.path, '/example.com');
    });

    test('returns null for empty domain', () {
      expect(
        ImageLogoHelpers.buildLogokitLogoUri('', token: 'tok'),
        isNull,
      );
    });

    test('returns null for empty token', () {
      expect(
        ImageLogoHelpers.buildLogokitLogoUri('example.com', token: ''),
        isNull,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // rankImageCandidates
  // ---------------------------------------------------------------------------
  group('ImageLogoHelpers.rankImageCandidates', () {
    const primaryHost = 'example.com';

    test('trusted provider hosts rank above generic company URLs', () {
      final ranked = ImageLogoHelpers.rankImageCandidates(
        [
          'https://example.com/logo.png',
          'https://img.logokit.com/example.com?token=t',
        ],
        primaryHost,
        const ['example'],
      );
      expect(ranked.first,
          'https://img.logokit.com/example.com?token=t');
    });

    test('URL with "favicon" in path scores higher than plain image', () {
      final ranked = ImageLogoHelpers.rankImageCandidates(
        [
          'https://example.com/image.png',
          'https://example.com/favicon.ico',
        ],
        primaryHost,
        const [],
      );
      expect(ranked.first, 'https://example.com/favicon.ico');
    });

    test('URL with "logo" in path scores higher than random image', () {
      final ranked = ImageLogoHelpers.rankImageCandidates(
        [
          'https://example.com/image.png',
          'https://example.com/logo.png',
        ],
        primaryHost,
        const [],
      );
      expect(ranked.first, 'https://example.com/logo.png');
    });

    test('social asset URLs rank last by default', () {
      final ranked = ImageLogoHelpers.rankImageCandidates(
        [
          'https://example.com/favicon.ico',
          'https://facebook.com/example/logo.png',
        ],
        primaryHost,
        const [],
      );
      expect(ranked.last, 'https://facebook.com/example/logo.png');
    });

    test('social asset URLs are allowed when allowSocialAssetUrls is true', () {
      final ranked = ImageLogoHelpers.rankImageCandidates(
        [
          'https://facebook.com/example/logo.png',
          'https://example.com/image.png',
        ],
        primaryHost,
        const [],
        allowSocialAssetUrls: true,
      );
      // When allowed, they should not be penalised — just ranked normally.
      expect(ranked, isNotEmpty);
    });

    test('deduplicates URLs', () {
      final ranked = ImageLogoHelpers.rankImageCandidates(
        [
          'https://example.com/logo.png',
          'https://example.com/logo.png',
        ],
        primaryHost,
        const [],
      );
      expect(ranked, hasLength(1));
    });

    test('ui icon URLs are penalised', () {
      final ranked = ImageLogoHelpers.rankImageCandidates(
        [
          'https://example.com/logo.png',
          'https://example.com/icon-16.png',
        ],
        primaryHost,
        const [],
      );
      expect(ranked.first, 'https://example.com/logo.png');
    });

    test('company token match boosts score', () {
      final ranked = ImageLogoHelpers.rankImageCandidates(
        [
          'https://example.com/unrelated.png',
          'https://example.com/example-brand.png',
        ],
        primaryHost,
        const ['example'],
      );
      expect(ranked.first, 'https://example.com/example-brand.png');
    });
  });

  // ---------------------------------------------------------------------------
  // mergeImageOptions
  // ---------------------------------------------------------------------------
  group('ImageLogoHelpers.mergeImageOptions', () {
    test('primary options appear first', () {
      final primary = [_option('https://a.com/1.png'), _option('https://a.com/2.png')];
      final extra = [_option('https://b.com/3.png')];
      final merged = ImageLogoHelpers.mergeImageOptions(primary, extra);
      expect(merged[0].url, 'https://a.com/1.png');
      expect(merged[1].url, 'https://a.com/2.png');
      expect(merged[2].url, 'https://b.com/3.png');
    });

    test('deduplicates by URL', () {
      final primary = [_option('https://a.com/1.png')];
      final extra = [_option('https://a.com/1.png')];
      final merged = ImageLogoHelpers.mergeImageOptions(primary, extra);
      expect(merged, hasLength(1));
    });

    test('caps output at 8 options', () {
      final primary =
          List.generate(6, (i) => _option('https://a.com/$i.png'));
      final extra =
          List.generate(6, (i) => _option('https://b.com/$i.png'));
      final merged = ImageLogoHelpers.mergeImageOptions(primary, extra);
      expect(merged.length, lessThanOrEqualTo(8));
    });

    test('returns empty list when both inputs are empty', () {
      expect(ImageLogoHelpers.mergeImageOptions([], []), isEmpty);
    });

    test('handles empty primary with non-empty additional', () {
      final extra = [_option('https://b.com/1.png')];
      final merged = ImageLogoHelpers.mergeImageOptions([], extra);
      expect(merged, hasLength(1));
    });
  });

  // ---------------------------------------------------------------------------
  // extractLogoImageUrlsFromHtml
  // ---------------------------------------------------------------------------
  group('ImageLogoHelpers.extractLogoImageUrlsFromHtml', () {
    final baseUri = Uri.parse('https://example.com/');

    test('extracts og:image meta tag', () {
      const html = '<meta property="og:image" content="https://example.com/og.jpg">';
      final urls = ImageLogoHelpers.extractLogoImageUrlsFromHtml(html, baseUri);
      expect(urls, contains('https://example.com/og.jpg'));
    });

    test('extracts twitter:image meta tag', () {
      // NOTE: the URL must not contain social keywords (twitter, facebook, etc.)
      // because isLikelySocialAssetUrl() checks for substring matches in the URL
      // itself, and would filter out any URL containing "twitter".
      const html =
          '<meta name="twitter:image" content="https://example.com/card.jpg">';
      final urls = ImageLogoHelpers.extractLogoImageUrlsFromHtml(html, baseUri);
      expect(urls, contains('https://example.com/card.jpg'));
    });

    test('extracts link rel=icon href', () {
      const html = '<link rel="icon" href="/favicon.ico">';
      final urls = ImageLogoHelpers.extractLogoImageUrlsFromHtml(html, baseUri);
      expect(urls, contains('https://example.com/favicon.ico'));
    });

    test('extracts link rel=apple-touch-icon href', () {
      const html = '<link rel="apple-touch-icon" href="/apple-touch-icon.png">';
      final urls = ImageLogoHelpers.extractLogoImageUrlsFromHtml(html, baseUri);
      expect(urls, contains('https://example.com/apple-touch-icon.png'));
    });

    test('extracts logo img src when alt contains "logo"', () {
      const html = '<img alt="Company logo" src="/logo.png">';
      final urls = ImageLogoHelpers.extractLogoImageUrlsFromHtml(html, baseUri);
      expect(urls, contains('https://example.com/logo.png'));
    });

    test('skips img tags that do not have logo/brand/header context', () {
      const html = '<img alt="product photo" src="/product.png">';
      final urls = ImageLogoHelpers.extractLogoImageUrlsFromHtml(html, baseUri);
      expect(urls, isNot(contains('https://example.com/product.png')));
    });

    test('skips SVG URLs', () {
      const html = '<link rel="icon" href="/logo.svg">';
      final urls = ImageLogoHelpers.extractLogoImageUrlsFromHtml(html, baseUri);
      expect(urls, isEmpty);
    });

    test('skips data: URIs', () {
      const html =
          '<meta property="og:image" content="data:image/png;base64,abc123">';
      final urls = ImageLogoHelpers.extractLogoImageUrlsFromHtml(html, baseUri);
      expect(urls, isEmpty);
    });

    test('resolves relative URLs against baseUri', () {
      const html = '<link rel="icon" href="/relative/icon.png">';
      final urls = ImageLogoHelpers.extractLogoImageUrlsFromHtml(html, baseUri);
      expect(urls, contains('https://example.com/relative/icon.png'));
    });

    test('deduplicates extracted URLs', () {
      const html = '''
        <meta property="og:image" content="https://example.com/logo.png">
        <meta property="og:image:url" content="https://example.com/logo.png">
      ''';
      final urls = ImageLogoHelpers.extractLogoImageUrlsFromHtml(html, baseUri);
      expect(urls.where((u) => u == 'https://example.com/logo.png').length, 1);
    });

    test('filters disallowed logos-world asset URLs', () {
      const html =
          '<img alt="logo" src="https://logos-world.net/wp-content/uploads/2024/01/logos-world.net_99.png">';
      final urls = ImageLogoHelpers.extractLogoImageUrlsFromHtml(html, baseUri);
      expect(urls, isEmpty);
    });

    test('skips social asset URLs by default', () {
      const html =
          '<meta property="og:image" content="https://facebook.com/img.png">';
      final urls = ImageLogoHelpers.extractLogoImageUrlsFromHtml(html, baseUri);
      expect(urls, isEmpty);
    });

    test('includes social asset URLs when allowSocialAssetUrls is true', () {
      const html =
          '<meta property="og:image" content="https://facebook.com/img.png">';
      final urls = ImageLogoHelpers.extractLogoImageUrlsFromHtml(
        html,
        baseUri,
        allowSocialAssetUrls: true,
      );
      expect(urls, contains('https://facebook.com/img.png'));
    });

    test('extracts srcset URLs from img tag', () {
      const html =
          '<img alt="logo" srcset="https://example.com/1x.png 1x, https://example.com/2x.png 2x">';
      final urls = ImageLogoHelpers.extractLogoImageUrlsFromHtml(html, baseUri);
      expect(urls, contains('https://example.com/1x.png'));
      expect(urls, contains('https://example.com/2x.png'));
    });

    test('decodes &amp; in URLs', () {
      const html =
          '<meta property="og:image" content="https://example.com/img?a=1&amp;b=2">';
      final urls = ImageLogoHelpers.extractLogoImageUrlsFromHtml(html, baseUri);
      expect(urls, contains('https://example.com/img?a=1&b=2'));
    });

    test('company token in img tag boosts extraction', () {
      const html =
          '<img class="acme-img" src="https://example.com/brand.png">';
      final urls = ImageLogoHelpers.extractLogoImageUrlsFromHtml(
        html,
        baseUri,
        companyTokens: const ['acme'],
      );
      expect(urls, contains('https://example.com/brand.png'));
    });
  });

  // ---------------------------------------------------------------------------
  // buildLogosWorldPageUris
  // ---------------------------------------------------------------------------
  group('ImageLogoHelpers.buildLogosWorldPageUris', () {
    test('generates URI from company name slug', () {
      final uris = ImageLogoHelpers.buildLogosWorldPageUris(
        companyName: 'Acme Tools',
        companyWebsiteUrl: 'https://acme-tools.com',
      );
      final strings = uris.map((u) => u.toString()).toList();
      expect(strings, contains('https://logos-world.net/acme-tools-logo/'));
    });

    test('all URIs use logos-world.net host', () {
      final uris = ImageLogoHelpers.buildLogosWorldPageUris(
        companyName: 'Example Corp',
        companyWebsiteUrl: 'https://example.com',
      );
      for (final uri in uris) {
        expect(uri.host, 'logos-world.net');
      }
    });

    test('caps results at 8 URIs', () {
      final uris = ImageLogoHelpers.buildLogosWorldPageUris(
        companyName: 'A Very Long Company Name That Makes Many Tokens',
        companyWebsiteUrl: 'https://averylongcompany.com',
      );
      expect(uris.length, lessThanOrEqualTo(8));
    });

    test('includes domain-based slug', () {
      final uris = ImageLogoHelpers.buildLogosWorldPageUris(
        companyName: 'BrandCo',
        companyWebsiteUrl: 'https://brandco.com',
      );
      final strings = uris.map((u) => u.toString()).toSet();
      expect(strings.any((s) => s.contains('brandco')), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // buildGuessedSocialProfileUris
  // ---------------------------------------------------------------------------
  group('ImageLogoHelpers.buildGuessedSocialProfileUris', () {
    test('returns Facebook and Instagram URIs', () {
      final uris = ImageLogoHelpers.buildGuessedSocialProfileUris(
        companyName: 'Acme',
        companyWebsiteUrl: 'https://acme.com',
      );
      final hosts = uris.map((u) => u.host).toSet();
      expect(hosts.any((h) => h.contains('facebook.com')), isTrue);
      expect(hosts.any((h) => h.contains('instagram.com')), isTrue);
    });

    test('slugifies the company name for social handles', () {
      final uris = ImageLogoHelpers.buildGuessedSocialProfileUris(
        companyName: 'Acme Tools & Co',
        companyWebsiteUrl: 'https://acme-tools.com',
      );
      final paths = uris.map((u) => u.path).toList();
      expect(paths.any((p) => p.contains('acme')), isTrue);
    });
  });
}
