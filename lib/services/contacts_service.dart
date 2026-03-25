import 'dart:typed_data';

import 'package:flutter_contacts/flutter_contacts.dart';
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
  }) async {
    final granted = await FlutterContacts.requestPermission();
    if (!granted) {
      throw Exception('Contacts permission was not granted.');
    }

    final contact = Contact(
      name: Name(first: companyName),
      phones: [Phone(phoneNumber)],
      photo: photoBytes,
    );

    await FlutterContacts.insertContact(contact);
  }
}
