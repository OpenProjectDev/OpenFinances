"""Generates a realistic multi-year OpenFinances backup (JSON, format v3) for
restore testing: Persian category names, toman (IRT), Jalali-month rhythms
(rent and salary on the 1st, Nowruz spending, yearly raises), inflation,
incomes, budgets, upcoming payments (overdue / today / future) with title
history, debts both ways (titles, partial payments, a settled one, one
recorded in rial), captured bank messages in several banks' formats
(Persian/English, rial/toman, signed), settings and a typed prefs dump
(all home tabs on, a few ignored suggestions).

    python tool/make_sample_backup.py [--today 2026-10-18] [--out PATH]

Deterministic (fixed seed). Output defaults to build/sample_backup/.
"""

import argparse
import json
import os
import random
import uuid
from datetime import date, datetime, timedelta, timezone

LOCAL_TZ = timezone(timedelta(hours=3, minutes=30))
RNG = random.Random(1402)


# ---------------------------------------------------------------- Jalali
def j2g(jy, jm, jd):
    """Jalali -> Gregorian (jdf algorithm)."""
    jy += 1595
    days = -355668 + 365 * jy + (jy // 33) * 8 + ((jy % 33) + 3) // 4 + jd
    days += (jm - 1) * 31 if jm < 7 else (jm - 7) * 30 + 186
    gy = 400 * (days // 146097)
    days %= 146097
    if days > 36524:
        days -= 1
        gy += 100 * (days // 36524)
        days %= 36524
        if days >= 365:
            days += 1
    gy += 4 * (days // 1461)
    days %= 1461
    if days > 365:
        gy += (days - 1) // 365
        days = (days - 1) % 365
    gd = days + 1
    leap = (gy % 4 == 0 and gy % 100 != 0) or gy % 400 == 0
    months = [0, 31, 29 if leap else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    gm = 1
    while gm <= 12 and gd > months[gm]:
        gd -= months[gm]
        gm += 1
    return date(gy, gm, gd)


def g2j(d):
    """Gregorian -> (jy, jm, jd) by scanning from a nearby Nowruz."""
    jy = d.year - 621
    if d < j2g(jy, 1, 1):
        jy -= 1
    start = j2g(jy, 1, 1)
    n = (d - start).days
    if n < 186:
        return jy, n // 31 + 1, n % 31 + 1
    n -= 186
    return jy, n // 30 + 7, n % 30 + 1


assert j2g(1402, 1, 1) == date(2023, 3, 21)
assert g2j(date(2026, 10, 18)) == (1405, 7, 26)


# ---------------------------------------------------------------- helpers
def gid():
    return str(uuid.UUID(int=RNG.getrandbits(128), version=4))


def iso_utc(dt):
    u = dt.astimezone(timezone.utc)
    return u.strftime('%Y-%m-%dT%H:%M:%S.') + f'{u.microsecond // 1000:03d}Z'


def at(d, hour, minute=None):
    return datetime(d.year, d.month, d.day, hour,
                    RNG.randint(0, 59) if minute is None else minute,
                    tzinfo=LOCAL_TZ)


def toman(lo, hi, f=1.0, step=1000):
    """Random toman amount in [lo, hi] * inflation, rounded, as minor units."""
    v = RNG.uniform(lo, hi) * f
    v = max(step, round(v / step) * step)
    return int(v) * 100


START = date(2023, 3, 21)  # 1402/01/01


def inflation(d):
    return 1.38 ** ((d - START).days / 365.25)


# ---------------------------------------------------------------- categories
# (gid, name, Material code point, ARGB color). Code points must be in the
# app's kCategoryIcons list, otherwise the icon falls back to "category".
EXP_CATS = [
    ('cat_groceries', 'خواربار', 0xe59c, 0xFF43A047),
    ('cat_restaurant', 'رستوران', 0xe532, 0xFFE53935),
    ('cat_cafe', 'کافه', 0xe38d, 0xFF8D6E63),
    ('cat_taxi', 'تاکسی اینترنتی', 0xe3a7, 0xFFFDD835),
    ('cat_fuel', 'بنزین', 0xe394, 0xFFFB8C00),
    ('cat_transit', 'مترو و اتوبوس', 0xe1d5, 0xFF00897B),
    ('cat_rent', 'اجاره خانه', 0xf107, 0xFF5E35B1),
    ('cat_bills', 'قبوض', 0xe0ee, 0xFFFFB300),
    ('cat_mobile', 'موبایل و اینترنت', 0xe4aa, 0xFF1E88E5),
    ('cat_health', 'دارو و درمان', 0xe39e, 0xFFD81B60),
    ('cat_clothes', 'پوشاک', 0xe59a, 0xFF8E24AA),
    ('cat_fun', 'تفریح', 0xe655, 0xFFF4511E),
    ('cat_subs', 'اشتراک‌ها', 0xf1f5, 0xFF3949AB),
    ('cat_edu', 'آموزش', 0xe559, 0xFF00ACC1),
    ('cat_gifts', 'هدیه و مناسبت', 0xef0f, 0xFFEC407A),
    ('cat_gym', 'ورزش', 0xe28d, 0xFF7CB342),
    ('cat_pets', 'حیوان خانگی', 0xe4a1, 0xFF6D4C41),
    ('cat_home', 'لوازم خانه', 0xe6e1, 0xFF546E7A),
    ('cat_travel', 'سفر', 0xe297, 0xFF039BE5),
    ('cat_care', 'آرایشی و بهداشتی', 0xef02, 0xFFAB47BC),
    ('cat_general', 'عمومی', 0xe148, 0xFF607D8B),  # the app's seed gid
]
INC_CATS = [
    ('inccat_salary', 'حقوق', 0xe6f4, 0xFF2E7D32),
    ('inccat_freelance', 'پروژه آزاد', 0xe369, 0xFF1565C0),
    ('inccat_interest', 'سود بانکی', 0xf336, 0xFF00838F),
    ('inccat_bonus', 'پاداش و عیدی', 0xf24e, 0xFFF9A825),
    ('inccat_gift', 'هدیه', 0xe25c, 0xFFAD1457),
    ('inccat_sales', 'فروش وسایل', 0xe60c, 0xFF6A1B9A),
    ('inccat_general', 'عمومی', 0xe148, 0xFF607D8B),  # the app's seed gid
]


def cat_rows(cats):
    created = iso_utc(at(START, 9, 0) - timedelta(days=3))
    return [{
        'gid': g, 'name': n, 'sort': i,
        'createdAtUtc': created, 'updatedAtUtc': created,
        'isDeleted': False, 'isDirty': True,
        'iconCodePoint': cp, 'iconFontFamily': 'MaterialIcons', 'color': c,
    } for i, (g, n, cp, c) in enumerate(cats)]


# ---------------------------------------------------------------- entries
def entry(when, title, amount, cat, note=None, now=None):
    created = when + timedelta(minutes=RNG.randint(1, 240))
    if now and created > now:
        created = now
    return {
        'gid': gid(), 'title': title, 'amountMinor': amount,
        'currency': 'IRT', 'occurredAtUtc': iso_utc(when), 'note': note,
        'categoryGid': cat, 'accountGid': None, 'version': 1,
        'createdAtUtc': iso_utc(created), 'updatedAtUtc': iso_utc(created),
        'isDeleted': False, 'isDirty': True,
    }


def maybe_note(options, p=0.15):
    return RNG.choice(options) if RNG.random() < p else None


FRIENDS = ['با علی', 'با مریم', 'با بچه‌های دانشگاه', 'با خانواده', 'با سارا و رضا']


def generate_expenses(today, now):
    out = []
    d = START
    while d <= today:
        jy, jm, jd = g2j(d)
        f = inflation(d)
        wd = d.weekday()  # Mon=0 ... Fri=4 (Iranian weekend)
        def add(when, *a, **k):
            if when <= now:  # nothing later than the backup's own time
                out.append(entry(when, *a, now=now, **k))

        # --- monthly, on Jalali dates
        if jd == 1:
            add(at(d, 10), 'اجاره ماهانه', toman(9e6, 9e6, f, 100000), 'cat_rent',
                maybe_note(['واریز به حساب صاحبخانه'], 0.3))
        if jd == 3:
            add(at(d, 18), 'شهریه باشگاه', toman(6e5, 7e5, f, 10000), 'cat_gym')
            add(at(d, 21), 'اشتراک فیلیمو', toman(9e4, 9e4, f, 1000), 'cat_subs')
        if jd == 5:
            add(at(d, 12), 'شارژ ساختمان', toman(4e5, 6e5, f, 10000), 'cat_bills')
            add(at(d, 22), 'بسته اینترنت ماهانه', toman(1.5e5, 2.5e5, f), 'cat_mobile')
        if jd == 12:
            add(at(d, 9), 'قبض برق', toman(1.2e5, 3.5e5 if jm in (4, 5, 6) else 1.8e5, f),
                'cat_bills')
        if jd == 15:
            winter = jm in (9, 10, 11, 12)
            add(at(d, 9), 'قبض گاز', toman(3e5 if winter else 4e4, 9e5 if winter else 1e5, f),
                'cat_bills', maybe_note(['زمستون سرد بود'], 0.2 if winter else 0))
            add(at(d, 20), 'غذای گربه', toman(3e5, 6e5, f), 'cat_pets')
        if jd == 20:
            add(at(d, 9), 'قبض آب', toman(5e4, 1.2e5, f), 'cat_bills')
            add(at(d, 13), 'شارژ همراه اول', toman(1e5, 2e5, f), 'cat_mobile')
        if jd == 25 and jm % 2 == 0:
            add(at(d, 19), 'اشتراک اسپاتیفای', toman(1.6e5, 1.6e5, f, 1000), 'cat_subs')

        # --- weekly-ish
        if RNG.random() < 0.3:
            add(at(d, RNG.randint(8, 21)),
                RNG.choice(['سوپرمارکت', 'میوه و تره‌بار', 'لبنیات', 'قصابی',
                            'خرید هفتگی هایپراستار', 'مرغ و ماهی']),
                toman(1.5e5, 1.1e6, f), 'cat_groceries')
        if RNG.random() < 0.5:
            add(at(d, RNG.choice([7, 8, 18, 19])), 'نانوایی', toman(1.5e4, 6e4, f),
                'cat_groceries')
        if RNG.random() < (0.15 if wd in (3, 4) else 0.04):
            add(at(d, RNG.choice([13, 14, 20, 21, 22])),
                RNG.choice(['پیتزا', 'کباب', 'فست‌فود', 'رستوران سنتی',
                            'سفارش از اسنپ‌فود', 'سوشی']),
                toman(3e5, 1.2e6, f), 'cat_restaurant', maybe_note(FRIENDS, 0.35))
        if RNG.random() < 0.15:
            add(at(d, RNG.randint(10, 22)),
                RNG.choice(['قهوه', 'کافه با دوستان', 'کیک و قهوه', 'آیس‌لته']),
                toman(8e4, 4.5e5, f), 'cat_cafe', maybe_note(FRIENDS, 0.2))
        if RNG.random() < 0.45 and wd != 4:
            add(at(d, RNG.randint(7, 23)), RNG.choice(['اسنپ', 'تپسی', 'اسنپ', 'تاکسی']),
                toman(4e4, 3.5e5, f), 'cat_taxi')
        if RNG.random() < 0.14:
            add(at(d, RNG.randint(8, 20)), 'بنزین', toman(4e4, 1.6e5, f), 'cat_fuel')
        if RNG.random() < 0.06:
            add(at(d, 8), 'شارژ کارت مترو', toman(5e4, 2e5, f), 'cat_transit')

        # --- occasional
        if RNG.random() < 0.025:
            add(at(d, RNG.randint(9, 20)),
                RNG.choice(['داروخانه', 'ویزیت پزشک', 'آزمایش خون', 'دندانپزشکی',
                            'عینک']),
                toman(1.5e5, 1.5e6, f), 'cat_health',
                maybe_note(['بیمه نصفش رو داد', 'سرماخوردگی'], 0.3))
        if RNG.random() < (0.12 if jm == 12 else 0.03):
            add(at(d, RNG.randint(11, 21)),
                RNG.choice(['کفش', 'پیراهن', 'کاپشن', 'شلوار جین', 'تی‌شرت']),
                toman(6e5, 2.5e6, f), 'cat_clothes',
                'خرید عید' if jm == 12 and RNG.random() < 0.5 else None)
        if RNG.random() < 0.05:
            add(at(d, RNG.randint(16, 23)),
                RNG.choice(['سینما', 'کنسرت', 'بولینگ', 'شهربازی', 'تئاتر', 'اتاق فرار']),
                toman(2e5, 1.2e6, f), 'cat_fun', maybe_note(FRIENDS, 0.4))
        if RNG.random() < 0.025:
            add(at(d, RNG.randint(10, 20)),
                RNG.choice(['کتاب', 'دوره آنلاین', 'کلاس زبان', 'لوازم‌التحریر']),
                toman(2e5, 2e6, f), 'cat_edu')
        if RNG.random() < 0.015:
            add(at(d, RNG.randint(10, 21)),
                RNG.choice(['ظروف آشپزخانه', 'لامپ', 'ملحفه', 'جاروبرقی', 'قفسه کتاب']),
                toman(2e5, 3e6, f), 'cat_home')
        if RNG.random() < 0.03:
            add(at(d, RNG.randint(10, 21)),
                RNG.choice(['شامپو و صابون', 'آرایشگاه', 'عطر', 'کرم ضدآفتاب']),
                toman(1e5, 1.8e6, f), 'cat_care')
        if RNG.random() < 0.012:
            add(at(d, RNG.randint(10, 20)), 'دامپزشک', toman(5e5, 2.5e6, f), 'cat_pets')
        if RNG.random() < 0.01:
            add(at(d, RNG.randint(9, 18)),
                RNG.choice(['کارمزد بانکی', 'متفرقه', 'جریمه رانندگی', 'تعمیر ماشین']),
                toman(5e4, 1.2e7, f), 'cat_general')

        # --- yearly rhythms
        if jm == 12 and jd in (20, 25):
            add(at(d, 17), 'هدیه عید', toman(5e5, 2e6, f), 'cat_gifts', 'برای بچه‌های فامیل')
        if jm == 1 and jd == 2:
            add(at(d, 11), 'عیدی بچه‌ها', toman(1e6, 3e6, f), 'cat_gifts')
        if (jm, jd) in ((3, 14), (8, 9), (11, 22)):
            add(at(d, 19), RNG.choice(['کادوی تولد', 'گل و کیک تولد']),
                toman(8e5, 3e6, f), 'cat_gifts',
                {(3, 14): 'تولد مریم', (8, 9): 'تولد مامان', (11, 22): 'تولد علی'}[(jm, jd)])
        if (jm, jd) in ((1, 5), (5, 10)):  # two trips a year
            add(at(d, 9), 'بلیت هواپیما', toman(3e6, 6e6, f), 'cat_travel',
                'مشهد' if jm == 1 else 'کیش')
            add(at(d + timedelta(days=1), 14), 'هتل', toman(4e6, 9e6, f), 'cat_travel')
            add(at(d + timedelta(days=2), 21), 'شام سفر', toman(8e5, 2e6, f), 'cat_restaurant')
        d += timedelta(days=1)

    # a couple of entries without category / with long text (UI edge cases)
    mid = START + timedelta(days=400)
    out.append(entry(at(mid, 15), 'پرداخت بدون دسته‌بندی', toman(2.5e5, 2.5e5), None, now=now))
    out.append(entry(at(mid + timedelta(days=200), 16),
                     'خرید خیلی طولانی برای تست نمایش عنوان‌های بلند در فهرست هزینه‌ها',
                     toman(3.3e5, 3.3e5, inflation(mid)), 'cat_home',
                     'یادداشت بلند: این ردیف فقط برای بررسی شکستن خط و نمایش یادداشت در صفحه '
                     'جزئیات و ویرایش است.', now=now))
    return out


def generate_incomes(today, now):
    out = []
    salary = 2.6e7
    d = START
    while d <= today:
        jy, jm, jd = g2j(d)
        f = inflation(d)
        def add(when, *a, **k):
            if when <= now:
                out.append(entry(when, *a, now=now, **k))

        if jm == 1 and jd == 1 and d != START:
            salary *= RNG.uniform(1.3, 1.42)  # yearly raise
        if jd == 1:
            add(at(d, 9), 'حقوق ماهانه', int(round(salary / 1e5) * 1e5) * 100, 'inccat_salary')
        if jd == 28:
            add(at(d, 8), 'سود سپرده', toman(3e5, 9e5, f, 1000), 'inccat_interest')
        if jm == 12 and jd == 20:
            add(at(d, 10), 'عیدی شرکت', int(round(salary / 1e5) * 1e5) * 100, 'inccat_bonus')
        if (jm, jd) in ((6, 30), (12, 25)):
            add(at(d, 11), 'پاداش عملکرد', toman(5e6, 1.5e7, f, 100000), 'inccat_bonus')
        if RNG.random() < 0.016:
            add(at(d, RNG.randint(10, 20)),
                RNG.choice(['پروژه طراحی سایت', 'ترجمه مقاله', 'مشاوره', 'اپلیکیشن فروشگاهی']),
                toman(4e6, 3e7, f, 100000), 'inccat_freelance',
                maybe_note(['نصف پیش‌پرداخت', 'تسویه کامل'], 0.4))
        if jm == 1 and jd == 3:
            add(at(d, 13), 'عیدی از پدربزرگ', toman(1e6, 3e6, f, 100000), 'inccat_gift')
        if RNG.random() < 0.003:
            add(at(d, 17), RNG.choice(['فروش گوشی قدیمی', 'فروش دوچرخه', 'فروش کتاب‌ها']),
                toman(1e6, 1.2e7, f, 100000), 'inccat_sales')
        if RNG.random() < 0.004:
            add(at(d, 12), 'متفرقه', toman(2e5, 2e6, f), 'inccat_general')
        d += timedelta(days=1)
    return out


def generate_upcoming(today, now):
    f = inflation(today)
    items = [
        (-6, 'قسط وام', 1.2e7, 'cat_general', 'قسط ۸ از ۲۴'),
        (-2, 'قبض گاز', 4.5e5, 'cat_bills', None),
        (0, 'تمدید اشتراک فیلیمو', 9e4, 'cat_subs', None),
        (3, 'بیمه ماشین', 9.5e6, 'cat_general', 'بیمه ایران'),
        (5, 'اجاره ماه بعد', 9e6 * f, 'cat_rent', None),
        (12, 'شهریه کلاس زبان', 3.8e6, 'cat_edu', 'ترم پاییز'),
        (19, 'کادوی تولد مامان', 2.5e6, 'cat_gifts', None),
        (34, 'تعویض روغن ماشین', 1.6e6, 'cat_general', None),
        (60, 'بلیت سفر زمستانی', 1.4e7, 'cat_travel', 'تبریز'),
    ]
    out = []
    for days, title, amount, cat, note in items:
        due_local = datetime.combine(today + timedelta(days=days), datetime.min.time(),
                                     tzinfo=LOCAL_TZ)
        created = now - timedelta(days=RNG.randint(3, 40), hours=RNG.randint(0, 12))
        out.append({
            'gid': gid(), 'title': title,
            'amountMinor': int(round(amount / 1000) * 1000) * 100,
            'currency': 'IRT', 'dueAtUtc': iso_utc(due_local), 'note': note,
            'categoryGid': cat, 'version': 1,
            'createdAtUtc': iso_utc(created), 'updatedAtUtc': iso_utc(created),
        })
    history = []
    for i, u in enumerate(out + [
        {'title': 'قبض برق', 'amountMinor': 2400000, 'categoryGid': 'cat_bills'},
        {'title': 'شارژ ساختمان', 'amountMinor': 85000000, 'categoryGid': 'cat_bills'},
    ]):
        history.append({
            'title': u['title'], 'amountMinor': u['amountMinor'],
            'categoryGid': u['categoryGid'],
            'lastUsedAtUtc': iso_utc(now - timedelta(days=i * 2 + 1)),
        })
    return out, history


def generate_debts(today, now):
    """Both sides; titles/people that don't mix between the sides."""
    rows, pays = [], []

    def debt(direction, person, title, toman_amount, started_days_ago,
             due_in=None, note=None, paid=(), currency='IRT'):
        g = gid()
        started = now - timedelta(days=started_days_ago)
        unit = 10 if currency == 'IRR' else 1
        rows.append({
            'gid': g, 'direction': direction, 'person': person, 'title': title,
            'amountMinor': toman_amount * unit * 100, 'currency': currency,
            'startedAtUtc': iso_utc(started),
            'dueAtUtc': None if due_in is None else iso_utc(
                datetime.combine(today + timedelta(days=due_in),
                                 datetime.min.time(), tzinfo=LOCAL_TZ)),
            'note': note, 'version': 1,
            'createdAtUtc': iso_utc(started), 'updatedAtUtc': iso_utc(started),
        })
        for days_ago, toman_paid in paid:
            when = now - timedelta(days=days_ago)
            pays.append({
                'gid': gid(), 'debtGid': g, 'amountMinor': toman_paid * 100,
                'currency': 'IRT', 'paidAtUtc': iso_utc(when), 'version': 1,
                'createdAtUtc': iso_utc(when), 'updatedAtUtc': iso_utc(when),
            })

    # I owe: family and a friend, for big purchases / rent
    debt('owe', 'بابا', 'خرید ماشین', 150_000_000, 200, note='بدون عجله',
         paid=[(150, 20_000_000), (90, 20_000_000), (30, 15_000_000)])
    debt('owe', 'علی رضایی', 'قرض برای اجاره', 20_000_000, 25, due_in=10)
    debt('owe', 'بابا', 'شهریه دانشگاه', 35_000_000, 60, due_in=-3)
    debt('owe', 'مامان', 'تعمیر گوشی', 4_500_000, 12, paid=[(5, 1_500_000)])
    # Owed to me: friends and colleagues, for small things / a laptop
    debt('owed', 'سارا', 'ناهار گروهی', 1_200_000, 4)
    debt('owed', 'رضا', 'قرض برای لپ‌تاپ', 30_000_000, 70, due_in=20,
         paid=[(40, 10_000_000)])
    debt('owed', 'مریم', 'بلیت کنسرت', 2_400_000, 45, paid=[(20, 2_400_000)])
    debt('owed', 'همکار - امیر', 'ناهار گروهی', 850_000, 2, currency='IRR')
    return rows, pays


def java_hash_hex(text):
    """Integer.toHexString(text.trim().hashCode()), like BankStore.keyOf."""
    data = text.strip().encode('utf-16-be')  # Java chars = UTF-16 units
    h = 0
    for i in range(0, len(data), 2):
        h = (31 * h + (data[i] << 8 | data[i + 1])) & 0xFFFFFFFF
    return format(h, 'x')


def fa_digits(s):
    return s.translate(str.maketrans('0123456789,', '۰۱۲۳۴۵۶۷۸۹٬'))


def generate_bank_messages(now):
    """Captured bank SMS (as the notification listener stores them), newest
    first, in the layouts the reader is tested on. No learned formats: each
    layout waits for its first confirmation."""
    g = lambda n: f'{n:,}'
    msgs = []

    def add(hours_ago, sender, text):
        when = now - timedelta(hours=hours_ago)
        msgs.append({'key': java_hash_hex(text), 'text': text, 'sender': sender,
                     'postedAt': int(when.timestamp() * 1000),
                     'package': 'com.google.android.apps.messaging'})

    bal = 412_000_000
    add(2, 'Blu', f'بلو\nبرداشت پول\nعلی عزیز، {g(8_345_000)} ریال از حساب شما پرید.\n'
                  f'موجودی: {g(bal)} ریال\n18:52\n1405.07.27')
    add(9, 'B.Pasargad', f'777.888.12345678.1\n-{g(40_008_000)}\n07/27_09:10\n'
                         f'مانده: {g(1_000_000_000)}')
    add(20, 'Bank Mellat', f'Bank Mellat\nDeposit to 1234.5678.9\nAmount: {g(120_000_000)} IRR\n'
                           f'Available balance: {g(530_000_000)} IRR\n2026/10/18 11:02')
    add(30, 'Bank Saman', 'بانک سامان\nخرید با کارت ۶۲۱۹***۱۲۳۴\n'
                          f'مبلغ: {fa_digits(g(345_000))} تومان\nمانده: {fa_digits(g(8_280_000))} تومان')
    add(44, 'Saman Bank', f'Saman Bank\nCard 6219-xxxx-1234\nWithdrawal {g(1_250_000)} Toman\n'
                          f'Remaining {g(7_030_000)} Toman')
    add(60, 'Blu', f'بلو\nواریز پول\nعلی عزیز، {g(250_000_000)} ریال به حساب شما نشست.\n'
                   f'موجودی: {g(420_345_000)} ریال\n10:05\n1405.07.25')
    add(75, 'B.Pasargad', f'777.888.12345678.1\n+{g(1_135_000_000)}\n07/24_09:56\n'
                          f'مانده: {g(1_140_000_000)}')
    add(100, 'Bank Saman', 'بانک سامان\nخرید با کارت ۶۲۱۹***۱۲۳۴\n'
                           f'مبلغ: {fa_digits(g(89_000))} تومان\nمانده: {fa_digits(g(8_625_000))} تومان')
    add(130, 'Blu', f'بلو\nبرداشت پول\nعلی عزیز، {g(1_100_000)} ریال از حساب شما پرید.\n'
                    f'موجودی: {g(170_345_000)} ریال\n21:40\n1405.07.22')
    add(170, 'Bank Mellat', f'Bank Mellat\nWithdrawal\nAmount: {g(6_500_000)} IRR\n'
                            f'Available balance: {g(410_000_000)} IRR\n2026/10/11 19:20')
    # one sender ignored (its messages aren't listed or read)
    return {'formats': [], 'messages': msgs, 'ignoredSenders': ['Hamrah-e Aval']}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--today', default=date.today().isoformat())
    ap.add_argument('--out')
    a = ap.parse_args()
    today = date.fromisoformat(a.today)
    now = datetime.combine(today, datetime.min.time(), tzinfo=LOCAL_TZ).replace(hour=12)

    expenses = sorted(generate_expenses(today, now), key=lambda e: e['occurredAtUtc'])
    incomes = sorted(generate_incomes(today, now), key=lambda e: e['occurredAtUtc'])
    upcoming, history = generate_upcoming(today, now)
    debts, debt_payments = generate_debts(today, now)
    bank = generate_bank_messages(now)

    t = lambda v: v * 100  # toman -> minor units
    budgets = {
        'cat_groceries': t(14_000_000), 'cat_restaurant': t(4_000_000),
        'cat_cafe': t(1_500_000), 'cat_taxi': t(3_000_000), 'cat_fuel': t(800_000),
        'cat_rent': t(23_000_000), 'cat_bills': t(3_000_000), 'cat_mobile': t(900_000),
        'cat_health': t(2_000_000), 'cat_clothes': t(3_500_000), 'cat_fun': t(1_500_000),
        'cat_subs': t(500_000), 'cat_gym': t(1_500_000), 'cat_pets': t(1_200_000),
        'cat_care': t(800_000),
    }
    seed = 0xFF0BA5A4  # teal: visibly different from the default blue
    settings = {
        'themeMode': 'dark', 'seedColor': seed, 'currencyCode': 'IRT', 'startDay': 1,
        'biometricEnabled': False, 'localeCode': 'fa', 'calendar': 'jalali',
    }
    prefs = {  # typed, as the app now exports them
        'onboarding_done_v1': True, 'budgetSortModeV1': 'spentDesc',
        '_budget_migrated_v3': True, 'xp_saves_count': 42,
        'themeMode': 'dark', 'seedColor': seed, 'onSeedTextIsWhite': True,
        'currency': 'IRT', 'biometric': False, 'premium': False, 'startDay': 1,
        'locale': 'fa', 'calendar': 'jalali',
        # every home tab on; our bank notifications stay off until allowed
        'tabUpcoming': True, 'tabDebts': True, 'tabSms': True, 'bankNotify': False,
        # a few ignored suggestions (Settings > Ignored), one list each
        # (upcoming payments share the expense list; debts: per side)
        'ignoredTitles.expense': ['سوشی', 'کادوی تولد مامان'],
        'ignoredTitles.income': [],
        'ignoredTitles.oweTitle': [], 'ignoredTitles.owePerson': [],
        'ignoredTitles.owedTitle': [], 'ignoredTitles.owedPerson': ['همکار - امیر'],
        'noSuggestCategoriesV1': [],
        # two of the bank messages already added to the ledger
        'smsAddedV1': [bank['messages'][5]['key'], bank['messages'][6]['key']],
    }

    payload = {
        'version': 3,
        'updatedAt': now.isoformat(),
        'expenses': expenses,
        'categories': cat_rows(EXP_CATS),
        'settings': settings,
        'budgets': budgets,
        'incomeCategories': cat_rows(INC_CATS),
        'incomes': incomes,
        'upcoming': upcoming,
        'upcomingHistory': history,
        'debts': debts,
        'debtPayments': debt_payments,
        'bankData': bank,
        'prefsDump': prefs,
    }

    jy, jm, jd = g2j(today)
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out = a.out or os.path.join(root, 'build', 'sample_backup',
                                f'OpenFinances-{jy}-{jm:02d}-{jd:02d}-sample-backup.json')
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, 'w', encoding='utf-8') as fh:
        json.dump(payload, fh, ensure_ascii=False)

    years = sorted({g2j(datetime.fromisoformat(e['occurredAtUtc'][:10]).date())[0]
                    for e in expenses})
    print(f'{out}\n  expenses {len(expenses)}, incomes {len(incomes)}, '
          f'upcoming {len(upcoming)}, history {len(history)}, '
          f'debts {len(debts)} ({len(debt_payments)} payments), '
          f'bank messages {len(bank["messages"])}, '
          f'Jalali years {years[0]}-{years[-1]}, {os.path.getsize(out) // 1024} KB')


if __name__ == '__main__':
    main()
