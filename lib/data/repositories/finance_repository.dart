import 'package:drift/drift.dart';

import '../../core/error/app_exception.dart';
import '../../core/result/result.dart';
import '../../features/finance/domain/finance_transaction.dart';
import '../db/app_database.dart' as db;
import '../search/search_index.dart';
import 'repository_guard.dart';

/// Drift-реализация [FinanceRepository].
class DriftFinanceRepository implements FinanceRepository {
  DriftFinanceRepository(this._db);

  final db.AppDatabase _db;

  @override
  Future<Result<List<FinanceTransaction>>> list({
    DateTime? from,
    DateTime? to,
    FinanceTransactionType? type,
    String? currency,
    bool includeDeleted = false,
    bool forLlm = false,
  }) {
    return RepositoryGuard.guard('FinanceRepository.list', () async {
      final rows = await _query(
        from: from,
        to: to,
        type: type,
        currency: currency,
        includeDeleted: includeDeleted,
        forLlm: forLlm,
      );
      return rows.map(_toDomain).toList();
    });
  }

  @override
  Future<Result<FinanceTransaction?>> getById(
    int id, {
    bool includeDeleted = false,
  }) {
    return RepositoryGuard.guard('FinanceRepository.getById', () async {
      final row = await _find(id, includeDeleted: includeDeleted);
      return row == null ? null : _toDomain(row);
    });
  }

  @override
  Future<Result<FinanceTransaction>> create(FinanceDraft draft) {
    return RepositoryGuard.guard('FinanceRepository.create', () async {
      _validate(draft);
      final now = DateTime.now().toUtc();
      late FinanceTransaction created;
      await _db.transaction(() async {
        final id = await _db
            .into(_db.financeTransactions)
            .insert(
              db.FinanceTransactionsCompanion.insert(
                amount: draft.amount,
                currency: Value(draft.currency.trim().toUpperCase()),
                type: draft.type.name,
                category: Value(_nullIfBlank(draft.category)),
                account: Value(_nullIfBlank(draft.account)),
                date: draft.date,
                note: Value(_nullIfBlank(draft.note)),
                isPrivateForLlm: Value(draft.isPrivateForLlm),
                createdAt: now,
                updatedAt: now,
              ),
            );
        await indexFinance(_db, id);
        final row = await _find(id);
        created = _toDomain(row!);
      });
      return created;
    });
  }

  @override
  Future<Result<FinanceTransaction>> update(int id, FinanceDraft draft) {
    return RepositoryGuard.guard('FinanceRepository.update', () async {
      _validate(draft);
      final current = await _find(id);
      if (current == null) {
        throw ValidationException('FinanceRepository: операция $id не найдена');
      }
      late FinanceTransaction updated;
      await _db.transaction(() async {
        await (_db.update(
          _db.financeTransactions,
        )..where((t) => t.id.equals(id))).write(
          db.FinanceTransactionsCompanion(
            amount: Value(draft.amount),
            currency: Value(draft.currency.trim().toUpperCase()),
            type: Value(draft.type.name),
            category: Value(_nullIfBlank(draft.category)),
            account: Value(_nullIfBlank(draft.account)),
            date: Value(draft.date),
            note: Value(_nullIfBlank(draft.note)),
            isPrivateForLlm: Value(draft.isPrivateForLlm),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
        await indexFinance(_db, id);
        final row = await _find(id);
        updated = _toDomain(row!);
      });
      return updated;
    });
  }

  @override
  Future<Result<void>> softDelete(int id) {
    return RepositoryGuard.guard('FinanceRepository.softDelete', () async {
      final current = await _find(id);
      if (current == null) {
        throw ValidationException('FinanceRepository: операция $id не найдена');
      }
      final now = DateTime.now().toUtc();
      await _db.transaction(() async {
        await (_db.update(
          _db.financeTransactions,
        )..where((t) => t.id.equals(id))).write(
          db.FinanceTransactionsCompanion(
            deletedAt: Value(now),
            updatedAt: Value(now),
          ),
        );
        await indexFinance(_db, id);
      });
    });
  }

  @override
  Future<Result<void>> restore(int id) {
    return RepositoryGuard.guard('FinanceRepository.restore', () async {
      final current = await _find(id, includeDeleted: true);
      if (current == null) {
        throw ValidationException('FinanceRepository: операция $id не найдена');
      }
      await _db.transaction(() async {
        await (_db.update(
          _db.financeTransactions,
        )..where((t) => t.id.equals(id))).write(
          db.FinanceTransactionsCompanion(
            deletedAt: const Value(null),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
        await indexFinance(_db, id);
      });
    });
  }

  @override
  Future<Result<FinanceSummary>> summary({
    DateTime? from,
    DateTime? to,
    String? currency,
    bool forLlm = false,
  }) {
    return RepositoryGuard.guard('FinanceRepository.summary', () async {
      final rows = await _query(
        from: from,
        to: to,
        currency: currency,
        forLlm: forLlm,
      );
      var income = 0.0;
      var expense = 0.0;
      for (final row in rows) {
        if (row.type == FinanceTransactionType.income.name) {
          income += row.amount;
        } else {
          expense += row.amount;
        }
      }
      return FinanceSummary(
        income: income,
        expense: expense,
        transactions: rows.length,
      );
    });
  }

  Future<List<db.FinanceTransaction>> _query({
    DateTime? from,
    DateTime? to,
    FinanceTransactionType? type,
    String? currency,
    bool includeDeleted = false,
    bool forLlm = false,
  }) async {
    final query = _db.select(_db.financeTransactions);
    if (!includeDeleted) {
      query.where((t) => t.deletedAt.isNull());
    }
    if (from != null) {
      query.where((t) => t.date.isBiggerOrEqualValue(from));
    }
    if (to != null) {
      // Верхняя граница эксклюзивна: диапазон [from, to). Это позволяет
      // передавать начало следующего месяца/дня без риска захватить 00:00
      // следующего периода (R02-005).
      query.where((t) => t.date.isSmallerThanValue(to));
    }
    if (type != null) {
      query.where((t) => t.type.equals(type.name));
    }
    if (currency != null) {
      query.where((t) => t.currency.equals(currency.toUpperCase()));
    }
    if (forLlm) {
      query.where((t) => t.isPrivateForLlm.equals(false));
    }
    query.orderBy([(t) => OrderingTerm.desc(t.date)]);
    return query.get();
  }

  Future<db.FinanceTransaction?> _find(int id, {bool includeDeleted = false}) {
    final query = _db.select(_db.financeTransactions)
      ..where((t) => t.id.equals(id));
    if (!includeDeleted) {
      query.where((t) => t.deletedAt.isNull());
    }
    return query.getSingleOrNull();
  }

  void _validate(FinanceDraft draft) {
    if (!draft.amount.isFinite || draft.amount <= 0) {
      throw const ValidationException(
        'FinanceRepository: сумма должна быть положительным числом',
      );
    }
    if (draft.currency.trim().isEmpty) {
      throw const ValidationException(
        'FinanceRepository: валюта не может быть пустой',
      );
    }
  }

  String? _nullIfBlank(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  FinanceTransaction _toDomain(db.FinanceTransaction row) => FinanceTransaction(
    id: row.id,
    amount: row.amount,
    currency: row.currency,
    type: FinanceTransactionType.fromDb(row.type),
    category: row.category,
    account: row.account,
    date: row.date,
    note: row.note,
    isPrivateForLlm: row.isPrivateForLlm,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    deletedAt: row.deletedAt,
  );
}
