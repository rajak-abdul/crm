class AccountCurrency {
  final String currency;

  const AccountCurrency({
    required this.currency,
  });

  factory AccountCurrency.fromJson(Map<String, dynamic> json) {
    return AccountCurrency(
      currency: json['currency']?.toString().trim().toUpperCase() ?? 'INR',
    );
  }
}