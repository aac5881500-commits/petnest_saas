class OwnerCashflowTotals {
  const OwnerCashflowTotals({
    required this.systemIncome,
    required this.otherIncome,
    required this.salary,
    required this.otherExpense,
  });
  factory OwnerCashflowTotals.fromEntries(
    int systemIncome,
    List<Map<String, dynamic>> entries,
  ) {
    int sum(String kind) => entries
        .where((e) => e['kind'] == kind)
        .fold<int>(0, (v, e) => v + (e['amount'] as num).toInt());
    return OwnerCashflowTotals(
      systemIncome: systemIncome,
      otherIncome: sum('income'),
      salary: sum('salary'),
      otherExpense: sum('expense'),
    );
  }
  final int systemIncome, otherIncome, salary, otherExpense;
  int get totalIncome => systemIncome + otherIncome;
  int get totalExpense => salary + otherExpense;
  int get balance => totalIncome - totalExpense;
}
