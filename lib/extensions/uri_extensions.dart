import 'package:http/http.dart' as http;

extension UriExtensions on Uri {
  List<Uri> buildWebsiteCandidates() {
    final candidates = <Uri>{};
    final host = this.host;

    candidates.add(Uri(scheme: 'https', host: host, path: '/'));

    if (host.startsWith('www.')) {
      final noWww = host.substring(4);
      if (noWww.isNotEmpty && noWww.contains('.')) {
        candidates.add(Uri(scheme: 'https', host: noWww, path: '/'));
      }
    } else {
      candidates.add(Uri(scheme: 'https', host: 'www.$host', path: '/'));
    }

    return candidates.toList();
  }

  List<String> buildCommonImageAssetUrls() {
    final urls = <String>{
      Uri(scheme: 'https', host: host, path: '/favicon.ico').toString(),
      Uri(scheme: 'https', host: host, path: '/favicon.png').toString(),
      Uri(scheme: 'https', host: host, path: '/favicon-32x32.png').toString(),
      Uri(scheme: 'https', host: host, path: '/favicon-192x192.png').toString(),
      Uri(
        scheme: 'https',
        host: host,
        path: '/apple-touch-icon.png',
      ).toString(),
      Uri(
        scheme: 'https',
        host: host,
        path: '/apple-touch-icon-precomposed.png',
      ).toString(),
      Uri(
        scheme: 'https',
        host: host,
        path: '/android-chrome-192x192.png',
      ).toString(),
      Uri(scheme: 'https', host: host, path: '/logo.png').toString(),
      Uri(scheme: 'https', host: host, path: '/images/logo.png').toString(),
      Uri(scheme: 'https', host: host, path: '/images/logo.jpg').toString(),
      Uri(scheme: 'https', host: host, path: '/images/logo.webp').toString(),
      Uri(scheme: 'https', host: host, path: '/assets/logo.png').toString(),
      Uri(scheme: 'https', host: host, path: '/assets/img/logo.png').toString(),
      Uri(
        scheme: 'https',
        host: host,
        path: '/assets/images/logo.png',
      ).toString(),
      Uri(scheme: 'https', host: host, path: '/media/logo.png').toString(),
      Uri(scheme: 'https', host: host, path: '/themes/logo.png').toString(),
      'https://www.google.com/s2/favicons?sz=256&domain_url=https://$host',
    };
    return urls.toList();
  }

  Future<http.Response?> tryGet() async {
    try {
      return await http.get(this, headers: const {
        'User-Agent':
            'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
      }).timeout(const Duration(seconds: 6));
    } catch (_) {
      return null;
    }
  }
}
