package com.openproject.openfinances

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/** A captured bank message (from the messaging app's notification). */
data class BankEntry(
    /** Stable id of the text (the same message re-posted keeps it). */
    val key: String,
    val text: String,
    /** Who sent it, as the messaging app names the conversation. */
    val sender: String,
    val postedAt: Long,
    val pkg: String,
)

/**
 * Small JSON files in the app's private storage (never leave the phone,
 * except in the user's own backups):
 *  - bank_notifications.json: captured messages, newest first, max 500.
 *  - bank_formats.json: layouts the user defined (or said to ignore).
 *  - bank_ignored_senders.json: senders whose messages are never read.
 *  - bank_seen.json: messages marked seen from their notification, until
 *    the app takes them into its own list ([takeSeen]).
 */
object BankStore {
    private const val LOG = "bank_notifications.json"
    private const val FORMATS = "bank_formats.json"
    private const val SENDERS = "bank_ignored_senders.json"
    private const val SEEN = "bank_seen.json"
    private const val MAX = 500

    private fun file(context: Context, name: String) = File(context.filesDir, name)

    /** Told when new messages are captured (the app's screen, while open). */
    @Volatile
    var onChange: (() -> Unit)? = null

    private fun readArray(context: Context, name: String): JSONArray = try {
        val f = file(context, name)
        if (f.exists()) JSONArray(f.readText()) else JSONArray()
    } catch (_: Exception) {
        JSONArray()
    }

    fun keyOf(text: String): String = Integer.toHexString(text.trim().hashCode())

    // ---------------- Messages ----------------

    @Synchronized
    fun entries(context: Context): List<BankEntry> {
        val a = readArray(context, LOG)
        return (0 until a.length()).map {
            val o = a.getJSONObject(it)
            BankEntry(
                o.optString("key"),
                o.optString("text"),
                o.optString("sender"),
                o.optLong("postedAt"),
                o.optString("package"),
            )
        }
    }

    fun entry(context: Context, key: String): BankEntry? =
        entries(context).firstOrNull { it.key == key }

    /** Adds the messages not seen before; returns those. */
    @Synchronized
    fun add(context: Context, fresh: List<BankEntry>): List<BankEntry> {
        val current = entries(context)
        val known = current.map { it.key }.toHashSet()
        val added = fresh.filter { known.add(it.key) }
        if (added.isEmpty()) return added
        writeEntries(context, (added + current).sortedByDescending { it.postedAt }.take(MAX))
        onChange?.invoke()
        return added
    }

    private fun writeEntries(context: Context, list: List<BankEntry>) {
        val out = JSONArray()
        for (e in list) {
            out.put(
                JSONObject()
                    .put("key", e.key)
                    .put("text", e.text)
                    .put("sender", e.sender)
                    .put("postedAt", e.postedAt)
                    .put("package", e.pkg)
            )
        }
        file(context, LOG).writeText(out.toString())
    }

    // ---------------- Formats ----------------

    @Synchronized
    fun formats(context: Context): List<BankMessageReader.BankFormat> {
        val a = readArray(context, FORMATS)
        return (0 until a.length()).map {
            val o = a.getJSONObject(it)
            BankMessageReader.BankFormat(
                skeleton = o.optString("skeleton"),
                runIndex = o.optInt("runIndex", -1),
                before = o.optString("before"),
                after = o.optString("after"),
                kind = o.optString("kind"),
                rialPerUnit = o.optInt("rialPerUnit", 1),
                createdAt = o.optLong("createdAt"),
                name = o.optString("name"),
            )
        }
    }

    /** Saves [f], replacing an earlier format with the same layout. */
    @Synchronized
    fun addFormat(context: Context, f: BankMessageReader.BankFormat) =
        writeFormats(context, formats(context).filter { it.skeleton != f.skeleton } + f)

    /** Forgets the format laid out as [skeleton] (its messages are unknown
     *  again, or read again if it was an "ignore"). */
    @Synchronized
    fun deleteFormat(context: Context, skeleton: String) =
        writeFormats(context, formats(context).filter { it.skeleton != skeleton })

    /** Changes [skeleton]'s name, which way its amounts go and their unit,
     *  in place. */
    @Synchronized
    fun updateFormat(
        context: Context,
        skeleton: String,
        kind: String,
        rialPerUnit: Int,
        name: String,
    ) = writeFormats(context, formats(context).map {
        if (it.skeleton == skeleton) {
            it.copy(kind = kind, rialPerUnit = rialPerUnit, name = name.trim())
        } else {
            it
        }
    })

    private fun writeFormats(context: Context, list: List<BankMessageReader.BankFormat>) {
        val out = JSONArray()
        for (x in list) {
            out.put(
                JSONObject()
                    .put("skeleton", x.skeleton)
                    .put("runIndex", x.runIndex)
                    .put("before", x.before)
                    .put("after", x.after)
                    .put("kind", x.kind)
                    .put("rialPerUnit", x.rialPerUnit)
                    .put("createdAt", x.createdAt)
                    .put("name", x.name)
            )
        }
        file(context, FORMATS).writeText(out.toString())
    }

    fun read(context: Context, e: BankEntry) = BankMessageReader.read(e.text, formats(context))

    // ---------------- Ignored senders ----------------

    private fun senderKey(s: String) = s.trim().lowercase()

    @Synchronized
    fun ignoredSenders(context: Context): List<String> {
        val a = readArray(context, SENDERS)
        return (0 until a.length()).map { a.optString(it) }.filter { it.isNotBlank() }
    }

    /** Keys of the ignored senders, for [isIgnored]. */
    fun ignoredSenderKeys(context: Context): Set<String> =
        ignoredSenders(context).map(::senderKey).toSet()

    fun isIgnored(e: BankEntry, keys: Set<String>) = senderKey(e.sender) in keys

    @Synchronized
    fun setSenderIgnored(context: Context, sender: String, ignored: Boolean) {
        if (sender.isBlank()) return
        val k = senderKey(sender)
        val rest = ignoredSenders(context).filter { senderKey(it) != k }
        val out = JSONArray()
        for (s in if (ignored) rest + sender.trim() else rest) out.put(s)
        file(context, SENDERS).writeText(out.toString())
    }

    // ---------------- Seen from the notification ----------------

    /** [key] marked seen by its notification's button (the app may not be
     *  running; it takes these on its next read). */
    @Synchronized
    fun markSeen(context: Context, key: String) {
        val a = readArray(context, SEEN)
        if ((0 until a.length()).any { a.optString(it) == key }) return
        file(context, SEEN).writeText(a.put(key).toString())
    }

    /** The keys marked seen natively since the last call (then cleared). */
    @Synchronized
    fun takeSeen(context: Context): List<String> {
        val a = readArray(context, SEEN)
        file(context, SEEN).delete()
        return (0 until a.length()).map { a.optString(it) }.filter { it.isNotBlank() }
    }

    // ---------------- Backup ----------------

    @Synchronized
    fun exportJson(context: Context): Map<String, String> = mapOf(
        "formats" to readArray(context, FORMATS).toString(),
        "messages" to readArray(context, LOG).toString(),
        "ignoredSenders" to readArray(context, SENDERS).toString(),
    )

    /** Replaces the files with a backup's (each only if given and it parses). */
    @Synchronized
    fun importJson(context: Context, formats: String?, messages: String?, senders: String?) {
        for ((json, name) in listOf(formats to FORMATS, messages to LOG, senders to SENDERS)) {
            json?.let { runCatching { JSONArray(it) }.getOrNull() }
                ?.let { file(context, name).writeText(it.toString()) }
        }
    }
}

/** The Flutter app's settings, read natively (shared_preferences' file). */
object AppPrefs {
    private fun prefs(context: Context) =
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

    fun isFa(context: Context) = prefs(context).getString("flutter.locale", "fa") != "en"

    fun currency(context: Context): String =
        prefs(context).getString("flutter.currency", "IRT") ?: "IRT"

    /** Post our own notification for bank messages: the SMS tab is on and
     *  the user turned notifications on (off until then). */
    fun notifyBankMessages(context: Context): Boolean {
        val p = prefs(context)
        return p.getBoolean("flutter.tabSms", false) && p.getBoolean("flutter.bankNotify", false)
    }
}
