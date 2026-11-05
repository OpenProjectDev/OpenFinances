/// Toman and rial are one currency in two units (1 toman = 10 rial).
///
/// Amounts are stored exactly as recorded, with the unit they were recorded
/// in (each row's `currency`); nothing is ever rewritten when the user picks
/// another unit. Only what's shown is converted: toman <-> rial by the fixed
/// 1:10 ratio. Other currencies (USD, EUR) have no fixed rate, so they're
/// shown as recorded.
library;

const Map<String, int> _rialPerUnit = {'IRT': 10, 'IRR': 1};

bool isIranianUnit(String? code) => _rialPerUnit.containsKey(code);

/// [minor] recorded in [from], expressed in [to]. Converts only between
/// toman and rial; anything else (or an unknown unit) is returned as is.
int amountInUnit(int minor, String? from, String to) {
  final a = _rialPerUnit[from];
  final b = _rialPerUnit[to];
  if (a == null || b == null || a == b) return minor;
  return (minor * a / b).round();
}

/// Pref keys of the Budget page's per-category budgets (minor units) and
/// the unit they were recorded in.
const String kBudgetsPrefsKey = 'catBudgetsV1';
const String kBudgetsUnitPrefsKey = 'catBudgetsUnitV1';
