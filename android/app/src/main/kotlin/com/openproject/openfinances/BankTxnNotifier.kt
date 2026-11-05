package com.openproject.openfinances

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.openproject.openfinances.BankMessageReader.Guess
import com.openproject.openfinances.BankMessageReader.Kind
import com.openproject.openfinances.BankMessageReader.Status

/**
 * Our notification for a bank message (drawn in the app's font by
 * [NotifText]; the bank in the header, never the message itself, Latin
 * digits):
 *  - a layout the user defined before: the reading ("Expense: 835,000"),
 *    "Tap to record" under it (a notification can show without its
 *    buttons), Add, which opens the app's add sheet prefilled, and Seen
 *    (out of the SMS tab's New, nothing recorded);
 *  - any other: "unknown format"; tapping it opens the app's define-format
 *    sheet; buttons: Ignore (messages laid out like this aren't
 *    transactions) and Ignore sender (never read this sender's messages).
 */
object BankTxnNotifier {
    private const val CHANNEL = "bank_messages"

    const val EXTRA_ACTION = "bankAction"
    const val EXTRA_KEY = "bankKey"
    const val EXTRA_KIND = "bankKind"
    const val EXTRA_AMOUNT = "bankAmount"
    const val EXTRA_UNIT = "bankUnit"
    const val EXTRA_POSTED = "bankPosted"

    const val ACTION_ADD = "add"
    const val ACTION_DEFINE = "define"
    const val ACTION_IGNORE = "com.openproject.openfinances.BANK_IGNORE"
    const val ACTION_IGNORE_SENDER = "com.openproject.openfinances.BANK_IGNORE_SENDER"
    const val ACTION_SEEN = "com.openproject.openfinances.BANK_SEEN"

    private class Strings(val fa: Boolean) {
        fun t(f: String, e: String) = if (fa) f else e
        val channel = t("پیامک‌های بانکی", "Bank messages")
        val expense = t("هزینه", "Expense")
        val income = t("درآمد", "Income")
        val add = t("ثبت", "Add")
        val seen = t("دیده شد", "Seen")
        val tapToRecord = t("برای ثبت لمس کنید", "Tap to record")
        val unknown = t("قالب این پیامک شناخته نشد", "Unknown message format")
        val tapToDefine = t("برای تعریف قالب کلیک کنید", "Tap to define it")
        val ignore = t("نادیده گرفتن", "Ignore")
        val ignoreSender = t("نادیده گرفتن فرستنده", "Ignore sender")
    }

    fun notificationId(key: String) = key.hashCode()

    fun cancel(context: Context, key: String) =
        NotificationManagerCompat.from(context).cancel(notificationId(key))

    /** Shows (or updates) the notification for [e]. */
    fun show(context: Context, e: BankEntry) {
        val reading = BankStore.read(context, e)
        if (reading.status != Status.LEARNED && reading.status != Status.GUESS) {
            cancel(context, e.key)
            return
        }
        val fa = AppPrefs.isFa(context)
        val s = Strings(fa)
        ensureChannel(context, s)
        val b = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_bank)
            .setAutoCancel(true)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)

        val title: String
        val text: String
        if (reading.status == Status.LEARNED) {
            val g = reading.guesses.first()
            title = label(context, s, g)
            text = s.tapToRecord
            b.setContentIntent(addIntent(context, e, g))
                .addAction(0, s.add, addIntent(context, e, g))
                .addAction(0, s.seen, broadcast(context, ACTION_SEEN, e.key))
        } else {
            title = s.unknown
            text = s.tapToDefine
            // Tapping it defines the format (in the app); two buttons only,
            // so their labels fit.
            b.setContentIntent(defineIntent(context, e))
                .addAction(0, s.ignore, broadcast(context, ACTION_IGNORE, e.key))
            if (e.sender.isNotBlank()) {
                b.addAction(0, s.ignoreSender, broadcast(context, ACTION_IGNORE_SENDER, e.key))
            }
        }
        b.setContentTitle(title)
            .setSubText(e.sender.ifBlank { null })
        if (text.isNotEmpty()) b.setContentText(text)
        // If drawing fails: the system's own layout and font.
        val views = try {
            NotifText.views(context, title, text, fa, big = false) to
                NotifText.views(context, title, text, fa, big = true)
        } catch (_: Exception) {
            null
        }
        if (views != null) {
            b.setStyle(NotificationCompat.DecoratedCustomViewStyle())
                .setCustomContentView(views.first)
                .setCustomBigContentView(views.second)
        }

        try {
            NotificationManagerCompat.from(context).notify(notificationId(e.key), b.build())
        } catch (_: SecurityException) {
            // No permission to post notifications: the SMS tab still lists it.
        }
    }

    private fun label(context: Context, s: Strings, g: Guess): String {
        val amount = formatAmount(g, AppPrefs.currency(context))
        return "${if (g.kind == Kind.INCOME) s.income else s.expense}: $amount"
    }

    /**
     * Rounded in the message's own unit (toman to the nearest 1,000, rial to
     * the nearest 10,000): what gets recorded, in that unit.
     */
    fun roundedInUnit(g: Guess): Long = when (g.unit) {
        "IRT" -> Math.round(g.amount / 1000.0) * 1000
        "IRR" -> Math.round(g.amount / 10000.0) * 10000
        else -> g.amount
    }

    /** As the app shows it: the recorded amount in the display currency
     *  (toman/rial converted, like amountInUnit in Dart). */
    private fun formatAmount(g: Guess, display: String): String {
        val rial = mapOf("IRT" to 10L, "IRR" to 1L)
        val from = rial[g.unit]
        val to = rial[display]
        val v = roundedInUnit(g).let { if (from != null && to != null) it * from / to else it }
        return "%,d".format(java.util.Locale.US, v)
    }

    private fun ensureChannel(context: Context, s: Strings) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(NotificationManager::class.java)
        if (nm.getNotificationChannel(CHANNEL) != null) return
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL, s.channel, NotificationManager.IMPORTANCE_HIGH)
        )
    }

    private const val FLAGS = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE

    private fun code(key: String, what: Int) = key.hashCode() * 31 + what

    private fun addIntent(context: Context, e: BankEntry, g: Guess): PendingIntent {
        val i = Intent(context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            .putExtra(EXTRA_ACTION, ACTION_ADD)
            .putExtra(EXTRA_KEY, e.key)
            .putExtra(EXTRA_KIND, g.kind.name)
            .putExtra(EXTRA_AMOUNT, roundedInUnit(g))
            .putExtra(EXTRA_UNIT, g.unit)
            .putExtra(EXTRA_POSTED, e.postedAt)
        return PendingIntent.getActivity(context, code(e.key, 100), i, FLAGS)
    }

    private fun defineIntent(context: Context, e: BankEntry): PendingIntent {
        val i = Intent(context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            .putExtra(EXTRA_ACTION, ACTION_DEFINE)
            .putExtra(EXTRA_KEY, e.key)
        return PendingIntent.getActivity(context, code(e.key, 99), i, FLAGS)
    }

    private fun broadcast(context: Context, action: String, key: String): PendingIntent {
        val i = Intent(context, BankActionReceiver::class.java)
            .setAction(action)
            .putExtra(EXTRA_KEY, key)
        val what = when (action) {
            ACTION_IGNORE -> 2
            ACTION_SEEN -> 4
            else -> 3
        }
        return PendingIntent.getBroadcast(context, code(key, what), i, FLAGS)
    }
}

/** "Ignore", "Ignore sender" and "Seen" on our notification, without
 *  opening the app. */
class BankActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val key = intent.getStringExtra(BankTxnNotifier.EXTRA_KEY) ?: return
        val e = BankStore.entry(context, key) ?: return BankTxnNotifier.cancel(context, key)
        when (intent.action) {
            BankTxnNotifier.ACTION_IGNORE -> {
                BankStore.addFormat(
                    context,
                    BankMessageReader.ignoreFormat(e.text, System.currentTimeMillis()),
                )
                BankTxnNotifier.cancel(context, key)
            }
            BankTxnNotifier.ACTION_SEEN -> {
                BankStore.markSeen(context, key)
                BankTxnNotifier.cancel(context, key)
                BankStore.onChange?.invoke()
            }
            BankTxnNotifier.ACTION_IGNORE_SENDER -> {
                BankStore.setSenderIgnored(context, e.sender, true)
                // Its other messages' notifications go too.
                val keys = BankStore.ignoredSenderKeys(context)
                for (x in BankStore.entries(context)) {
                    if (BankStore.isIgnored(x, keys)) BankTxnNotifier.cancel(context, x.key)
                }
            }
        }
    }
}
