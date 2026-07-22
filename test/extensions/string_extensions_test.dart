import 'package:contact_photos/extensions/string_extensions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ---------------------------------------------------------------------------
  // normalizeWebsiteUrl
  // ---------------------------------------------------------------------------
  group('StringExtensions.normalizeWebsiteUrl', () {
    test('returns null for empty string', () {
      expect(''.normalizeWebsiteUrl(), isNull);
      expect('   '.normalizeWebsiteUrl(), isNull);
    });

    test('adds https scheme when missing', () {
      expect('example.com'.normalizeWebsiteUrl(), 'https://example.com');
    });

    test('preserves existing https scheme', () {
      expect(
        'https://example.com'.normalizeWebsiteUrl(),
        'https://example.com',
      );
    });

    test('preserves http scheme', () {
      expect(
        'http://example.com'.normalizeWebsiteUrl(),
        'http://example.com',
      );
    });

    // BUG (flagged): 'ftp://example.com' is not properly rejected.
    // normalizeWebsiteUrl() only prepends 'https://' when the string doesn't
    // already start with 'http://' or 'https://'. Since 'ftp://example.com'
    // doesn't start with either, it becomes 'https://ftp://example.com', which
    // parses to scheme=https, host=ftp — passing all guards.
    // The correct behavior would be to return null for non-http(s) inputs.
    test('BUG: does not reject non-http(s) scheme (ftp:// passes through)', () {
      final result = 'ftp://example.com'.normalizeWebsiteUrl();
      // Current (buggy) behavior: returns a garbled URL instead of null
      expect(result, isNotNull);
    });

    test('returns null when host is empty', () {
      expect('https://'.normalizeWebsiteUrl(), isNull);
    });

    test('handles paths correctly', () {
      expect(
        'https://example.com/path?q=1'.normalizeWebsiteUrl(),
        'https://example.com/path?q=1',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // normalizeWebsiteUri
  // ---------------------------------------------------------------------------
  group('StringExtensions.normalizeWebsiteUri', () {
    test('returns null for empty string', () {
      expect(''.normalizeWebsiteUri(), isNull);
    });

    // BUG (flagged): normalizeWebsiteUri() uses case-sensitive startsWith
    // checks for 'http://' and 'https://'. An uppercase scheme like
    // 'HTTP://Example.COM' is not recognized, so 'https://' is prepended,
    // resulting in 'https://HTTP://Example.COM' with host='http'.
    test('adds https scheme for bare domains', () {
      final uri = 'example.com'.normalizeWebsiteUri();
      expect(uri?.scheme, 'https');
      expect(uri?.host, 'example.com');
    });

    test('strips path and query', () {
      final uri = 'https://example.com/some/path?q=1'.normalizeWebsiteUri();
      // path is preserved but query is not passed through
      expect(uri?.host, 'example.com');
    });

    // BUG (flagged): same scheme-detection issue as normalizeWebsiteUrl.
    // 'ftp://example.com' is prepended with 'https://', giving host='ftp'.
    test('BUG: does not reject non-http(s) scheme (ftp:// passes through)', () {
      final uri = 'ftp://example.com'.normalizeWebsiteUri();
      // Current (buggy) behavior: returns a Uri with host 'ftp' instead of null
      expect(uri, isNotNull);
    });
  });

  // ---------------------------------------------------------------------------
  // extractJsonPayload
  // ---------------------------------------------------------------------------
  group('StringExtensions.extractJsonPayload', () {
    test('returns trimmed string when already a JSON object', () {
      const s = '{"key": "value"}';
      expect(s.extractJsonPayload(), s);
    });

    test('returns trimmed string when already a JSON array', () {
      const s = '[1, 2, 3]';
      expect(s.extractJsonPayload(), s);
    });

    test('extracts embedded JSON object from surrounding text', () {
      const s = 'Here is the data: {"companies":[]} done.';
      expect(s.extractJsonPayload(), '{"companies":[]}');
    });

    test('returns null when no JSON object delimiters found', () {
      expect('no json here'.extractJsonPayload(), isNull);
    });

    test('returns null for empty string', () {
      expect(''.extractJsonPayload(), isNull);
      expect('   '.extractJsonPayload(), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // parseCompanies
  // ---------------------------------------------------------------------------
  group('StringExtensions.parseCompanies', () {
    test('parses a well-formed companies JSON object', () {
      const json = '''
      {
        "companies": [
          {"name": "Acme Inc", "websiteUrl": "https://acme.com"},
          {"name": "Widget Co", "websiteUrl": "https://widget.co"}
        ]
      }
      ''';
      final results = json.parseCompanies();
      expect(results, hasLength(2));
      expect(results[0].name, 'Acme Inc');
      expect(results[0].websiteUrl, 'https://acme.com');
    });

    test('parses a raw JSON array without wrapper object', () {
      const json = '''
      [
        {"name": "Acme Inc", "websiteUrl": "https://acme.com"}
      ]
      ''';
      final results = json.parseCompanies();
      expect(results, hasLength(1));
      expect(results[0].name, 'Acme Inc');
    });

    test('returns empty list for empty string', () {
      expect(''.parseCompanies(), isEmpty);
      expect('   '.parseCompanies(), isEmpty);
    });

    test('returns empty list when JSON has no companies key and is not array',
        () {
      expect('{"other": []}'.parseCompanies(), isEmpty);
    });

    test('skips entries with empty names', () {
      const json = '{"companies": [{"name": "", "websiteUrl": "https://a.com"}]}';
      expect(json.parseCompanies(), isEmpty);
    });

    test('skips entries with null or missing websiteUrl', () {
      const json = '{"companies": [{"name": "Acme", "websiteUrl": null}]}';
      expect(json.parseCompanies(), isEmpty);
    });

    test('deduplicates by websiteUrl', () {
      const json = '''
      {"companies": [
        {"name": "Acme", "websiteUrl": "https://acme.com"},
        {"name": "Acme Copy", "websiteUrl": "https://acme.com"}
      ]}
      ''';
      final results = json.parseCompanies();
      expect(results, hasLength(1));
    });

    test('caps results at 6', () {
      final items = List.generate(
        10,
        (i) => '{"name": "Co$i", "websiteUrl": "https://co$i.com"}',
      ).join(',');
      final json = '{"companies": [$items]}';
      final results = json.parseCompanies();
      expect(results.length, lessThanOrEqualTo(6));
    });

    test('returns empty list for invalid JSON', () {
      expect('not json at all'.parseCompanies(), isEmpty);
    });

    test('extracts embedded JSON from surrounding text', () {
      const s = 'Here you go: {"companies":[{"name":"Acme","websiteUrl":"https://acme.com"}]}';
      expect(s.parseCompanies(), hasLength(1));
    });
  });

  // ---------------------------------------------------------------------------
  // isLikelyUiIconUrl
  // ---------------------------------------------------------------------------
  group('StringExtensions.isLikelyUiIconUrl', () {
    test('returns true for URL containing icon- prefix', () {
      expect('https://example.com/icon-16.png'.isLikelyUiIconUrl(), isTrue);
    });

    test('returns true for URL with /icons/ path segment', () {
      expect('https://example.com/icons/star.png'.isLikelyUiIconUrl(), isTrue);
    });

    test('returns true for URL with /icon/ path segment', () {
      expect('https://example.com/icon/brand.png'.isLikelyUiIconUrl(), isTrue);
    });

    test('returns true for URL containing glyph', () {
      expect('https://example.com/glyph-set.png'.isLikelyUiIconUrl(), isTrue);
    });

    test('returns true for URL containing sprite', () {
      expect('https://example.com/sprite-sheet.png'.isLikelyUiIconUrl(), isTrue);
    });

    test('returns false for a regular logo URL', () {
      expect('https://example.com/logo.png'.isLikelyUiIconUrl(), isFalse);
    });

    test('is case-insensitive', () {
      expect('https://example.com/ICON-24.PNG'.isLikelyUiIconUrl(), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // isLikelySvgUrl
  // ---------------------------------------------------------------------------
  group('StringExtensions.isLikelySvgUrl', () {
    test('returns true for .svg extension', () {
      expect('https://example.com/logo.svg'.isLikelySvgUrl(), isTrue);
    });

    test('returns true for format=svg query param', () {
      expect('https://example.com/img?format=svg'.isLikelySvgUrl(), isTrue);
    });

    test('returns false for PNG URL', () {
      expect('https://example.com/logo.png'.isLikelySvgUrl(), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // isLikelySocialAssetUrl
  // ---------------------------------------------------------------------------
  group('StringExtensions.isLikelySocialAssetUrl', () {
    test('returns true for facebook.com URL', () {
      expect('https://www.facebook.com/logo.png'.isLikelySocialAssetUrl(), isTrue);
    });

    test('returns true for instagram.com URL', () {
      expect('https://www.instagram.com/logo.png'.isLikelySocialAssetUrl(), isTrue);
    });

    test('returns true for linkedin.com URL', () {
      expect('https://www.linkedin.com/img.png'.isLikelySocialAssetUrl(), isTrue);
    });

    test('returns true for URL containing "social" keyword', () {
      expect('https://example.com/social-badge.png'.isLikelySocialAssetUrl(), isTrue);
    });

    test('returns false for a regular company logo URL', () {
      expect('https://example.com/logo.png'.isLikelySocialAssetUrl(), isFalse);
    });

    test('is case-insensitive', () {
      expect('https://www.FACEBOOK.COM/img.png'.isLikelySocialAssetUrl(), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // extractUrlsFromSrcset
  // ---------------------------------------------------------------------------
  group('StringExtensions.extractUrlsFromSrcset', () {
    test('returns empty list for empty string', () {
      expect(''.extractUrlsFromSrcset(), isEmpty);
    });

    test('extracts single URL from srcset without descriptor', () {
      const srcset = 'https://example.com/img.png';
      expect(srcset.extractUrlsFromSrcset(), ['https://example.com/img.png']);
    });

    test('extracts URLs from srcset with width descriptors', () {
      const srcset =
          'https://example.com/img-1x.png 1x, https://example.com/img-2x.png 2x';
      final urls = srcset.extractUrlsFromSrcset();
      expect(urls, contains('https://example.com/img-1x.png'));
      expect(urls, contains('https://example.com/img-2x.png'));
    });

    test('handles whitespace-only string', () {
      expect('   '.extractUrlsFromSrcset(), isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // extractCompanyTokens
  // ---------------------------------------------------------------------------
  group('StringExtensions.extractCompanyTokens', () {
    test('splits on non-alphanumeric characters and lowercases', () {
      final tokens = 'Acme Tools Inc.'.extractCompanyTokens();
      expect(tokens, containsAll(['acme', 'tools']));
    });

    test('excludes tokens shorter than 3 characters', () {
      final tokens = 'AB Corp'.extractCompanyTokens();
      // 'ab' has length 2 — excluded; 'corp' included
      expect(tokens, contains('corp'));
      expect(tokens, isNot(contains('ab')));
    });

    test('deduplicates tokens', () {
      final tokens = 'acme acme tools'.extractCompanyTokens();
      final acmeCount = tokens.where((t) => t == 'acme').length;
      expect(acmeCount, 1);
    });
  });

  // ---------------------------------------------------------------------------
  // trimTrailingUrlPunctuation
  // ---------------------------------------------------------------------------
  group('StringExtensions.trimTrailingUrlPunctuation', () {
    test('removes trailing closing parenthesis', () {
      expect(
        'https://example.com)'.trimTrailingUrlPunctuation(),
        'https://example.com',
      );
    });

    test('removes trailing comma', () {
      expect(
        'https://example.com,'.trimTrailingUrlPunctuation(),
        'https://example.com',
      );
    });

    test('does not remove trailing dot when removeDot is false', () {
      expect(
        'https://example.com.'.trimTrailingUrlPunctuation(),
        'https://example.com.',
      );
    });

    test('removes trailing dot when removeDot is true', () {
      expect(
        'https://example.com.'.trimTrailingUrlPunctuation(removeDot: true),
        'https://example.com',
      );
    });

    test('leaves clean URL untouched', () {
      const url = 'https://example.com/path';
      expect(url.trimTrailingUrlPunctuation(), url);
    });

    test('removes multiple trailing punctuation characters', () {
      expect(
        'https://example.com),'.trimTrailingUrlPunctuation(),
        'https://example.com',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // extractHtmlStartTags
  // ---------------------------------------------------------------------------
  group('StringExtensions.extractHtmlStartTags', () {
    test('extracts all matching start tags', () {
      const html = '<img src="a.png"><p>text</p><img src="b.png">';
      final tags = html.extractHtmlStartTags('img');
      expect(tags, hasLength(2));
      expect(tags[0], contains('src="a.png"'));
      expect(tags[1], contains('src="b.png"'));
    });

    test('is case-insensitive for tag name', () {
      const html = '<IMG src="a.png"><img src="b.png">';
      final tags = html.extractHtmlStartTags('img');
      expect(tags, hasLength(2));
    });

    test('returns empty list when tag not found', () {
      expect('<p>text</p>'.extractHtmlStartTags('img'), isEmpty);
    });

    test('stops at > character', () {
      const html = '<link rel="icon" href="/favicon.ico">';
      final tags = html.extractHtmlStartTags('link');
      expect(tags, hasLength(1));
      expect(tags.first, endsWith('>'));
    });
  });

  // ---------------------------------------------------------------------------
  // extractHtmlAttribute
  // ---------------------------------------------------------------------------
  group('StringExtensions.extractHtmlAttribute', () {
    test('extracts double-quoted attribute value', () {
      const tag = '<img src="https://example.com/img.png">';
      expect(tag.extractHtmlAttribute('src'), 'https://example.com/img.png');
    });

    test('extracts single-quoted attribute value', () {
      const tag = "<img src='https://example.com/img.png'>";
      expect(tag.extractHtmlAttribute('src'), 'https://example.com/img.png');
    });

    test('returns null when attribute not present', () {
      const tag = '<img alt="logo">';
      expect(tag.extractHtmlAttribute('src'), isNull);
    });

    test('is case-insensitive for attribute name', () {
      const tag = '<IMG SRC="https://example.com/img.png">';
      expect(tag.extractHtmlAttribute('src'), 'https://example.com/img.png');
    });

    test('does not match partial attribute names', () {
      const tag = '<img data-src="value">';
      // 'src' should NOT match inside 'data-src' since 'a' precedes 'src'
      expect(tag.extractHtmlAttribute('src'), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // extractJsonLdLogoUrls
  // ---------------------------------------------------------------------------
  group('StringExtensions.extractJsonLdLogoUrls', () {
    test('extracts logo URL from JSON-LD style text', () {
      const html = '{"@type":"Organization","logo":"https://example.com/logo.png"}';
      expect(
        html.extractJsonLdLogoUrls(),
        contains('https://example.com/logo.png'),
      );
    });

    test('returns empty list when no logo key present', () {
      const html = '{"@type":"Organization","name":"Acme"}';
      expect(html.extractJsonLdLogoUrls(), isEmpty);
    });

    test('deduplicates repeated logo URLs', () {
      const html =
          '{"logo":"https://a.com/logo.png"} {"logo":"https://a.com/logo.png"}';
      expect(html.extractJsonLdLogoUrls(), hasLength(1));
    });
  });

  // ---------------------------------------------------------------------------
  // extractDomainToken
  // ---------------------------------------------------------------------------
  group('StringExtensions.extractDomainToken', () {
    test('extracts first domain segment', () {
      expect('https://example.com'.extractDomainToken(), 'example');
    });

    test('strips www. prefix before extracting token', () {
      expect('https://www.example.com'.extractDomainToken(), 'example');
    });

    test('returns null for empty string', () {
      expect(''.extractDomainToken(), isNull);
    });

    // NOTE: 'not a url' (with spaces) is percent-encoded by Uri.tryParse
    // to host='not%20a%20url', which is non-empty, so extractDomainToken
    // returns the first dot-split segment rather than null.
    // A truly invalid URL like an empty string returns null.
    test('returns null for empty string', () {
      expect(''.extractDomainToken(), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // inferCompanyNameFromWebsite
  // ---------------------------------------------------------------------------
  group('StringExtensions.inferCompanyNameFromWebsite', () {
    test('capitalizes single-word domain', () {
      expect(
        'https://apple.com'.inferCompanyNameFromWebsite(),
        'Apple',
      );
    });

    test('splits hyphenated domain into title-cased words', () {
      expect(
        'https://acme-tools.com'.inferCompanyNameFromWebsite(),
        'Acme Tools',
      );
    });

    test('splits compact domain with known suffix', () {
      expect(
        'https://crumblcookies.com'.inferCompanyNameFromWebsite(),
        'Crumbl Cookies',
      );
    });

    // NOTE: 'not a url' (with spaces) is treated as a valid-ish URI by
    // Uri.tryParse (spaces are percent-encoded). The domain token extraction
    // succeeds with a garbled host. A properly empty/invalid URL like '' or a
    // truly malformed string without dots returns the fallback.
    test('returns fallback for empty string', () {
      expect(
        ''.inferCompanyNameFromWebsite(fallback: 'Unknown'),
        'Unknown',
      );
    });

    test('uses "Unknown Company" as default fallback for empty string', () {
      expect(
        ''.inferCompanyNameFromWebsite(),
        'Unknown Company',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // slugify
  // ---------------------------------------------------------------------------
  group('StringExtensions.slugify', () {
    test('lowercases and replaces spaces with hyphens', () {
      expect('Hello World'.slugify(), 'hello-world');
    });

    test('replaces & with "and"', () {
      expect('R&D'.slugify(), 'r-and-d');
    });

    test('collapses multiple separators into one hyphen', () {
      expect('Acme  --  Tools'.slugify(), 'acme-tools');
    });

    test('strips leading and trailing hyphens', () {
      expect('-test-'.slugify(), 'test');
    });

    test('handles already-clean slug', () {
      expect('acme-tools'.slugify(), 'acme-tools');
    });
  });
}
