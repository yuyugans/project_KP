import 'package:flutter/services.dart';

String formatCurrency(double value) {
  final amount = value.toStringAsFixed(0);
  final formattedAmount = amount.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match.group(1)}.',
  );

  return 'Rp $formattedAmount';
}

double parseCurrencyInput(String value) {
  return double.tryParse(value.replaceAll('.', '').trim()) ?? 0;
}

class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  const ThousandsSeparatorInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');

    if (digits.isEmpty) {
      return const TextEditingValue();
    }

    final formatted = digits.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match.group(1)}.',
    );

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
