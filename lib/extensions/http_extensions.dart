import 'package:contact_photos/extensions/byte_extensions.dart';
import 'package:http/http.dart';

extension HttpExtensions on Response {
  bool looksLikeImage() {
    final contentType = headers['content-type']?.toLowerCase() ?? '';
    if (contentType.contains('svg')) {
      return false;
    }
    return contentType.startsWith('image/') || bodyBytes.looksLikeImageBytes();
  }

  bool looksLikeHtml() {
    final contentType = headers['content-type']?.toLowerCase() ?? '';
    if (contentType.contains('text/html')) {
      return true;
    }
    final trimmedBody = body.trimLeft();
    return trimmedBody.startsWith('<!doctype html') ||
        trimmedBody.startsWith('<html');
  }
}
