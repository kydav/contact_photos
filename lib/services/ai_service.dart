import 'package:contact_photos/extensions/string_extensions.dart';
import 'package:contact_photos/models/company_search_result.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';

class AiService {
  static Future<List<CompanySearchResult>> queryCompaniesFromGemini(
      String query) async {
    debugPrint('Querying Gemini for companies matching: $query');
    final model = FirebaseAI.googleAI().generativeModel(
      model: 'gemini-2.5-flash',
      generationConfig: GenerationConfig(responseMimeType: 'application/json'),
    );

    final response = await model.generateContent([
      Content.text('''
      Return JSON only in this format:
      {
        "companies": [
          {"name":"Company Name","websiteUrl":"https://example.com"}
        ]
      }

      Task:
      - Find up to 6 likely companies that match the query "$query".
      - Include only real companies and their official website URLs.
      - Use absolute https URLs.
      '''),
    ]);
    if (response.text == null || response.text!.trim().isEmpty) {
      throw Exception('AI returned empty response.');
    }

    final parsedCompanies = response.text!.parseCompanies();
    if (parsedCompanies.isEmpty) {
      throw Exception('No valid companies returned by AI.');
    }
    return parsedCompanies;
  }
}
