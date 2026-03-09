import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:http/http.dart' as http;

class CompanyProfile {
  const CompanyProfile({
    required this.name,
    required this.phoneNumber,
    required this.logoUrl,
  });

  final String name;
  final String phoneNumber;
  final String logoUrl;
}

const List<CompanyProfile> _companyProfiles = [
  CompanyProfile(
    name: 'USPS',
    phoneNumber: '28777',
    logoUrl:
        'https://about.usps.com/newsroom/media-kit/mobile/USPS_Logo_128x128.jpg',
  ),
];

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _activeCompany;

  List<CompanyProfile> get _filteredCompanies {
    final normalizedQuery = _searchQuery.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return _companyProfiles;
    }
    return _companyProfiles
        .where((company) => company.name.toLowerCase().contains(normalizedQuery))
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _createContactForCompany(CompanyProfile company) async {
    setState(() => _activeCompany = company.name);

    try {
      final hasPermission = await FlutterContacts.requestPermission(
        readonly: false,
      );
      if (!hasPermission) {
        _showMessage('Contacts permission is required to create contacts.');
        return;
      }

      final logoBytes = await _fetchLogoBytes(company.logoUrl);
      final existingContact = await _findExistingContact(company);
      final isNewContact = existingContact == null;

      if (existingContact == null) {
        final newContact = Contact(
          name: Name(first: company.name),
          phones: [Phone(company.phoneNumber)],
          photo: logoBytes,
        );
        await newContact.insert();
      } else {
        existingContact.photo = logoBytes;
        final hasPhoneNumber = existingContact.phones.any(
          (phone) =>
              _normalizePhoneNumber(phone.number) ==
              _normalizePhoneNumber(company.phoneNumber),
        );
        if (!hasPhoneNumber) {
          existingContact.phones.add(Phone(company.phoneNumber));
        }
        await existingContact.update();
      }

      _showMessage(
        isNewContact
            ? '${company.name} contact created.'
            : '${company.name} contact updated.',
      );
    } catch (error) {
      _showMessage('Could not create contact: $error');
    } finally {
      if (mounted) {
        setState(() => _activeCompany = null);
      }
    }
  }

  Future<Contact?> _findExistingContact(CompanyProfile company) async {
    final contacts = await FlutterContacts.getContacts(
      withProperties: true,
      query: company.name,
    );

    for (final contact in contacts) {
      for (final phone in contact.phones) {
        if (_normalizePhoneNumber(phone.number) ==
            _normalizePhoneNumber(company.phoneNumber)) {
          return contact;
        }
      }
    }
    return null;
  }

  Future<Uint8List> _fetchLogoBytes(String logoUrl) async {
    final response = await http.get(Uri.parse(logoUrl));
    if (response.statusCode != 200) {
      throw Exception('Logo download failed with status ${response.statusCode}');
    }
    return response.bodyBytes;
  }

  String _normalizePhoneNumber(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final companies = _filteredCompanies;
    return Scaffold(
      appBar: AppBar(title: const Text('Company Contacts')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Search common text-message senders',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: const InputDecoration(
                labelText: 'Search companies',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: companies.isEmpty
                  ? const Center(child: Text('No matching companies found.'))
                  : ListView.builder(
                      itemCount: companies.length,
                      itemBuilder: (context, index) {
                        final company = companies[index];
                        final isCreating = _activeCompany == company.name;
                        return Card(
                          child: ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                company.logoUrl,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) {
                                  return const ColoredBox(
                                    color: Color(0xFF004B87),
                                    child: SizedBox(
                                      width: 44,
                                      height: 44,
                                      child: Icon(
                                        Icons.local_post_office,
                                        color: Colors.white,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            title: Text(company.name),
                            subtitle: Text('Text number: ${company.phoneNumber}'),
                            trailing: isCreating
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : FilledButton(
                                    onPressed: () =>
                                        _createContactForCompany(company),
                                    child: const Text('Create'),
                                  ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
