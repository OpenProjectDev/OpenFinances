/// Which of the two independent ledgers a row belongs to. Expenses and
/// income are never netted against each other — this just tags rows so
/// a merged list/sheet knows which provider and category set to use.
enum TransactionKind { expense, income }
