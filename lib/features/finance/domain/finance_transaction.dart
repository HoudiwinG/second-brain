import '../../../core/result/result.dart';

enum FinanceTransactionType {
  income,
  expense;

  static FinanceTransactionType fromDb(String value) => value == 'income'
      ? FinanceTransactionType.income
      : FinanceTransactionType.expense;
}

/// Финансовая операция: доход или расход.
class FinanceTransaction {
  const FinanceTransaction({
    required this.id,
    required this.amount,
    required this.currency,
    required this.type,
    required this.category,
    required this.account,
    required this.date,
    required this.note,
    required this.isPrivateForLlm,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  });

  final int id;
  final double amount;
  final String currency;
  final FinanceTransactionType type;
  final String? category;
  final String? account;
  final DateTime date;
  final String? note;
  final bool isPrivateForLlm;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  /// Знаковая сумма: доход положительный, расход отрицательный.
  double get signedAmount =>
      type == FinanceTransactionType.income ? amount : -amount;
}

/// Данные для создания/полного обновления операции.
class FinanceDraft {
  const FinanceDraft({
    required this.amount,
    required this.type,
    required this.date,
    this.currency = 'RUB',
    this.category,
    this.account,
    this.note,
    this.isPrivateForLlm = false,
  });

  final double amount;
  final String currency;
  final FinanceTransactionType type;
  final String? category;
  final String? account;
  final DateTime date;
  final String? note;
  final bool isPrivateForLlm;
}

/// Итоги за период (в валюте выборки; смешивание валют не поддерживается).
class FinanceSummary {
  const FinanceSummary({
    required this.income,
    required this.expense,
    required this.transactions,
  });

  final double income;
  final double expense;
  final int transactions;

  double get balance => income - expense;
}

abstract interface class FinanceRepository {
  Future<Result<List<FinanceTransaction>>> list({
    DateTime? from,
    DateTime? to,
    FinanceTransactionType? type,
    String? currency,
    bool includeDeleted = false,
    bool forLlm = false,
  });

  Future<Result<FinanceTransaction?>> getById(
    int id, {
    bool includeDeleted = false,
  });

  Future<Result<FinanceTransaction>> create(FinanceDraft draft);

  Future<Result<FinanceTransaction>> update(int id, FinanceDraft draft);

  Future<Result<void>> softDelete(int id);

  Future<Result<void>> restore(int id);

  Future<Result<FinanceSummary>> summary({
    DateTime? from,
    DateTime? to,
    String? currency,
    bool forLlm = false,
  });
}
