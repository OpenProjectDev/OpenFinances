"""Two demo backups for store screenshots, English (USD, Gregorian) and Persian
(toman, Jalali). All made up, and built to look good in charts: every category's
monthly total differs from the month before, there is no fixed monthly payment
to draw a row of equal bars, and the current period is nearly over with spending
on each of its last days.

    python tool/make_store_demo_backup.py [--today 2026-11-05] [--out DIR]

Take the screenshots on --today or soon after: the period's start day is set
from it. Deterministic. Prints how much each category varies, so a flat chart
shows up here first. Output defaults to build/store_demo/.

Don't restore these on a phone with real data.
"""

import argparse
import json
import os
import random
import statistics
import uuid
from datetime import date, datetime, timedelta, timezone

from make_sample_backup import g2j, generate_bank_messages, j2g, java_hash_hex  # noqa: F401

PERIODS = 14  # how far back

# (key, English, Persian, Material code point, color, dollars a month, spiky,
#  titles as (English, Persian))
CATS = [
    ('groceries', 'Groceries', 'خواربار', 0xe59c, 0xFF43A047, 330, False, [
        ('Supermarket', 'سوپرمارکت'), ('Fruit & vegetables', 'میوه و تره‌بار'),
        ('Bakery', 'نانوایی'), ('Butcher', 'قصابی'), ('Weekly shop', 'خرید هفتگی')]),
    ('dining', 'Dining out', 'رستوران', 0xe532, 0xFFE53935, 210, False, [
        ('Pizza', 'پیتزا'), ('Kebab', 'کباب'), ('Sushi', 'سوشی'),
        ('Burger night', 'شب همبرگر'), ('Noodles', 'نودل'), ('Brunch', 'صبحانه بیرون')]),
    ('coffee', 'Coffee', 'کافه', 0xe38d, 0xFF8D6E63, 58, False, [
        ('Latte', 'لاته'), ('Cold brew', 'قهوه سرد'), ('Cake & coffee', 'کیک و قهوه')]),
    ('taxi', 'Taxi', 'تاکسی', 0xe3a7, 0xFFFDD835, 96, False, [
        ('Taxi home', 'تاکسی تا خانه'), ('Airport taxi', 'تاکسی فرودگاه'), ('Taxi to work', 'تاکسی تا کار')]),
    ('gas', 'Gas', 'بنزین', 0xe394, 0xFFFB8C00, 84, False, [
        ('Gas station', 'پمپ بنزین'), ('Full tank', 'باک پر')]),
    ('bills', 'Bills', 'قبوض', 0xe0ee, 0xFF00ACC1, 150, False, [
        ('Electricity', 'قبض برق'), ('Water', 'قبض آب'), ('Heating', 'قبض گاز')]),
    ('phone', 'Phone & internet', 'موبایل و اینترنت', 0xe4aa, 0xFF1E88E5, 54, False, [
        ('Phone top-up', 'شارژ موبایل'), ('Internet', 'بسته اینترنت')]),
    ('health', 'Health', 'دارو و درمان', 0xe39e, 0xFFD81B60, 90, True, [
        ('Pharmacy', 'داروخانه'), ('Dentist', 'دندانپزشکی'),
        ('Doctor visit', 'ویزیت پزشک'), ('Glasses', 'عینک')]),
    ('clothes', 'Clothing', 'پوشاک', 0xe59a, 0xFF8E24AA, 140, True, [
        ('Sneakers', 'کفش ورزشی'), ('Jacket', 'کاپشن'),
        ('Jeans', 'شلوار جین'), ('T-shirts', 'تی‌شرت')]),
    ('fun', 'Entertainment', 'تفریح', 0xe655, 0xFFF4511E, 125, False, [
        ('Cinema', 'سینما'), ('Concert', 'کنسرت'), ('Bowling', 'بولینگ'),
        ('Board games', 'بازی فکری'), ('Theater', 'تئاتر')]),
    ('home', 'Home', 'لوازم خانه', 0xe6e1, 0xFF546E7A, 170, True, [
        ('Lamp', 'لامپ'), ('Kitchenware', 'ظروف آشپزخانه'), ('Bedding', 'ملحفه'),
        ('Plumber', 'لوله‌کش'), ('Bookshelf', 'قفسه کتاب')]),
    ('gifts', 'Gifts', 'هدیه', 0xef0f, 0xFFEC407A, 80, True, [
        ('Birthday gift', 'کادوی تولد'), ('Flowers', 'گل')]),
    ('travel', 'Travel', 'سفر', 0xe297, 0xFF039BE5, 260, True, [
        ('Flights', 'بلیت هواپیما'), ('Hotel', 'هتل'), ('Train tickets', 'بلیت قطار')]),
    ('gym', 'Fitness', 'ورزش', 0xe28d, 0xFF7CB342, 44, False, [
        ('Gym', 'باشگاه'), ('Swimming', 'استخر')]),
    ('edu', 'Education', 'آموزش', 0xe559, 0xFF5E35B1, 62, True, [
        ('Book', 'کتاب'), ('Language class', 'کلاس زبان'), ('Online course', 'دوره آنلاین')]),
    ('general', 'General', 'عمومی', 0xe148, 0xFF607D8B, 30, False, [
        ('Bank fee', 'کارمزد بانکی'), ('Parking', 'پارکینگ'), ('Car wash', 'کارواش')]),
]
INCOME_CATS = [
    ('salary', 'Salary', 'حقوق', 0xe6f4, 0xFF2E7D32),
    ('freelance', 'Freelance', 'پروژه آزاد', 0xe369, 0xFF1565C0),
    ('bonus', 'Bonus', 'پاداش', 0xf24e, 0xFFF9A825),
    ('sales', 'Selling things', 'فروش وسایل', 0xe60c, 0xFF6A1B9A),
    ('general', 'General', 'عمومی', 0xe148, 0xFF607D8B),
]
NOTES = [('With friends', 'با دوستان'), ('With family', 'با خانواده'),
         ('On sale', 'حراجی'), ('Long overdue', 'خیلی وقت بود لازم داشتم')]

# How big each period is against the usual, newest last: the all-periods chart.
# Current against the one before and the average gives a saving on one chip and
# a rise on the other.
SHAPE = [0.92, 1.18, 0.74, 1.05, 1.34, 0.86, 1.22, 0.68, 1.12, 0.95, 1.38, 0.82, 1.30, 1.08]

# The current period's categories, by how much, so the ring has big, middle and
# small slices. Off the list: nothing this period.
NOW_SHARE = {
    'groceries': 1.05, 'dining': 1.25, 'travel': 1.55, 'clothes': 1.1, 'home': 0.8,
    'fun': 1.0, 'bills': 0.85, 'taxi': 0.9, 'coffee': 1.0, 'health': 0.55, 'gifts': 0.5,
}
# Budget against this period's spending: low, middle, nearly full and two over.
FILL = {
    'groceries': 0.86, 'dining': 1.14, 'travel': 0.62, 'clothes': 0.45, 'home': 0.34,
    'fun': 0.73, 'bills': 0.94, 'taxi': 1.27, 'coffee': 0.58, 'health': 0.21, 'gifts': 0.39,
}
# The last days, newest first, in dollars: the daily chart opens here, so peaks
# and dips, each at a believable price.
RECENT = [
    [('groceries', 0, 64), ('coffee', 0, 6.4)], [('dining', 2, 61), ('taxi', 0, 23)], [('coffee', 1, 11.3)],
    [('clothes', 0, 148), ('dining', 0, 38)], [('groceries', 3, 96), ('taxi', 2, 18)], [('fun', 0, 42)],
    [('home', 1, 120), ('groceries', 1, 44), ('coffee', 2, 7.2)], [('bills', 0, 58)],
]
# The biggest day of the last two periods, in dollars.
DAY_PEAK = 200
# What one purchase can cost, in dollars.
PRICES = {
    'groceries': (9, 120), 'dining': (14, 85), 'coffee': (3.5, 14), 'taxi': (6, 48), 'gas': (22, 68),
    'bills': (18, 120), 'phone': (10, 60), 'health': (12, 260), 'clothes': (25, 190), 'fun': (12, 95),
    'home': (15, 320), 'gifts': (20, 160), 'travel': (60, 620), 'gym': (15, 60), 'edu': (15, 180),
    'general': (3, 45),
}


class Locale:
    def __init__(self, code, today):
        self.fa = code == 'fa'
        self.code = code
        self.tz = timezone(timedelta(hours=3, minutes=30) if self.fa else timedelta(hours=-5))
        self.today = today
        self.now = datetime(today.year, today.month, today.day, 19, 0, tzinfo=self.tz)
        self.currency = 'IRT' if self.fa else 'USD'
        self.rng = random.Random(1405 if self.fa else 2026)
        # Today sits three days before the period ends.
        day = g2j(today)[2] if self.fa else today.day
        self.start_day = min(day + 3, 28)

    def pick(self, pair):
        return pair[1] if self.fa else pair[0]

    def minor(self, dollars):
        """Dollars of the scenario in this locale's minor units, looking typed."""
        if self.fa:
            v = dollars * 30000
            step = 5000 if v < 1e6 else 50000
            return max(step, int(round(v / step)) * step) * 100
        if dollars >= 100:
            return int(round(dollars)) * 100
        return int(round(dollars * 100))

    def period_start(self, back):
        """The first day of the period `back` before the current one."""
        if self.fa:
            jy, jm, jd = g2j(self.today)
            months = jy * 12 + jm - 1 - back - (1 if jd < self.start_day else 0)
            return j2g(months // 12, months % 12 + 1, self.start_day)
        months = self.today.year * 12 + self.today.month - 1 - back
        if self.today.day < self.start_day:
            months -= 1
        return date(months // 12, months % 12 + 1, self.start_day)

    def days(self, back):
        first, next_first = self.period_start(back), self.period_start(back - 1)
        return [first + timedelta(days=i) for i in range((next_first - first).days)]

    def gid(self):
        return str(uuid.UUID(int=self.rng.getrandbits(128), version=4))

    def at(self, d, hour):
        return datetime(d.year, d.month, d.day, hour, self.rng.randint(0, 59), tzinfo=self.tz)


def iso_utc(dt):
    u = dt.astimezone(timezone.utc)
    return u.strftime('%Y-%m-%dT%H:%M:%S.') + f'{u.microsecond // 1000:03d}Z'


def cat_rows(lo, cats, prefix):
    first = lo.period_start(PERIODS)
    created = iso_utc(lo.at(first, 9) - timedelta(days=3))
    return [{
        'gid': prefix + c[0], 'name': c[2] if lo.fa else c[1], 'sort': i,
        'createdAtUtc': created, 'updatedAtUtc': created, 'isDeleted': False, 'isDirty': True,
        'iconCodePoint': c[3], 'iconFontFamily': 'MaterialIcons', 'color': c[4],
    } for i, c in enumerate(cats)]


def entry(lo, when, title, amount, cat, note=None):
    created = min(when + timedelta(minutes=lo.rng.randint(1, 90)), lo.now)
    return {
        'gid': lo.gid(), 'title': title, 'amountMinor': amount, 'currency': lo.currency,
        'occurredAtUtc': iso_utc(when), 'note': note, 'categoryGid': cat, 'accountGid': None,
        'version': 1, 'createdAtUtc': iso_utc(created), 'updatedAtUtc': iso_utc(created),
        'isDeleted': False, 'isDirty': True,
    }


def monthly_targets(lo):
    """Dollars per period (oldest first) per category, no two neighbors alike."""
    out = {}
    for c in CATS:
        key, base, spiky = c[0], c[5], c[6]
        row, last = [], None
        for back in range(PERIODS - 1, 0, -1):
            shape = SHAPE[PERIODS - 1 - back]
            while True:
                f = lo.rng.uniform(0.15, 2.3) if spiky else lo.rng.uniform(0.55, 1.6)
                v = base * shape * f
                if last is None or not 0.75 < v / last < 1.33:
                    break
            row.append(v)
            last = v
        # The current period: its full size; only the days so far get spent.
        row.append(base * SHAPE[-1] * NOW_SHARE.get(key, 0))
        out[key] = row
    return out


def split(rng, total, n):
    weights = [rng.gammavariate(1.1, 1) + 0.15 for _ in range(n)]
    s = sum(weights)
    return [total * w / s for w in weights]


def expenses(lo):
    out = []
    targets = monthly_targets(lo)
    by_key = {c[0]: c for c in CATS}
    recent_days = {lo.today - timedelta(days=i) for i in range(len(RECENT))}
    planned = {0: [], 1: []}
    for back in range(PERIODS - 1, -1, -1):
        days = [d for d in lo.days(back) if d <= lo.today]
        whole = len(lo.days(back))
        for c in CATS:
            key, spiky, titles = c[0], c[6], c[7]
            total = targets[key][PERIODS - 1 - back] * len(days) / whole
            if total <= 0:
                continue
            low, high = PRICES[key]
            if back < 2:  # no single day may dwarf the rest of the heatmap
                high = min(high, DAY_PEAK - 25)
            ticket = min(sum(PRICES[key]) / 2.4, high * 0.7)
            n = max(1, round(total / ticket))
            pool = [d for d in days if back or d not in recent_days]
            for amount in split(lo.rng, total, n):
                note = lo.pick(lo.rng.choice(NOTES)) if lo.rng.random() < 0.13 else None
                row = (lo.pick(lo.rng.choice(titles)), min(max(amount, low), high), key, note)
                if back < 2:
                    planned[back].append(row)
                    continue
                d = lo.rng.choice(pool)
                if d.weekday() in (0, 1, 2) and lo.rng.random() < 0.4:  # busier weekends
                    d = lo.rng.choice(pool)
                out.append(entry(lo, lo.at(d, lo.rng.randint(8, 22)), row[0],
                                 lo.minor(row[1]), 'cat_' + key, note))
    # The heatmap shades a day by its share of the biggest one, and the daily
    # chart scales to it. So these two periods fill days toward a planned spread
    # instead of landing at random, the biggest purchases first.
    for back, rows in planned.items():
        days = [d for d in lo.days(back) if d <= lo.today and (back or d not in recent_days)]
        room = [DAY_PEAK * (0.14 + 0.8 * i / max(1, len(days) - 1)) for i in range(len(days))]
        lo.rng.shuffle(room)
        room = dict(zip(days, room))
        for title, amount, key, note in sorted(rows, key=lambda r: -r[1]):
            d = max(room, key=room.get)
            room[d] -= amount
            out.append(entry(lo, lo.at(d, lo.rng.randint(8, 22)), title, lo.minor(amount), 'cat_' + key, note))
    # The last days, by hand: never empty, and far apart.
    for i, day in enumerate(RECENT):
        d = lo.today - timedelta(days=i)
        for j, (key, title, dollars) in enumerate(day):
            c = by_key[key]
            hour = 8 + (j * 5 + i) % 11
            if d == lo.today:
                hour = min(hour, 17)
            out.append(entry(lo, lo.at(d, hour), lo.pick(c[7][title % len(c[7])]),
                             lo.minor(dollars), 'cat_' + key))
    # The period before never has a long gap, so comparing lines keep going.
    seen = {e['occurredAtUtc'][:10] for e in out}
    for d in lo.days(1):
        if d.isoformat() not in seen and lo.rng.random() < 0.8:
            out.append(entry(lo, lo.at(d, 12), lo.pick(by_key['coffee'][7][0]),
                             lo.minor(lo.rng.uniform(4, 13)), 'cat_coffee'))
    return [e for e in out if e['occurredAtUtc'] <= iso_utc(lo.now)]


def incomes(lo):
    out = []
    for back in range(PERIODS - 1, -1, -1):
        days = [d for d in lo.days(back) if d <= lo.today]
        out.append(entry(lo, lo.at(days[min(2, len(days) - 1)], 9),
                         lo.pick(('Paycheck', 'حقوق ماهانه')),
                         lo.minor(lo.rng.uniform(1900, 2500)), 'inccat_salary'))
        if lo.rng.random() < 0.7 or back == 0:
            out.append(entry(lo, lo.at(lo.rng.choice(days), 15),
                             lo.pick(lo.rng.choice([('Logo design', 'طراحی لوگو'), ('Translation job', 'پروژه ترجمه'),
                                                    ('Website fix', 'اصلاح سایت'), ('Consulting call', 'مشاوره')])),
                             lo.minor(lo.rng.uniform(120, 880)), 'inccat_freelance'))
        if lo.rng.random() < 0.18:
            out.append(entry(lo, lo.at(lo.rng.choice(days), 11), lo.pick(('Performance bonus', 'پاداش عملکرد')),
                             lo.minor(lo.rng.uniform(400, 1300)), 'inccat_bonus'))
        if lo.rng.random() < 0.14:
            out.append(entry(lo, lo.at(lo.rng.choice(days), 17),
                             lo.pick(lo.rng.choice([('Sold old phone', 'فروش گوشی قدیمی'), ('Sold bike', 'فروش دوچرخه')])),
                             lo.minor(lo.rng.uniform(60, 320)), 'inccat_sales'))
    return [e for e in out if e['occurredAtUtc'] <= iso_utc(lo.now)]


def upcoming(lo):
    items = [  # days from today, title, dollars, category, note, paid days ago
        (-3, ('Credit card', 'قسط کارت اعتباری'), 215.4, 'general', None, None),
        (0, ('Electricity', 'قبض برق'), 62.3, 'bills', None, None),
        (2, ('Car insurance', 'بیمه ماشین'), 138, 'general', None, None),
        (6, ('Gym renewal', 'تمدید باشگاه'), 39.9, 'gym', None, None),
        (11, ('Language class', 'شهریه کلاس زبان'), 128, 'edu', ('Autumn term', 'ترم پاییز'), None),
        (17, ("Mom's birthday", 'تولد مامان'), 60, 'gifts', None, None),
        (29, ('Dentist check-up', 'معاینه دندانپزشکی'), 95, 'health', None, None),
        (54, ('Winter flights', 'بلیت سفر زمستانی'), 420, 'travel', None, None),
        (-9, ('Internet', 'بسته اینترنت'), 44.5, 'phone', None, 8),
        (-16, ('Water', 'قبض آب'), 23.8, 'bills', None, 15),
    ]
    out = []
    for days, title, dollars, cat, note, paid in items:
        due = datetime.combine(lo.today + timedelta(days=days), datetime.min.time(), tzinfo=lo.tz)
        created = lo.now - timedelta(days=lo.rng.randint(20, 40))
        row = {
            'gid': lo.gid(), 'title': lo.pick(title), 'amountMinor': lo.minor(dollars),
            'currency': lo.currency, 'dueAtUtc': iso_utc(due), 'note': lo.pick(note) if note else None,
            'categoryGid': 'cat_' + cat, 'version': 1,
            'createdAtUtc': iso_utc(created), 'updatedAtUtc': iso_utc(created),
        }
        if paid:
            row['paidAtUtc'] = iso_utc(lo.now - timedelta(days=paid))
        out.append(row)
    history = [{'title': u['title'], 'amountMinor': u['amountMinor'], 'categoryGid': u['categoryGid'],
                'lastUsedAtUtc': iso_utc(lo.now - timedelta(days=i * 2 + 1))} for i, u in enumerate(out)]
    return out, history


def debts(lo):
    rows, pays = [], []

    def debt(direction, person, title, dollars, started, due_in=None, note=None, paid=()):
        g = lo.gid()
        when = lo.now - timedelta(days=started)
        rows.append({
            'gid': g, 'direction': direction, 'person': lo.pick(person), 'title': lo.pick(title),
            'amountMinor': lo.minor(dollars), 'currency': lo.currency, 'startedAtUtc': iso_utc(when),
            'dueAtUtc': None if due_in is None else iso_utc(datetime.combine(
                lo.today + timedelta(days=due_in), datetime.min.time(), tzinfo=lo.tz)),
            'note': lo.pick(note) if note else None, 'version': 1,
            'createdAtUtc': iso_utc(when), 'updatedAtUtc': iso_utc(when),
        })
        for days_ago, p in paid:
            at = lo.now - timedelta(days=days_ago)
            pays.append({
                'gid': lo.gid(), 'debtGid': g, 'amountMinor': lo.minor(p), 'currency': lo.currency,
                'paidAtUtc': iso_utc(at), 'version': 1,
                'createdAtUtc': iso_utc(at), 'updatedAtUtc': iso_utc(at),
            })

    debt('owe', ('Dad', 'بابا'), ('Car down payment', 'پیش‌پرداخت ماشین'), 3000, 160,
         note=('No rush', 'بدون عجله'), paid=[(120, 500), (70, 650), (25, 400)])
    debt('owe', ('Jordan', 'علی'), ('Laptop repair', 'تعمیر لپ‌تاپ'), 400, 20, due_in=9)
    debt('owe', ('Mom', 'مامان'), ('Phone repair', 'تعمیر گوشی'), 180, 12, paid=[(5, 60)])
    debt('owed', ('Sam', 'سارا'), ('Concert tickets', 'بلیت کنسرت'), 160, 18)
    debt('owed', ('Riley', 'رضا'), ('Laptop loan', 'قرض برای لپ‌تاپ'), 900, 70, due_in=21, paid=[(35, 300)])
    debt('owed', ('Taylor', 'مریم'), ('Group dinner', 'شام گروهی'), 48, 3)
    debt('owed', ('Casey', 'امیر'), ('Trip share', 'سهم سفر'), 240, 50, paid=[(15, 240)])
    return rows, pays


def budgets(lo, rows):
    first = iso_utc(datetime.combine(lo.period_start(0), datetime.min.time(), tzinfo=lo.tz))
    spent = {}
    for e in rows:
        if e['occurredAtUtc'] >= first:
            spent[e['categoryGid']] = spent.get(e['categoryGid'], 0) + e['amountMinor']
    out = {}
    step = (100000 if lo.fa else 5) * 100
    for key, fill in FILL.items():
        g = 'cat_' + key
        whole = spent.get(g, step * 4) / fill
        out[g] = max(step, int(round(whole / step)) * step)
    return out


def report(lo, rows):
    """How much each category moves from period to period."""
    edges = [iso_utc(datetime.combine(lo.period_start(b), datetime.min.time(), tzinfo=lo.tz))
             for b in range(PERIODS - 1, -2, -1)]
    totals, flat = {}, []
    unit = 30000 * 100 if lo.fa else 100
    for key in [c[0] for c in CATS]:
        g = 'cat_' + key
        row = []
        for a, b in zip(edges, edges[1:]):
            row.append(sum(e['amountMinor'] for e in rows
                           if e['categoryGid'] == g and a <= e['occurredAtUtc'] < b) / unit)
        totals[key] = row
        past = row[:-1]
        close = sum(1 for x, y in zip(past, past[1:]) if x and y and 0.9 < x / y < 1.1)
        if close > 2:
            flat.append(key)
    period = [sum(totals[k][i] for k in totals) for i in range(PERIODS)]
    print('  all periods, dollars-equivalent: ' + ' '.join(f'{v:.0f}' for v in period))
    print(f'  largest / smallest whole period: {max(period[:-1]) / min(period[:-1]):.2f}; '
          f'current so far against the one before: {period[-1] / period[-2]:.2f}, '
          f'against the average: {period[-1] / statistics.mean(period[:-1]):.2f}')
    print('  categories with near-flat neighbors: ' + (', '.join(flat) or 'none'))
    return not flat


def build(code, today, outdir):
    lo = Locale(code, today)
    exp = sorted(expenses(lo), key=lambda e: e['occurredAtUtc'])
    inc = sorted(incomes(lo), key=lambda e: e['occurredAtUtc'])
    up, history = upcoming(lo)
    deb, pays = debts(lo)
    kinds = ['categoryChips', 'ignoredChips', 'dayPreview', 'suggestions', 'chipsRow', 'colorRow', 'menu',
             'periodChart', 'dailyChart', 'changeLog', 'datePicker', 'datePickerYears', 'calendarWeeks']
    calendar = 'jalali' if lo.fa else 'gregorian'
    settings = {'themeMode': 'dark', 'currencyCode': lo.currency, 'startDay': lo.start_day,
                'biometricEnabled': False, 'localeCode': code, 'calendar': calendar}
    prefs = {
        'onboarding_done_v1': True, 'budgetSortModeV1': 'spentDesc', '_budget_migrated_v3': True,
        'themeMode': 'dark', 'currency': lo.currency, 'biometric': False, 'startDay': lo.start_day,
        'locale': code, 'calendar': calendar, 'tabUpcoming': True, 'tabDebts': True,
        'tabSms': lo.fa, 'bankNotify': lo.fa, 'tipsOn': False, 'suggestionsOn': True,
        'scrollLearnedV1': kinds,
    }
    payload = {
        'version': 3, 'updatedAt': lo.now.isoformat(), 'expenses': exp,
        'categories': cat_rows(lo, CATS, 'cat_'), 'settings': settings,
        'budgets': budgets(lo, exp), 'budgetsUnit': lo.currency,
        'incomeCategories': cat_rows(lo, INCOME_CATS, 'inccat_'), 'incomes': inc,
        'upcoming': up, 'upcomingHistory': history, 'debts': deb, 'debtPayments': pays,
        'prefsDump': prefs,
    }
    if lo.fa:
        payload['bankData'] = generate_bank_messages(lo.now)
    path = os.path.join(outdir, f'OpenFinances-demo-{code}.json')
    with open(path, 'w', encoding='utf-8') as fh:
        json.dump(payload, fh, ensure_ascii=False)
    print(f'{path}\n  expenses {len(exp)}, incomes {len(inc)}, upcoming {len(up)}, debts {len(deb)}, '
          f'start day {lo.start_day}, {os.path.getsize(path) // 1024} KB')
    return report(lo, exp)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--today', default=date.today().isoformat())
    ap.add_argument('--out')
    a = ap.parse_args()
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out = a.out or os.path.join(root, 'build', 'store_demo')
    os.makedirs(out, exist_ok=True)
    ok = [build(code, date.fromisoformat(a.today), out) for code in ('en', 'fa')]
    if not all(ok):
        print('Some category is near flat: look at it before taking screenshots')


if __name__ == '__main__':
    main()
