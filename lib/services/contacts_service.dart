import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';

enum ContactsPermissionResult {
  granted,
  denied,
  permanentlyDenied,
}

class ContactsService {
  static Future<ContactsPermissionResult> requestContactsPermission() async {
    final status = await Permission.contacts.request();
    if (status.isGranted || status.isLimited) {
      return ContactsPermissionResult.granted;
    }
    if (status.isPermanentlyDenied) {
      return ContactsPermissionResult.permanentlyDenied;
    }
    return ContactsPermissionResult.denied;
  }

  static Future<void> createContact({
    required String companyName,
    required String phoneNumber,
    Uint8List? photoBytes,
    bool photoAlreadyAdjusted = false,
  }) async {
    final granted = await FlutterContacts.requestPermission();
    if (!granted) {
      throw Exception('Contacts permission was not granted.');
    }

    final optimizedPhotoBytes = photoAlreadyAdjusted
        ? photoBytes
        : _optimizePhotoForContactBubble(photoBytes);

    final contact = Contact(
      name: Name(first: companyName),
      phones: [Phone(phoneNumber)],
      photo: optimizedPhotoBytes,
    );

    await FlutterContacts.insertContact(contact);
  }

  static Uint8List? _optimizePhotoForContactBubble(Uint8List? originalBytes) {
    if (originalBytes == null || defaultTargetPlatform != TargetPlatform.iOS) {
      return originalBytes;
    }

    final decoded = img.decodeImage(originalBytes);
    if (decoded == null || decoded.width == 0 || decoded.height == 0) {
      return originalBytes;
    }

    const targetSize = 512;
    const logoInset = 0;
    final maxDimension =
        decoded.width > decoded.height ? decoded.width : decoded.height;
    if (maxDimension == 0) {
      return originalBytes;
    }

    final fitScale = (targetSize - (logoInset * 2)) / maxDimension.toDouble();
    final resizedWidth =
        (decoded.width * fitScale).round().clamp(1, targetSize);
    final resizedHeight =
        (decoded.height * fitScale).round().clamp(1, targetSize);

    final resizedLogo = img.copyResize(
      decoded,
      width: resizedWidth,
      height: resizedHeight,
      interpolation: img.Interpolation.average,
    );

    final flattened = img.Image(
      width: targetSize,
      height: targetSize,
    );

    img.fill(flattened, color: img.ColorRgb8(255, 255, 255));

    final offsetX = (targetSize - resizedLogo.width) ~/ 2;
    final offsetY = (targetSize - resizedLogo.height) ~/ 2;
    img.compositeImage(flattened, resizedLogo, dstX: offsetX, dstY: offsetY);

    return Uint8List.fromList(img.encodeJpg(flattened, quality: 92));
  }
}
