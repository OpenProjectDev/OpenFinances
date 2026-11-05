package com.openproject.openfinances

import android.app.Notification
import android.content.ComponentName
import android.content.Context
import android.provider.Telephony
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/**
 * Reads the notifications the messaging app shows for incoming SMS, so bank
 * transaction messages reach the app without any SMS permission. Runs only
 * while the user has granted notification access (system settings);
 * Android binds it by itself, even when the app isn't open.
 *
 * Only messages [BankMessageReader] can read as a transaction (or that match
 * a format the user confirmed) are kept, and each new one gets our own
 * notification with the reading to confirm (see [BankTxnNotifier]).
 */
class BankNotificationListener : NotificationListenerService() {

    override fun onListenerConnected() {
        // Catch what's already in the shade (no notification for those).
        try {
            activeNotifications?.forEach { capture(it, notify = false) }
        } catch (_: Exception) {
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        try {
            capture(sbn, notify = true)
        } catch (_: Exception) {
        }
    }

    private fun capture(sbn: StatusBarNotification, notify: Boolean) {
        if (!isMessagingApp(sbn.packageName)) return
        val n = sbn.notification
        if (n.flags and Notification.FLAG_GROUP_SUMMARY != 0) return

        val found = ArrayList<BankEntry>()
        val title = n.extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        // Chat-style notifications hold each unread message with its time.
        val style = NotificationCompat.MessagingStyle.extractMessagingStyleFromNotification(n)
        if (style != null && style.messages.isNotEmpty()) {
            for (m in style.messages) {
                val text = m.text?.toString() ?: continue
                val sender = style.conversationTitle?.toString()
                    ?: m.person?.name?.toString() ?: title
                val time = if (m.timestamp > 0) m.timestamp else sbn.postTime
                found.add(BankEntry(BankStore.keyOf(text), text, sender, time, sbn.packageName))
            }
        } else {
            val extras = n.extras
            val text = (extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
                ?: extras.getCharSequence(Notification.EXTRA_TEXT))?.toString()
            if (text != null) {
                found.add(BankEntry(BankStore.keyOf(text), text, title, sbn.postTime, sbn.packageName))
            }
        }

        ingest(this, found, notify)
    }

    private fun isMessagingApp(pkg: String): Boolean =
        pkg == Telephony.Sms.getDefaultSmsPackage(this) || pkg in MESSAGING_APPS

    companion object {
        /**
         * Keeps the [found] messages that read as transactions (new ones
         * only) and, with [notify], posts our notification for each.
         * Real notifications and the test tool both come through here.
         */
        fun ingest(context: Context, found: List<BankEntry>, notify: Boolean) {
            val formats = BankStore.formats(context)
            val ignored = BankStore.ignoredSenderKeys(context)
            val money = found.filter {
                if (BankStore.isIgnored(it, ignored)) return@filter false
                val s = BankMessageReader.read(it.text, formats).status
                s == BankMessageReader.Status.LEARNED || s == BankMessageReader.Status.GUESS
            }
            if (money.isEmpty()) return
            val added = BankStore.add(context, money)
            if (notify && AppPrefs.notifyBankMessages(context)) {
                for (e in added) BankTxnNotifier.show(context, e)
            }
        }

        private val MESSAGING_APPS = setOf(
            "com.google.android.apps.messaging",
            "com.samsung.android.messaging",
            "com.android.mms",
            "com.android.messaging",
        )

        fun hasAccess(context: Context): Boolean =
            NotificationManagerCompat.getEnabledListenerPackages(context)
                .contains(context.packageName)

        fun component(context: Context) =
            ComponentName(context, BankNotificationListener::class.java)
    }
}
