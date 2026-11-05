package com.openproject.openfinances

import com.openproject.openfinances.BankMessageReader.Kind
import com.openproject.openfinances.BankMessageReader.Status
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class BankMessageReaderTest {

    private fun read(text: String, formats: List<BankMessageReader.BankFormat> = emptyList()) =
        BankMessageReader.read(text, formats)

    private fun first(text: String) = read(text).guesses.first()

    private fun assertNone(text: String) =
        assertEquals(text, Status.NONE, read(text).status)

    // ---------------- First guesses on known layouts ----------------

    @Test fun bluWithdrawal() {
        val g = first(
            "بلو\nبرداشت پول\nعلی عزیز، 8,300,000 ریال از حساب شما پرید.\n" +
                "موجودی: 46,000,000 ریال\n۱۸:۵۲\n۱۴۰۵.۰۷.۰۷"
        )
        assertEquals(8300000L, g.amountRial)
        assertEquals(Kind.EXPENSE, g.kind)
    }

    @Test fun bluDeposit() {
        val g = first(
            "بلو\nدریافت پل\n علی عزیز، 40,000,000 ریال به حساب شما نشست.\n" +
                " موجودی: 54,000,000 ریال\n۱۸:۵۰\n۱۴۰۵.۰۷.۰۷"
        )
        assertEquals(40000000L, g.amountRial)
        assertEquals(Kind.INCOME, g.kind)
    }

    @Test fun pasargadDebitAndCredit() {
        val d = first("777.888.12345678.1\n-40,008,000\n07/07_18:50\nمانده: 1,000,000,000")
        assertEquals(40008000L, d.amountRial)
        assertEquals(Kind.EXPENSE, d.kind)
        val c = first("777.888.12345678.1\n+1,135,000,000\n07/06_09:56\nمانده: 1,140,000,000")
        assertEquals(1135000000L, c.amountRial)
        assertEquals(Kind.INCOME, c.kind)
    }

    @Test fun persianDigitsAndArabicSeparators() {
        val g = first("برداشت از حساب\nمبلغ: ۱۲۰٬۵۰۰٬۰۰۰ ریال\nمانده: ۹۰٬۰۰۰٬۰۰۰ ریال")
        assertEquals(120500000L, g.amountRial)
        assertEquals(Kind.EXPENSE, g.kind)
    }

    @Test fun englishLayouts() {
        val a = first("Bank Pasargad\nAcc: 777.888.12345678.1\nWithdrawal: 1,250,000\nBal: 3,456,789\n07/08 12:30")
        assertEquals(1250000L, a.amountRial)
        assertEquals(Kind.EXPENSE, a.kind)

        val b = first("Pasargad\n777.888.12345678.1\n+2,500,000\n07/08_12:30\nBalance: 9,000,000")
        assertEquals(2500000L, b.amountRial)
        assertEquals(Kind.INCOME, b.kind)

        val c = first("Deposit to 777.888.1.1\nAmount: 75,000,000 IRR\nAvailable balance: 80,000,000 IRR")
        assertEquals(75000000L, c.amountRial)
        assertEquals(Kind.INCOME, c.kind)
    }

    @Test fun eachBanksOwnUnitIsKept() {
        val t = first("خرید با کارت\nمبلغ 125,000 تومان\nموجودی: 4,000,000 تومان")
        assertEquals(125000L, t.amount)
        assertEquals("IRT", t.unit)
        assertEquals(1250000L, t.amountRial)

        val r = first("خرید با کارت\nمبلغ 1,250,000 ریال\nموجودی: 40,000,000 ریال")
        assertEquals(1250000L, r.amount)
        assertEquals("IRR", r.unit)

        // The unit named once elsewhere in the message (not next to it).
        val far = first("بانک نمونه (مبالغ به تومان)\nبرداشت: 125,000\nمانده: 4,000,000")
        assertEquals("IRT", far.unit)
        assertEquals(125000L, far.amount)

        // No unit anywhere: rial.
        assertEquals("IRR", first("777.888.1.1\n-40,008,000\nمانده: 1,000,000,000").unit)
    }

    @Test fun learnedFormatKeepsItsUnit() {
        val a = "خرید\nمبلغ 125,000 تومان\nموجودی: 4,000,000 تومان"
        val f = BankMessageReader.learn(a, first(a), 1L)
        val g = read("خرید\nمبلغ 99,000 تومان\nموجودی: 3,901,000 تومان", listOf(f)).guesses[0]
        assertEquals("IRT", g.unit)
        assertEquals(99000L, g.amount)
    }

    @Test fun unclearDirectionIsOfferedBothWays() {
        val r = read("Bank X\nAmount: 1,000,000 Rial\nBalance: 5,000,000 Rial")
        assertEquals(Status.GUESS, r.status)
        assertEquals(1000000L, r.guesses[0].amountRial)
        assertEquals(setOf(Kind.EXPENSE, Kind.INCOME), r.guesses.take(2).map { it.kind }.toSet())
    }

    // The Settings test chips' messages (keep in sync with _TestBankSmsRow).
    @Test fun testChipMessages() {
        fun check(text: String, amount: Long, unit: String, kind: Kind) {
            val r = read(text)
            assertEquals(text, Status.GUESS, r.status)
            val g = r.guesses[0]
            assertEquals(text, amount, g.amount)
            assertEquals(text, unit, g.unit)
            assertEquals(text, kind, g.kind)
        }
        check(
            "بلو\nبرداشت پول\nعلی عزیز، 3,450,000 ریال از حساب شما پرید.\n" +
                "موجودی: 82,800,000 ریال\n18:52\n1405.07.27",
            3450000, "IRR", Kind.EXPENSE,
        )
        check(
            "777.888.12345678.1\n+3,450,000\n07/27_10:15\nBal: 82,800,000",
            3450000, "IRR", Kind.INCOME,
        )
        check(
            "Bank Mellat\nDeposit to 1234.5678.9\nAmount: 3,450,000 IRR\n" +
                "Available balance: 82,800,000 IRR\n2026/10/19 09:41",
            3450000, "IRR", Kind.INCOME,
        )
        check(
            "بانک سامان\nخرید با کارت ۶۲۱۹***۱۲۳۴\nمبلغ: ۳۴۵٬۰۰۰ تومان\nمانده: ۸٬۲۸۰٬۰۰۰ تومان",
            345000, "IRT", Kind.EXPENSE,
        )
        check(
            "Saman Bank\nCard 6219-xxxx-1234\nWithdrawal 345,000 Toman\nRemaining 8,280,000 Toman",
            345000, "IRT", Kind.EXPENSE,
        )
    }

    // ---------------- Not transactions ----------------

    @Test fun codesAndConfirmationsAreNotTransactions() {
        assertNone("پاسارگاد\nانتقال به\nعلی احمدی\nمبلغ:28,000,000\nرمز: 76578\n17:49:32")
        assertNone("پاسارگاد\nخرید\nآنلاین سازمان تامین \nمبلغ:60,000,000\nرمز: 95736\n13:12:14")
        assertNone(
            "*بانکداري ديجيتالي پاسارگاد*\nجهت انتقال وجه، کد 11112222 را به همین شماره ارسال نمایید\n" +
                "مبلغ: 40,000,000 ریال\nکارمزد: 8,000 ریال"
        )
        assertNone("بانک ملی\nکد 34786 را جهت ورود به سامانه بام وارد نمایید.\nAbCdEfGh123")
        assertNone("Your OTP code: 552211 for amount 1,000,000 IRR")
    }

    @Test fun otherMessagesAreNotTransactions() {
        assertNone(
            "بلو\n\nتایید و پرداخت\nعلی عزیز، خرید خود را از فروشگاه نمونه تایید و پرداخت کنید.\n" +
                "https://app.blubank.com/payment?transaction_id=abc12345\n10:48\n1405.7.4"
        )
        assertNone("پرداخت بدهی و شارژ اعتبار دیجی‌پی\nاعتبار قابل مصرف: ۴۱۶٬۰۰۰٬۰۰۰ ریال")
        assertNone("فروش 500 دلار آمريکا در تاريخ 1405/07/06 به صرافی نمونه و شرکا")
        assertNone("۵شنبه باهام هماهنگ بشین \nممنون ")
        assertNone("999 هزار تومان تخفیف + ارسال رایگان\nکد: LF9H\ndgkl.me/99V9Vg")
        assertNone("999,999 تومان تخفیف ویژه خرید سوپرمارکتی\nکد تخفیف: SDA9\nفقط تا امشب\ndgkl.me/yuYxAw\nلغو11")
        assertNone("سلام، سفارش 123456 دریافت شد.\nمبلغ سفارش : 999,999 تومان\n 99kala.ir \nلغو: off-11")
    }

    // ---------------- Learning ----------------

    @Test fun confirmedGuessIsLearnedForTheSameLayout() {
        val first = "Bank X\nAmount: 1,000,000 Rial\nBalance: 5,000,000 Rial"
        val r = read(first)
        // The user went to the second guess (income) and confirmed it.
        val f = BankMessageReader.learn(first, r.guesses[1], 1L)
        assertEquals("income", f.kind)

        val next = read("Bank X\nAmount: 2,345,000 Rial\nBalance: 7,345,000 Rial", listOf(f))
        assertEquals(Status.LEARNED, next.status)
        assertEquals(2345000L, next.guesses[0].amountRial)
        assertEquals(Kind.INCOME, next.guesses[0].kind)
    }

    @Test fun learnedSlotWinsOverTheHeuristic() {
        // The heuristic's pick is wrong here; the user picked the other number.
        val msg = "Shop ABC\nTotal 1,500,000\nPaid 1,200,000\nBal: 3,000,000"
        val r = read(msg)
        val right = r.guesses.first { it.amountRial == 1200000L }
        val f = BankMessageReader.learn(msg, right, 1L)
        val again = read("Shop ABC\nTotal 900,000\nPaid 850,000\nBal: 2,150,000", listOf(f))
        assertEquals(Status.LEARNED, again.status)
        assertEquals(850000L, again.guesses[0].amountRial)
    }

    @Test fun signedFormatTakesDirectionFromTheSign() {
        val debit = "777.888.12345678.1\n-40,008,000\n07/07_18:50\nمانده: 1,000,000,000"
        val f = BankMessageReader.learn(debit, read(debit).guesses[0], 1L)
        assertEquals("sign", f.kind)
        val credit = read("777.888.12345678.1\n+5,000,000\n07/08_10:00\nمانده: 1,005,000,000", listOf(f))
        assertEquals(Status.LEARNED, credit.status)
        assertEquals(Kind.INCOME, credit.guesses[0].kind)
    }

    @Test fun similarLayoutWithAnotherShopNameStillMatches() {
        val a = "خرید از فروشگاه رفاه\nمبلغ: 1,000,000 ریال\nموجودی: 9,000,000 ریال\nبانک ملت"
        val f = BankMessageReader.learn(a, read(a).guesses[0], 1L)
        val b = read("خرید از فروشگاه کوروش\nمبلغ: 2,000,000 ریال\nموجودی: 7,000,000 ریال\nبانک ملت", listOf(f))
        assertEquals(Status.LEARNED, b.status)
        assertEquals(2000000L, b.guesses[0].amountRial)
    }

    @Test fun ignoredLayoutStaysIgnored() {
        val ad = "فاکتور شماره 16565 به مبلغ 27225000 ریال با موفقیت پرداخت شد."
        assertEquals(Status.GUESS, read(ad).status)
        val f = BankMessageReader.ignoreFormat(ad, 1L)
        assertEquals(
            Status.IGNORED,
            read("فاکتور شماره 17001 به مبلغ 1500000 ریال با موفقیت پرداخت شد.", listOf(f)).status,
        )
    }

    @Test fun offsetsPointAtTheNumberInTheOriginalText() {
        val text = "بلو\nبرداشت پول\nعلی عزیز، ۸٬۳۰۰٬۰۰۰ ریال از حساب شما پرید.\nموجودی: ۴۶٬۰۰۰٬۰۰۰ ریال"
        val g = first(text)
        assertEquals("۸٬۳۰۰٬۰۰۰", text.substring(g.start, g.end))
    }

    // The generated sample backup's bank messages (tool/make_sample_backup.py):
    // every one reads as a transaction, and its key is what BankStore makes.
    @Test fun sampleBackupMessages() {
        val dir = File(File("../..").canonicalFile, "build/sample_backup")
        val files = dir.listFiles { f -> f.name.endsWith(".json") } ?: return
        for (f in files) {
            val msgs = JSONObject(f.readText()).getJSONObject("bankData").getJSONArray("messages")
            assertTrue(msgs.length() > 0)
            for (i in 0 until msgs.length()) {
                val m = msgs.getJSONObject(i)
                val text = m.getString("text")
                assertEquals(text, Status.GUESS, read(text).status)
                assertEquals(text, Integer.toHexString(text.trim().hashCode()), m.getString("key"))
            }
        }
    }

    // ---------------- Real export (gitignored, if present) ----------------

    @Test fun realExport() {
        val root = File("../..").canonicalFile
        val files = File(root, "client-input").listFiles { f -> f.name.matches(Regex("""(openfinances|jibyar)-sms-samples-\d+\.json""")) }
            ?: return
        for (f in files) {
            val msgs = JSONObject(f.readText()).getJSONArray("messages")
            var hits = 0
            for (i in 0 until msgs.length()) {
                val body = msgs.getJSONObject(i).optString("body")
                val r = read(body)
                if (body.startsWith("بلو") && body.contains("ریال")) {
                    // Every Blu transaction: amount = the number before "ریال از/به".
                    val m = Regex("""([\d,]+) ریال (از|به) حساب""").find(BankMessageReader.normalize(body))
                    if (m != null) {
                        hits++
                        assertEquals(body, Status.GUESS, r.status)
                        assertEquals(body, m.groupValues[1].replace(",", "").toLong(), r.guesses[0].amountRial)
                        assertEquals(body, if (m.groupValues[2] == "از") Kind.EXPENSE else Kind.INCOME, r.guesses[0].kind)
                    }
                }
                if (r.status != Status.NONE && !body.startsWith("بلو") && !body.startsWith("777.888.")) {
                    // Anything else that would get a notification: listed for review.
                    File(root, "build/bank_reader_other.txt").appendText("----\n$body\n=> ${r.guesses.firstOrNull()}\n")
                }
                if (body.startsWith("777.888.")) {
                    hits++
                    val signed = Regex("""\n([+-])([\d,]+)\n""").find(body)!!
                    assertEquals(body, signed.groupValues[2].replace(",", "").toLong(), r.guesses[0].amountRial)
                    assertEquals(body, if (signed.groupValues[1] == "-") Kind.EXPENSE else Kind.INCOME, r.guesses[0].kind)
                }
            }
            assertTrue("no bank messages found in ${f.name}", hits > 0)
            File(root, "build/bank_reader_other.txt").appendText("${f.name}: $hits bank messages checked\n")
        }
    }
}
