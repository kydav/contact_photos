import 'dart:typed_data';

class CompanyImageOption {
  const CompanyImageOption({
    required this.url,
    required this.bytes,
  });

  final String url;
  final Uint8List bytes;
}
