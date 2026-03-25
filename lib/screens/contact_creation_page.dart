import 'dart:async';

import 'package:contact_photos/models/company_image_option.dart';
import 'package:contact_photos/models/company_search_result.dart';
import 'package:contact_photos/services/contacts_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

typedef ContactCreatedCallback = void Function();

class ContactCreationPage extends HookWidget {
  const ContactCreationPage({
    required this.company,
    required this.imageOption,
    required this.onContactCreated,
    super.key,
  });

  final CompanySearchResult company;
  final CompanyImageOption imageOption;
  final ContactCreatedCallback onContactCreated;

  @override
  Widget build(BuildContext context) {
    final phoneController = useTextEditingController();
    final isSaving = useState(false);
    final localError = useState<String?>(null);

    Future<void> createContact() async {
      final phoneNumber = phoneController.text.trim();
      if (phoneNumber.isEmpty) {
        localError.value = 'Please enter a phone number.';
        return;
      }

      isSaving.value = true;
      localError.value = null;

      try {
        await ContactsService.createContact(
          companyName: company.name,
          phoneNumber: phoneNumber,
          photoBytes: imageOption.bytes,
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Created contact for ${company.name}.')),
        );
        onContactCreated();
      } catch (error) {
        if (!context.mounted) return;
        final message = 'Failed to create contact: $error';
        localError.value = message;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      } finally {
        isSaving.value = false;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Create Contact',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text('Company: ${company.name}'),
        const SizedBox(height: 8),
        SizedBox(
          height: 110,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              imageOption.bytes,
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Phone number',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: isSaving.value ? null : () => unawaited(createContact()),
          child: const Text('Create Contact'),
        ),
        if (isSaving.value) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ],
        if (localError.value != null) ...[
          const SizedBox(height: 8),
          Text(
            localError.value!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}
