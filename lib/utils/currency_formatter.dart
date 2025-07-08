import 'package:intl/intl.dart';

String formatToIDR(double amount) {
  final NumberFormat currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );
  return currencyFormatter.format(amount);
}

String formatDateTime(String isoString) {
  final dateTime = DateTime.tryParse(isoString);
  if (dateTime == null) return isoString;
  final dateFormat = DateFormat('dd-MM-yyyy HH:mm:ss');
  return dateFormat.format(dateTime);
}

String formatDate(DateTime date) {
  final dateFormat = DateFormat('dd-MM-yyyy');
  return dateFormat.format(date);
}
