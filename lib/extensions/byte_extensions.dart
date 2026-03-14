import 'dart:typed_data';

extension Uint8ListExtensions on Uint8List {
  bool looksLikeImageBytes() {
    if (length < 12) return false;

    final isPng = this[0] == 0x89 &&
        this[1] == 0x50 &&
        this[2] == 0x4E &&
        this[3] == 0x47;
    final isJpeg = this[0] == 0xFF && this[1] == 0xD8;
    final isGif = this[0] == 0x47 &&
        this[1] == 0x49 &&
        this[2] == 0x46 &&
        this[3] == 0x38;
    final isWebp = this[0] == 0x52 &&
        this[1] == 0x49 &&
        this[2] == 0x46 &&
        this[3] == 0x46 &&
        this[8] == 0x57 &&
        this[9] == 0x45 &&
        this[10] == 0x42 &&
        this[11] == 0x50;
    final isIco = this[0] == 0x00 &&
        this[1] == 0x00 &&
        this[2] == 0x01 &&
        this[3] == 0x00;

    return isPng || isJpeg || isGif || isWebp || isIco;
  }
}
