class CompanySearchResult {
  const CompanySearchResult({
    required this.name,
    required this.websiteUrl,
    this.email,
  });

  final String name;
  final String websiteUrl;
  final String? email;

  CompanySearchResult copyWith({
    String? name,
    String? websiteUrl,
    String? email,
  }) {
    return CompanySearchResult(
      name: name ?? this.name,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      email: email ?? this.email,
    );
  }
}
