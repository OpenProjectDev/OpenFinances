"""A US-English demo backup (JSON) for store screenshots: USD, Gregorian
dates, ~14 months of believable spending and income, budgets, upcoming
payments, debts both ways. Dark theme with the app's default color, English, no bank messages tab.

    python tool/make_us_demo_backup.py [--today 2026-10-29] [--out PATH]

Deterministic (fixed seed). Output defaults to build/us_demo_backup/.
"""

import argparse
import json
import os
import random
import uuid
from datetime import date, datetime, timedelta, timezone

NYC = timezone(timedelta(hours=-5))
RNG = random.Random(2026)


def gid():
    return str(uuid.UUID(int=RNG.getrandbits(128), version=4))


def iso_utc(dt):
    u = dt.astimezone(timezone.utc)
    return u.strftime('%Y-%m-%dT%H:%M:%S.') + f'{u.microsecond // 1000:03d}Z'


def at(d, hour, minute=None):
    return datetime(d.year, d.month, d.day, hour,
                    RNG.randint(0, 59) if minute is None else minute, tzinfo=NYC)


def usd(lo, hi=None, step=1):
    """Random dollar amount in [lo, hi] as cents (whole `step` dollars when
    step > 1, real cents when step == 1)."""
    v = RNG.uniform(lo, hi if hi is not None else lo)
    if step == 1:
        return int(round(v * 100))
    return int(round(v / step) * step) * 100


# (gid, name, Material code point, ARGB color) - code points from the app's list
EXP_CATS = [
    ('cat_groceries', 'Groceries', 0xe59c, 0xFF43A047),
    ('cat_dining', 'Dining out', 0xe532, 0xFFE53935),
    ('cat_coffee', 'Coffee', 0xe38d, 0xFF8D6E63),
    ('cat_rideshare', 'Rideshare', 0xe3a7, 0xFFFDD835),
    ('cat_gas', 'Gas', 0xe394, 0xFFFB8C00),
    ('cat_transit', 'Transit', 0xe1d5, 0xFF00897B),
    ('cat_rent', 'Rent', 0xf107, 0xFF5E35B1),
    ('cat_utilities', 'Utilities', 0xe0ee, 0xFFFFB300),
    ('cat_phone', 'Phone & internet', 0xe4aa, 0xFF1E88E5),
    ('cat_health', 'Health', 0xe39e, 0xFFD81B60),
    ('cat_clothes', 'Clothing', 0xe59a, 0xFF8E24AA),
    ('cat_fun', 'Entertainment', 0xe655, 0xFFF4511E),
    ('cat_subs', 'Subscriptions', 0xf1f5, 0xFF3949AB),
    ('cat_edu', 'Education', 0xe559, 0xFF00ACC1),
    ('cat_gifts', 'Gifts', 0xef0f, 0xFFEC407A),
    ('cat_gym', 'Fitness', 0xe28d, 0xFF7CB342),
    ('cat_pets', 'Pets', 0xe4a1, 0xFF6D4C41),
    ('cat_home', 'Home', 0xe6e1, 0xFF546E7A),
    ('cat_travel', 'Travel', 0xe297, 0xFF039BE5),
    ('cat_general', 'General', 0xe148, 0xFF607D8B),  # the app's seed gid
]
INC_CATS = [
    ('inccat_salary', 'Salary', 0xe6f4, 0xFF2E7D32),
    ('inccat_freelance', 'Freelance', 0xe369, 0xFF1565C0),
    ('inccat_interest', 'Interest', 0xf336, 0xFF00838F),
    ('inccat_bonus', 'Bonus', 0xf24e, 0xFFF9A825),
    ('inccat_gift', 'Gift', 0xe25c, 0xFFAD1457),
    ('inccat_sales', 'Selling things', 0xe60c, 0xFF6A1B9A),
    ('inccat_general', 'General', 0xe148, 0xFF607D8B),  # the app's seed gid
]
START = date(2025, 9, 1)


def cat_rows(cats):
    created = iso_utc(at(START, 9, 0) - timedelta(days=3))
    return [{
        'gid': g, 'name': n, 'sort': i,
        'createdAtUtc': created, 'updatedAtUtc': created,
        'isDeleted': False, 'isDirty': True,
        'iconCodePoint': cp, 'iconFontFamily': 'MaterialIcons', 'color': c,
    } for i, (g, n, cp, c) in enumerate(cats)]


def entry(when, title, amount, cat, note=None, now=None):
    created = when + timedelta(minutes=RNG.randint(1, 120))
    if now and created > now:
        created = now
    return {
        'gid': gid(), 'title': title, 'amountMinor': amount, 'currency': 'USD',
        'occurredAtUtc': iso_utc(when), 'note': note, 'categoryGid': cat,
        'accountGid': None, 'version': 1,
        'createdAtUtc': iso_utc(created), 'updatedAtUtc': iso_utc(created),
        'isDeleted': False, 'isDirty': True,
    }


def maybe(options, p):
    return RNG.choice(options) if RNG.random() < p else None


def generate_expenses(today, now):
    out = []
    d = START

    def add(when, *a, **k):
        if when <= now:
            out.append(entry(when, *a, now=now, **k))

    while d <= today:
        wd = d.weekday()  # Mon=0
        weekend = wd >= 5
        if d.day == 1:
            add(at(d, 9), 'Rent', usd(1850), 'cat_rent', 'Sent to landlord')
        if d.day == 3:
            add(at(d, 18), 'Gym membership', usd(39.99), 'cat_gym')
            add(at(d, 21), 'Netflix', usd(15.49), 'cat_subs')
        if d.day == 5:
            add(at(d, 12), 'Internet', usd(64.99), 'cat_phone')
            add(at(d, 12), 'Phone plan', usd(35), 'cat_phone')
        if d.day == 8:
            add(at(d, 20), 'Spotify', usd(11.99), 'cat_subs')
        if d.day == 12:
            hot = d.month in (6, 7, 8, 9)
            add(at(d, 9), 'Electric bill',
                usd(70, 125) if hot else usd(45, 80), 'cat_utilities')
        if d.day == 15:
            add(at(d, 9), 'Gas & water', usd(35, 70), 'cat_utilities')
            add(at(d, 19), 'Cat food & litter', usd(25, 55), 'cat_pets')
        if d.day == 18:
            add(at(d, 10), 'Renters insurance', usd(14), 'cat_general')
        # weekly-ish
        if RNG.random() < (0.45 if weekend else 0.22):
            add(at(d, RNG.randint(9, 20)),
                RNG.choice(["Trader Joe's", 'Whole Foods', 'Costco run',
                            'Safeway', 'Farmers market']),
                usd(28, 140), 'cat_groceries')
        if RNG.random() < (0.35 if wd < 5 else 0.2):
            add(at(d, RNG.randint(7, 15)),
                RNG.choice(['Starbucks', 'Latte', 'Blue Bottle', 'Cold brew']),
                usd(4.5, 8.5), 'cat_coffee')
        if RNG.random() < (0.28 if wd in (4, 5) else 0.1):
            add(at(d, RNG.choice([12, 13, 19, 20, 21])),
                RNG.choice(['Chipotle', 'Thai takeout', 'Pizza night', 'Sushi',
                            'Burger joint', 'Brunch', 'Ramen']),
                usd(14, 78), 'cat_dining',
                maybe(['With Sam', 'Date night', 'Team lunch', 'With the girls'], 0.3))
        if RNG.random() < 0.16:
            add(at(d, RNG.randint(7, 23)), RNG.choice(['Uber', 'Lyft']),
                usd(9, 38), 'cat_rideshare')
        if RNG.random() < 0.1:
            add(at(d, RNG.randint(8, 19)), 'Gas station', usd(32, 58), 'cat_gas')
        if RNG.random() < 0.12 and not weekend:
            add(at(d, 8), 'Transit pass top-up', usd(10, 30, 5), 'cat_transit')
        # occasional
        if RNG.random() < 0.02:
            add(at(d, RNG.randint(9, 19)),
                RNG.choice(['Pharmacy', 'Doctor copay', 'Dentist', 'Eye exam']),
                usd(15, 160), 'cat_health')
        if RNG.random() < 0.03:
            add(at(d, RNG.randint(11, 20)),
                RNG.choice(['Sneakers', 'Jeans', 'Jacket', 'T-shirts', 'Winter coat']),
                usd(30, 160), 'cat_clothes')
        if RNG.random() < 0.05:
            add(at(d, RNG.randint(17, 22)),
                RNG.choice(['Movie tickets', 'Concert', 'Bowling', 'Museum',
                            'Comedy show']),
                usd(14, 90), 'cat_fun', maybe(['With friends', 'Date night'], 0.4))
        if RNG.random() < 0.02:
            add(at(d, RNG.randint(10, 20)),
                RNG.choice(['Online course', 'Textbook', 'Language app']),
                usd(15, 120), 'cat_edu')
        if RNG.random() < 0.02:
            add(at(d, RNG.randint(10, 20)),
                RNG.choice(['Lamp', 'Kitchenware', 'Bedding', 'Shelf', 'Plants']),
                usd(18, 140), 'cat_home')
        if RNG.random() < 0.01:
            add(at(d, RNG.randint(10, 20)), 'Vet visit', usd(60, 220), 'cat_pets')
        if RNG.random() < 0.012:
            add(at(d, RNG.randint(9, 18)),
                RNG.choice(['ATM fee', 'Parking ticket', 'Car wash', 'Misc']),
                usd(5, 75), 'cat_general')
        # yearly rhythms
        if (d.month, d.day) in ((11, 20), (12, 18)):
            add(at(d, 17), 'Holiday gifts', usd(80, 220), 'cat_gifts', 'For family')
        if (d.month, d.day) in ((3, 14), (7, 9)):
            add(at(d, 19), 'Birthday gift', usd(40, 90), 'cat_gifts',
                {(3, 14): "Sam's birthday", (7, 9): "Mom's birthday"}[(d.month, d.day)])
        if (d.month, d.day) in ((12, 22), (6, 10)):
            add(at(d, 9), 'Flights', usd(280, 520), 'cat_travel',
                'Chicago' if d.month == 12 else 'Austin')
            add(at(d + timedelta(days=1), 14), 'Hotel', usd(240, 480), 'cat_travel')
            add(at(d + timedelta(days=2), 21), 'Dinner out', usd(60, 140), 'cat_dining')
        d += timedelta(days=1)
    # one without a category (UI edge case)
    mid = START + timedelta(days=150)
    out.append(entry(at(mid, 15), 'Cash payment', usd(25), None, now=now))
    return out


def generate_incomes(today, now):
    out = []
    d = START
    salary = 5200

    def add(when, *a, **k):
        if when <= now:
            out.append(entry(when, *a, now=now, **k))

    while d <= today:
        if d.month == 1 and d.day == 1:
            salary = 5450  # yearly raise
        if d.day in (1, 15):
            add(at(d, 9), 'Paycheck', usd(salary / 2), 'inccat_salary')
        if d.day == 28:
            add(at(d, 8), 'Savings interest', usd(18, 34), 'inccat_interest')
        if (d.month, d.day) in ((6, 30), (12, 20)):
            add(at(d, 11), 'Performance bonus', usd(1500, 2500, 50), 'inccat_bonus')
        if RNG.random() < 0.025:
            add(at(d, RNG.randint(10, 20)),
                RNG.choice(['Logo design', 'Website fix', 'Consulting call',
                            'Translation job']),
                usd(150, 900, 10), 'inccat_freelance',
                maybe(['Half upfront', 'Paid in full'], 0.4))
        if RNG.random() < 0.004:
            add(at(d, 17), RNG.choice(['Sold old phone', 'Sold bike', 'Sold books']),
                usd(40, 380, 5), 'inccat_sales')
        if (d.month, d.day) == (12, 25):
            add(at(d, 12), 'Holiday gift from Grandma', usd(100), 'inccat_gift')
        d += timedelta(days=1)
    return out


def generate_upcoming(today, now):
    items = [
        (-4, 'Credit card payment', 215.40, 'cat_general', None),
        (-1, 'Electric bill', 82.10, 'cat_utilities', None),
        (0, 'Netflix', 15.49, 'cat_subs', None),
        (3, 'Rent', 1850, 'cat_rent', 'Due Nov 1'),
        (5, 'Car insurance', 138, 'cat_general', None),
        (9, 'Gym membership', 39.99, 'cat_gym', None),
        (16, "Mom's birthday gift", 60, 'cat_gifts', None),
        (27, 'Dentist check-up', 95, 'cat_health', None),
        (52, 'Holiday flights', 420, 'cat_travel', 'Chicago'),
    ]
    out = []
    for days, title, amount, cat, note in items:
        due = datetime.combine(today + timedelta(days=days),
                               datetime.min.time(), tzinfo=NYC)
        created = now - timedelta(days=RNG.randint(3, 30), hours=RNG.randint(0, 12))
        out.append({
            'gid': gid(), 'title': title, 'amountMinor': int(round(amount * 100)),
            'currency': 'USD', 'dueAtUtc': iso_utc(due), 'note': note,
            'categoryGid': cat, 'version': 1,
            'createdAtUtc': iso_utc(created), 'updatedAtUtc': iso_utc(created),
        })
    history = [{'title': u['title'], 'amountMinor': u['amountMinor'],
                'categoryGid': u['categoryGid'],
                'lastUsedAtUtc': iso_utc(now - timedelta(days=i * 2 + 1))}
               for i, u in enumerate(out)]
    return out, history


def generate_debts(today, now):
    rows, pays = [], []

    def debt(direction, person, title, amount, started_days_ago,
             due_in=None, note=None, paid=()):
        g = gid()
        started = now - timedelta(days=started_days_ago)
        rows.append({
            'gid': g, 'direction': direction, 'person': person, 'title': title,
            'amountMinor': amount * 100, 'currency': 'USD',
            'startedAtUtc': iso_utc(started),
            'dueAtUtc': None if due_in is None else iso_utc(datetime.combine(
                today + timedelta(days=due_in), datetime.min.time(), tzinfo=NYC)),
            'note': note, 'version': 1,
            'createdAtUtc': iso_utc(started), 'updatedAtUtc': iso_utc(started),
        })
        for days_ago, p in paid:
            when = now - timedelta(days=days_ago)
            pays.append({
                'gid': gid(), 'debtGid': g, 'amountMinor': p * 100,
                'currency': 'USD', 'paidAtUtc': iso_utc(when), 'version': 1,
                'createdAtUtc': iso_utc(when), 'updatedAtUtc': iso_utc(when),
            })

    debt('owe', 'Dad', 'Car down payment', 3000, 160, note='No rush',
         paid=[(120, 500), (70, 500), (25, 400)])
    debt('owe', 'Jordan Lee', 'Rent shortfall', 400, 20, due_in=9)
    debt('owe', 'Mom', 'Phone repair', 180, 12, paid=[(5, 60)])
    debt('owed', 'Sam', 'Concert tickets', 160, 18)
    debt('owed', 'Riley', 'Laptop loan', 900, 70, due_in=21, paid=[(35, 300)])
    debt('owed', 'Taylor', 'Group dinner', 48, 3)
    debt('owed', 'Casey', 'Trip share', 240, 50, paid=[(15, 240)])
    return rows, pays


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--today', default='2026-10-29')
    ap.add_argument('--out')
    a = ap.parse_args()
    today = date.fromisoformat(a.today)
    now = datetime.combine(today, datetime.min.time(), tzinfo=NYC).replace(hour=14)

    expenses = sorted(generate_expenses(today, now), key=lambda e: e['occurredAtUtc'])
    incomes = sorted(generate_incomes(today, now), key=lambda e: e['occurredAtUtc'])
    upcoming, history = generate_upcoming(today, now)
    debts, debt_payments = generate_debts(today, now)
    # Budgets from this month's actual spending, at varied fill levels
    # (spent / budget), so the Budget page shows a mix: low, mid, nearly
    # full and one over. Whole dollars, in minor units (cents).
    this_month = today.strftime('%Y-%m')
    spent = {}
    for e in expenses:
        if e['occurredAtUtc'][:7] == this_month and e['categoryGid']:
            spent[e['categoryGid']] = spent.get(e['categoryGid'], 0) + e['amountMinor']
    fill = {  # share of the budget used
        'cat_rent': 1.0, 'cat_groceries': 0.82, 'cat_dining': 0.58,
        'cat_gas': 1.28, 'cat_fun': 0.47, 'cat_clothes': 0.31,
        'cat_utilities': 0.64, 'cat_phone': 0.95, 'cat_rideshare': 0.36,
        'cat_coffee': 0.74, 'cat_gym': 1.0, 'cat_pets': 0.22,
        'cat_subs': 0.52, 'cat_health': 0.12,
    }
    budgets = {}
    for g, f in fill.items():
        base = spent.get(g, 4000)  # a category with no spend yet: $40 base
        budgets[g] = int(round(base / f / 100 / 5) * 5) * 100 or 500
    settings = {'themeMode': 'dark', 'currencyCode': 'USD',
                'startDay': 1, 'biometricEnabled': False, 'localeCode': 'en',
                'calendar': 'gregorian'}
    prefs = {
        'onboarding_done_v1': True, 'budgetSortModeV1': 'spentDesc',
        '_budget_migrated_v3': True, 'themeMode': 'dark',
        'currency': 'USD', 'biometric': False,
        'startDay': 1, 'locale': 'en', 'calendar': 'gregorian',
        'tabUpcoming': True, 'tabDebts': True, 'tabSms': False,
        'bankNotify': False,
    }
    payload = {
        'version': 3, 'updatedAt': now.isoformat(),
        'expenses': expenses, 'categories': cat_rows(EXP_CATS),
        'settings': settings, 'budgets': budgets, 'budgetsUnit': 'USD',
        'incomeCategories': cat_rows(INC_CATS), 'incomes': incomes,
        'upcoming': upcoming, 'upcomingHistory': history,
        'debts': debts, 'debtPayments': debt_payments,
        'prefsDump': prefs,
    }
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out = a.out or os.path.join(
        root, 'build', 'us_demo_backup',
        f'OpenFinances-{today.isoformat()}-us-demo-backup.json')
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, 'w', encoding='utf-8') as fh:
        json.dump(payload, fh, ensure_ascii=False)
    print(f'{out}\n  expenses {len(expenses)}, incomes {len(incomes)}, '
          f'upcoming {len(upcoming)}, debts {len(debts)} '
          f'({len(debt_payments)} payments), {os.path.getsize(out) // 1024} KB')


if __name__ == '__main__':
    main()
