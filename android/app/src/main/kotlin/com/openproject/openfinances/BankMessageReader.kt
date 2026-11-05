package com.openproject.openfinances

/**
 * Finds the amount a bank message moved, for any bank and language.
 *
 * Two ways to read a message:
 *  - A learned [BankFormat]: the user confirmed a reading of a message with
 *    the same layout before, so we know which number is the amount and which
 *    way it went. This is the reliable path; each layout needs one
 *    confirmation.
 *  - Guesses: every number that could be an amount, ranked by what's around
 *    it (thousands separators, a sign, a currency word, "amount"/"withdraw"
 *    words; balance, fee and code words count against). The direction comes
 *    from the sign or from words like برداشت/واریز, withdraw/deposit. When
 *    the direction is unclear, the same number is offered both ways.
 *
 * Pure Kotlin (no Android types), so it's unit-tested on the JVM.
 */
object BankMessageReader {

    enum class Kind { EXPENSE, INCOME }

    enum class Status {
        /** Read by a learned format. */
        LEARNED,

        /** Read by guessing (needs the user's confirmation once). */
        GUESS,

        /** The user said messages of this layout aren't transactions. */
        IGNORED,

        /** Not a transaction (or nothing that could be an amount). */
        NONE,
    }

    /**
     * One reading: [amount] in the message's own [unit] ("IRR" rial or
     * "IRT" toman: banks differ) went out ([Kind.EXPENSE]) or came in.
     */
    data class Guess(
        val amount: Long,
        val unit: String,
        val kind: Kind,
        val runIndex: Int,
        /** Where the number is in the message (for highlighting). */
        val start: Int,
        val end: Int,
    ) {
        val amountRial: Long get() = if (unit == "IRT") amount * 10 else amount
    }

    data class Reading(val status: Status, val guesses: List<Guess>)

    /**
     * A learned layout. [skeleton] is the message with every number replaced
     * by `#`; the amount is the number run at [runIndex], recognized by the
     * words around it ([before], [after]) when the layout shifts a little.
     * [kind] is "expense", "income", "sign" (from the number's own sign) or
     * "ignore" (not a transaction).
     */
    data class BankFormat(
        val skeleton: String,
        val runIndex: Int,
        val before: String,
        val after: String,
        val kind: String,
        val rialPerUnit: Int,
        val createdAt: Long,
        /** The user's name for it (empty: none; the app shows the sender). */
        val name: String = "",
    )

    // ------------------------------------------------------------------
    // Reading
    // ------------------------------------------------------------------

    fun read(text: String, formats: List<BankFormat>): Reading {
        val norm = normalize(text)
        val runs = numberRuns(norm)
        val format = matchFormat(norm, runs, formats)
        if (format?.kind == "ignore") return Reading(Status.IGNORED, emptyList())

        val learned = format?.let { applyFormat(it, norm, runs) }
        val guesses = guess(norm, runs)
        if (learned != null) {
            return Reading(
                Status.LEARNED,
                listOf(learned) + guesses.filterNot {
                    it.runIndex == learned.runIndex && it.kind == learned.kind
                },
            )
        }
        if (guesses.isEmpty() || !looksLikeTransaction(norm, runs)) {
            return Reading(Status.NONE, emptyList())
        }
        return Reading(Status.GUESS, guesses)
    }

    /** A format learned from the user confirming [guess] on [text]. */
    fun learn(text: String, guess: Guess, now: Long): BankFormat {
        val norm = normalize(text)
        val runs = numberRuns(norm)
        val run = runs.getOrNull(guess.runIndex)
        val (before, after) = if (run != null) contextKey(norm, run) else "" to ""
        return BankFormat(
            skeleton = skeleton(norm, runs),
            runIndex = guess.runIndex,
            before = before,
            after = after,
            kind = when {
                run?.sign != null -> "sign"
                guess.kind == Kind.INCOME -> "income"
                else -> "expense"
            },
            rialPerUnit = if (guess.unit == "IRT") 10 else 1,
            createdAt = now,
        )
    }

    /** "Not a transaction" for every message laid out like [text]. */
    fun ignoreFormat(text: String, now: Long): BankFormat {
        val norm = normalize(text)
        return BankFormat(skeleton(norm, numberRuns(norm)), -1, "", "", "ignore", 1, now)
    }

    /** The learned format [text] matches, if any (exact layout first). */
    fun formatFor(text: String, formats: List<BankFormat>): BankFormat? {
        val norm = normalize(text)
        return matchFormat(norm, numberRuns(norm), formats)
    }

    // ------------------------------------------------------------------
    // Normalizing (same length as the input, so offsets stay valid)
    // ------------------------------------------------------------------

    fun normalize(s: String): String {
        val b = StringBuilder(s.length)
        for (c in s) {
            b.append(
                when (c) {
                    in '۰'..'۹' -> '0' + (c - '۰') // Persian digits
                    in '٠'..'٩' -> '0' + (c - '٠') // Arabic-Indic
                    '٬', '،' -> ',' // Arabic thousands sep / comma
                    '٫' -> '.' // Arabic decimal sep
                    'ي' -> 'ی'
                    'ك' -> 'ک'
                    '−', '–' -> '-' // minus sign, en dash
                    '‌', '‎', '‏', '﻿', ' ' -> ' '
                    else -> c.lowercaseChar()
                }
            )
        }
        return b.toString()
    }

    // ------------------------------------------------------------------
    // Numbers
    // ------------------------------------------------------------------

    data class Run(
        val index: Int,
        val start: Int,
        val end: Int,
        val raw: String,
        val sign: Char?,
        /** Could be an amount (not a date, time, account, card or phone). */
        val amountLike: Boolean,
        val grouped: Boolean,
        val value: Long,
    )

    // A run of digits joined by separators, with an optional sign that isn't
    // glued to a word before it.
    private val RUN = Regex("""(?<![\p{L}\d])([+-])?\d(?:[\d,./:_*-]*\d)?""")
    private val GROUPED = Regex("""^\d{1,3}(?:,\d{3})+(?:\.\d+)?$""")
    private val PLAIN = Regex("""^\d+(?:\.\d+)?$""")

    fun numberRuns(norm: String): List<Run> {
        val out = ArrayList<Run>()
        for (m in RUN.findAll(norm)) {
            val sign = m.groupValues[1].firstOrNull()
            val body = if (sign != null) m.value.substring(1) else m.value
            val grouped = GROUPED.matches(body)
            val plain = PLAIN.matches(body)
            val digits = body.substringBefore('.').replace(",", "")
            val value = digits.toLongOrNull() ?: -1L
            val amountLike = value > 0 && (grouped || (plain && digits.length <= 10))
            out.add(Run(out.size, m.range.first, m.range.last + 1, m.value, sign, amountLike, grouped, value))
        }
        return out
    }

    // ------------------------------------------------------------------
    // Guessing
    // ------------------------------------------------------------------

    private val CURRENCY = setOf("ریال", "rial", "rials", "irr", "rls", "ر", "تومان", "تومن", "toman", "tomans", "irt")
    private val TOMAN = setOf("تومان", "تومن", "toman", "tomans", "irt")
    private val AMOUNT_WORDS = setOf(
        "مبلغ", "amount", "amt", "برداشت", "واریز", "خرید", "انتقال", "پرداخت",
        "withdraw", "withdrawal", "deposit", "debit", "credit", "purchase", "transfer", "payment",
    )
    private val BALANCE_WORDS = setOf(
        "مانده", "موجودی", "اعتبار", "balance", "bal", "remain", "remaining", "avail", "available",
    )
    private val FEE_WORDS = setOf("کارمزد", "fee", "charge")
    private val ID_WORDS = setOf(
        "رمز", "کد", "code", "otp", "pin", "pass", "password", "شماره", "no", "number", "ref",
        "پیگیری", "سریال", "ترمینال", "terminal", "کارت", "card", "حساب", "acc", "account", "شبا",
    )
    private val EXPENSE_CUES = setOf(
        "برداشت", "خرید", "پرداخت", "کسر", "پرید", "withdraw", "withdrawal", "withdrawn", "debit",
        "debited", "dr", "purchase", "purchased", "paid", "payment", "spent",
    )
    private val INCOME_CUES = setOf(
        "واریز", "دریافت", "نشست", "افزایش", "بازگشت", "deposit", "deposited", "credit", "credited",
        "cr", "received", "refund",
    )

    // A one-time code ("رمز: 76578", "کد 19937443"): confirmations and
    // logins, never a settled transaction.
    private val OTP = Regex("""(رمز|کد|code|otp|password|pass|pin)\s*[:：]?\s*\d{4,8}(?!\d)""")
    private val WORD = Regex("""\p{L}+""")

    private fun lineBounds(norm: String, at: Int): Pair<Int, Int> {
        val s = norm.lastIndexOf('\n', at - 1).let { if (it < 0) 0 else it + 1 }
        val e = norm.indexOf('\n', at).let { if (it < 0) norm.length else it }
        return s to e
    }

    private fun wordsBefore(norm: String, run: Run, n: Int): List<String> {
        val (s, _) = lineBounds(norm, run.start)
        return WORD.findAll(norm.substring(s, run.start)).map { it.value }.toList().takeLast(n)
    }

    private fun wordsAfter(norm: String, run: Run, n: Int): List<String> {
        val (_, e) = lineBounds(norm, run.start)
        return WORD.findAll(norm.substring(run.end, e)).map { it.value }.take(n).toList()
    }

    private fun score(norm: String, run: Run): Double {
        val before = wordsBefore(norm, run, 3)
        val after = wordsAfter(norm, run, 2)
        var s = 0.0
        if (run.grouped) s += 3
        if (run.sign != null) s += 3
        if (after.firstOrNull() in CURRENCY) s += 3
        if (before.lastOrNull() in CURRENCY) s += 2
        if (before.any { it in AMOUNT_WORDS }) s += 2
        if (before.any { it in BALANCE_WORDS }) s -= 6
        if (before.any { it in FEE_WORDS }) s -= 3
        if (before.lastOrNull() in ID_WORDS) s -= 8
        if (run.value < 1000) s -= 2
        return s
    }

    /**
     * The unit [run] is in: the currency word right after (or before) it,
     * else the first currency word in the message, else rial.
     */
    fun unitOf(norm: String, run: Run): String {
        val near = wordsAfter(norm, run, 1).firstOrNull()?.takeIf { it in CURRENCY }
            ?: wordsBefore(norm, run, 1).lastOrNull()?.takeIf { it in CURRENCY }
            ?: WORD.findAll(norm).map { it.value }.firstOrNull { it in CURRENCY && it != "ر" }
        return if (near in TOMAN) "IRT" else "IRR"
    }

    /** The direction the words in the message point to (null if unclear). */
    private fun cueKind(norm: String): Kind? {
        var out = 0
        var inn = 0
        for (w in WORD.findAll(norm)) {
            if (w.value in EXPENSE_CUES) out++
            if (w.value in INCOME_CUES) inn++
        }
        return when {
            out > inn -> Kind.EXPENSE
            inn > out -> Kind.INCOME
            else -> null
        }
    }

    private fun kindOf(run: Run, cue: Kind?): Kind? = when (run.sign) {
        '-' -> Kind.EXPENSE
        '+' -> Kind.INCOME
        else -> cue
    }

    /** Best first; a number whose direction is unclear comes both ways. */
    fun guess(norm: String, runs: List<Run>): List<Guess> {
        if (OTP.containsMatchIn(norm)) return emptyList()
        val cue = cueKind(norm)
        val ranked = runs.filter { it.amountLike }
            .map { it to score(norm, it) }
            .sortedWith(compareByDescending<Pair<Run, Double>> { it.second }.thenBy { it.first.start })
        val out = ArrayList<Guess>()
        for ((run, _) in ranked) {
            val unit = unitOf(norm, run)
            val kind = kindOf(run, cue)
            if (kind != null) {
                out.add(Guess(run.value, unit, kind, run.index, run.start, run.end))
            } else {
                out.add(Guess(run.value, unit, Kind.EXPENSE, run.index, run.start, run.end))
                out.add(Guess(run.value, unit, Kind.INCOME, run.index, run.start, run.end))
            }
        }
        return out
    }

    // Shop ads quote prices with "buy"/"pay" words; banks don't send these.
    private val AD_MARKERS = listOf("تخفیف", "لغو", "http", "www.", "discount", "unsubscribe", "% off")

    /**
     * Worth asking about: a number that looks like an amount, and something
     * saying money moved: a balance or a signed amount (what bank messages
     * carry), or else a direction word in a message that isn't an ad.
     */
    private fun looksLikeTransaction(norm: String, runs: List<Run>): Boolean {
        val best = runs.filter { it.amountLike }.maxOfOrNull { score(norm, it) } ?: return false
        if (best < 3) return false
        val words = WORD.findAll(norm).map { it.value }.toSet()
        if (runs.any { it.amountLike && it.sign != null } || words.any { it in BALANCE_WORDS }) {
            return true
        }
        return best >= 4 && cueKind(norm) != null && AD_MARKERS.none { norm.contains(it) }
    }

    // ------------------------------------------------------------------
    // Formats
    // ------------------------------------------------------------------

    private val SPACES = Regex("""[ \t]+""")

    fun skeleton(norm: String, runs: List<Run>): String {
        val b = StringBuilder()
        var at = 0
        for (r in runs) {
            b.append(norm, at, r.start).append('#')
            at = r.end
        }
        b.append(norm, at, norm.length)
        return b.toString().lines().joinToString("\n") { it.replace(SPACES, " ").trim() }.trim()
    }

    private fun tokens(skeleton: String): Set<String> =
        Regex("""\p{L}+|#""").findAll(skeleton).map { it.value }.toSet()

    private fun contextKey(norm: String, run: Run): Pair<String, String> =
        wordsBefore(norm, run, 2).joinToString(" ") to wordsAfter(norm, run, 1).joinToString(" ")

    private fun matchFormat(norm: String, runs: List<Run>, formats: List<BankFormat>): BankFormat? {
        if (formats.isEmpty()) return null
        val sk = skeleton(norm, runs)
        formats.lastOrNull { it.skeleton == sk }?.let { return it }
        // Same layout with other words in places (a shop's name, a person):
        // most words shared and about the same number of numbers.
        val mine = tokens(sk)
        var best: BankFormat? = null
        var bestSim = 0.0
        for (f in formats) {
            val theirs = tokens(f.skeleton)
            val union = (mine + theirs).size
            if (union == 0) continue
            val sim = (mine intersect theirs).size.toDouble() / union
            val runDiff = kotlin.math.abs(sk.count { it == '#' } - f.skeleton.count { it == '#' })
            if (sim >= 0.8 && runDiff <= 1 && sim >= bestSim) {
                best = f
                bestSim = sim
            }
        }
        return best
    }

    private fun applyFormat(f: BankFormat, norm: String, runs: List<Run>): Guess? {
        val amounts = runs.filter { it.amountLike }
        val run = amounts.firstOrNull { contextKey(norm, it) == (f.before to f.after) }
            ?: amounts.firstOrNull { it.index == f.runIndex && wordsBefore(norm, it, 2).joinToString(" ") == f.before }
            ?: amounts.firstOrNull { it.index == f.runIndex }
            ?: return null
        val kind = when (f.kind) {
            "income" -> Kind.INCOME
            "expense" -> Kind.EXPENSE
            else -> kindOf(run, cueKind(norm)) ?: return null
        }
        val unit = if (f.rialPerUnit == 10) "IRT" else "IRR"
        return Guess(run.value, unit, kind, run.index, run.start, run.end)
    }
}
