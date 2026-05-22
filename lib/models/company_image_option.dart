import 'dart:typed_data';

class CompanyImageOption {
  const CompanyImageOption({
    required this.url,
    required this.bytes,
  });

  final String url;
  final Uint8List bytes;

  bool get isFromLogoKit {
    final host = Uri.tryParse(url)?.host.toLowerCase();
    return host == 'img.logokit.com' ||
        host == 'logokit.com' ||
        host == 'www.logokit.com';
  }
}
