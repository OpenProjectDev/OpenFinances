package com.openproject.openfinances

import android.Manifest
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.provider.Settings
import android.view.WindowInsets
import android.view.WindowInsetsAnimationControlListener
import android.view.WindowInsetsAnimationController
import android.view.inputmethod.InputMethodManager
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.install.InstallException
import com.google.android.play.core.install.model.InstallErrorCode
import com.google.android.play.core.install.model.UpdateAvailability
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.IOException

class MainActivity : FlutterFragmentActivity() {

    // Asks the Play Store, which does the network part: the app itself has no
    // INTERNET permission. "notPlay", "upToDate", "available" or "failed".
    private fun checkForUpdate(result: MethodChannel.Result) {
        val installer = try {
            if (Build.VERSION.SDK_INT >= 30) {
                packageManager.getInstallSourceInfo(packageName).installingPackageName
            } else {
                @Suppress("DEPRECATION")
                packageManager.getInstallerPackageName(packageName)
            }
        } catch (e: Exception) {
            null
        }
        if (installer != "com.android.vending") {
            result.success("notPlay")
            return
        }
        AppUpdateManagerFactory.create(this).appUpdateInfo
            .addOnSuccessListener { info ->
                result.success(
                    when (info.updateAvailability()) {
                        UpdateAvailability.UPDATE_AVAILABLE,
                        UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS -> "available"
                        UpdateAvailability.UPDATE_NOT_AVAILABLE -> "upToDate"
                        else -> "failed"
                    },
                )
            }
            .addOnFailureListener { e ->
                // Play no longer lists it for this account: nothing newer to get.
                val gone = e is InstallException &&
                    e.errorCode == InstallErrorCode.ERROR_APP_NOT_OWNED
                result.success(if (gone) "upToDate" else "failed")
            }
    }

    private val CHANNEL = "openfinances/downloads"
    private val REQ_WRITE = 1002

    // Backups' folder (Settings > Backup), picked with the system's folder
    // picker; its access is kept across restarts.
    private val REQ_FOLDER = 1006
    private var pendingFolder: MethodChannel.Result? = null

    // Bank messages read from the messaging app's notifications
    // (BankNotificationListener); no SMS permission involved.
    private val BANK_CHANNEL = "openfinances/bank_notifications"
    private val REQ_NOTIFY = 1004
    private var pendingNotifyPermission: MethodChannel.Result? = null

    // An "Add" tapped on our bank-message notification, until Dart takes it.
    private var pendingAdd: Map<String, Any?>? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        handleBankIntent(intent)
        holdSplash()
    }

    // The Android 12+ splash, held when it would leave until the app has drawn
    // the very same picture under it (lib/app/branding_screen.dart): the system
    // draws the splash icon at a size of its own choosing, so the app asks where
    // the logo's plate really is ("splashPlate") and says when it's drawn there
    // ("splashDone").
    private var splashView: android.view.View? = null
    private var splashPlate: Map<String, Int>? = null
    private var splashMeasured = false
    private var pendingPlate: MethodChannel.Result? = null

    private fun holdSplash() {
        if (Build.VERSION.SDK_INT < 31) return
        splashScreen.setOnExitAnimationListener { view ->
            splashView = view
            splashPlate = try { measurePlate(view) } catch (e: Exception) { null }
            splashMeasured = true
            pendingPlate?.success(splashPlate)
            pendingPlate = null
            // Never stuck: gone after 2 s whatever the app does.
            view.postDelayed({ removeSplash() }, 2000)
        }
    }

    private fun removeSplash() {
        if (Build.VERSION.SDK_INT < 31) return
        (splashView as? android.window.SplashScreenView)?.remove()
        splashView = null
    }

    /** The logo's plate on the splash (its color, kBrandPlate #303237), in
     *  pixels from the app's content view's top-left; null if not found. */
    private fun measurePlate(view: android.view.View): Map<String, Int>? {
        val w = view.width
        val h = view.height
        if (w <= 0 || h <= 0) return null
        val bmp = android.graphics.Bitmap.createBitmap(w, h, android.graphics.Bitmap.Config.ARGB_8888)
        view.draw(android.graphics.Canvas(bmp))
        val px = IntArray(w * h)
        bmp.getPixels(px, 0, w, 0, 0, w, h)
        bmp.recycle()
        // The plate's color, give or take. Letters' soft edges pass through
        // it too, but only the plate makes long unbroken runs of it: its
        // top and bottom rows and its side columns (the leaf is inside).
        fun plate(c: Int) =
            Math.abs(((c shr 16) and 0xFF) - 0x30) <= 3 &&
                Math.abs(((c shr 8) and 0xFF) - 0x32) <= 3 &&
                Math.abs((c and 0xFF) - 0x37) <= 3
        val rowRun = IntArray(h)
        val colRun = IntArray(w)
        val colCur = IntArray(w)
        for (y in 0 until h) {
            var cur = 0
            val row = y * w
            for (x in 0 until w) {
                if (plate(px[row + x])) {
                    cur++
                    if (cur > rowRun[y]) rowRun[y] = cur
                    colCur[x]++
                    if (colCur[x] > colRun[x]) colRun[x] = colCur[x]
                } else {
                    cur = 0
                    colCur[x] = 0
                }
            }
        }
        val maxRow = rowRun.maxOrNull() ?: 0
        val maxCol = colRun.maxOrNull() ?: 0
        if (maxRow < 16 || maxCol < 16) return null
        val t = rowRun.indexOfFirst { it * 2 >= maxRow }
        val b = rowRun.indexOfLast { it * 2 >= maxRow }
        val l = colRun.indexOfFirst { it * 2 >= maxCol }
        val r = colRun.indexOfLast { it * 2 >= maxCol }
        if (t < 0 || l < 0 || r - l < 16) return null
        val at = IntArray(2)
        view.getLocationInWindow(at)
        val content = IntArray(2)
        findViewById<android.view.View>(android.R.id.content)?.getLocationInWindow(content)
        return mapOf(
            "l" to l + at[0] - content[0],
            "t" to t + at[1] - content[1],
            "w" to r - l + 1,
            "h" to b - t + 1,
        )
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleBankIntent(intent)
    }

    /** Our notification, tapped: "Add" (a defined format) hands the entry
     *  to the add sheet; "Define format" opens the define-format sheet. */
    private fun handleBankIntent(intent: Intent?) {
        val action = intent?.getStringExtra(BankTxnNotifier.EXTRA_ACTION) ?: return
        val key = intent.getStringExtra(BankTxnNotifier.EXTRA_KEY) ?: return
        intent.removeExtra(BankTxnNotifier.EXTRA_ACTION) // once only
        BankTxnNotifier.cancel(this, key)
        if (action == BankTxnNotifier.ACTION_DEFINE) {
            pendingAdd = mapOf("action" to "define", "key" to key)
            return
        }
        if (action != BankTxnNotifier.ACTION_ADD) return
        val kind = intent.getStringExtra(BankTxnNotifier.EXTRA_KIND) ?: "EXPENSE"
        val amount = intent.getLongExtra(BankTxnNotifier.EXTRA_AMOUNT, 0)
        val unit = intent.getStringExtra(BankTxnNotifier.EXTRA_UNIT) ?: "IRR"
        pendingAdd = mapOf(
            "action" to "add",
            "key" to key,
            "kind" to if (kind == "INCOME") "income" else "expense",
            // Recorded as the bank sent it: rounded, in its own unit.
            "amount" to amount,
            "unit" to unit,
            "postedAt" to intent.getLongExtra(BankTxnNotifier.EXTRA_POSTED, 0),
        )
    }

    private fun confirmReading(
        key: String,
        run: Int,
        kind: String,
        unit: String,
        name: String = "",
    ) {
        BankTxnNotifier.cancel(this, key)
        val e = BankStore.entry(this, key) ?: return
        val k = if (kind == "INCOME") BankMessageReader.Kind.INCOME else BankMessageReader.Kind.EXPENSE
        val guess = BankMessageReader.Guess(0, unit, k, run, -1, -1)
        BankStore.addFormat(
            this,
            BankMessageReader.learn(e.text, guess, System.currentTimeMillis())
                .copy(name = name.trim()),
        )
    }

    // Keyboard restore: Android hides the IME when our window loses focus and,
    // since FlutterView doesn't report itself as a text editor, won't bring it
    // back. We remember it was open and re-show it ourselves, skipping the
    // slide-in animation where the platform allows it (API 30+).
    //
    // The flag stays set until the keyboard is actually seen open again: on
    // return from Recents the biometric prompt can grab focus right after we
    // re-show it, hiding it again — the next focus gain retries.
    private var imeRestorePending = false

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return
        val decor = window.decorView
        if (!hasFocus) {
            // Only ever SET here: a prompt appearing before the keyboard came
            // back must not wipe the pending restore.
            if (decor.rootWindowInsets?.isVisible(WindowInsets.Type.ime()) == true) {
                imeRestorePending = true
            }
            return
        }
        if (!imeRestorePending) return
        // Post so the system has re-attached input to our window first.
        decor.post { showImeInstantly() }
        // Settle: if it's open (or we still have focus and it isn't coming,
        // e.g. no text field is focused any more), stop retrying. If focus
        // moved away again (biometric prompt), keep it pending.
        decor.postDelayed({
            if (!hasWindowFocus()) return@postDelayed
            imeRestorePending = false
        }, 600)
    }

    private fun showImeInstantly() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return
        val target = currentFocus ?: window.decorView
        val controller = target.windowInsetsController ?: return
        controller.controlWindowInsetsAnimation(
            WindowInsets.Type.ime(),
            0,
            null,
            null,
            object : WindowInsetsAnimationControlListener {
                override fun onReady(c: WindowInsetsAnimationController, types: Int) {
                    c.finish(true) // jump straight to "shown"
                }

                override fun onFinished(c: WindowInsetsAnimationController) {}

                override fun onCancelled(c: WindowInsetsAnimationController?) {
                    // Couldn't take control — fall back to a normal show.
                    val imm = getSystemService(INPUT_METHOD_SERVICE) as InputMethodManager
                    imm.showSoftInput(target, 0)
                }
            }
        )
    }

    private var pendingResult: MethodChannel.Result? = null
    private var pendingFileName: String? = null
    private var pendingMimeType: String? = null
    private var pendingBytes: ByteArray? = null

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        BankStore.onChange = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "save") {
                    val fileName = call.argument<String>("fileName")
                    val mimeType = call.argument<String>("mimeType")
                    val bytes = call.argument<ByteArray>("bytes")

                    if (fileName == null || mimeType == null || bytes == null) {
                        result.error("BAD_ARGS", "Missing fileName/mimeType/bytes", null)
                        return@setMethodCallHandler
                    }

                    // Into the folder the user picked (no storage permission
                    // needed: the picker granted it).
                    val folder = call.argument<String>("folder")
                    if (folder != null) {
                        try {
                            val uri = saveToFolder(Uri.parse(folder), fileName, mimeType, bytes)
                            result.success(uri.toString())
                        } catch (e: Exception) {
                            result.error("SAVE_FAILED", e.message, null)
                        }
                        return@setMethodCallHandler
                    }

                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                        // Android 9 and below need WRITE_EXTERNAL_STORAGE to write to Downloads
                        val granted = ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.WRITE_EXTERNAL_STORAGE
                        ) == PackageManager.PERMISSION_GRANTED

                        if (!granted) {
                            pendingResult = result
                            pendingFileName = fileName
                            pendingMimeType = mimeType
                            pendingBytes = bytes
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                                REQ_WRITE
                            )
                            return@setMethodCallHandler
                        }
                    }

                    try {
                        val uri = saveToDownloads(fileName, mimeType, bytes)
                        result.success(uri.toString())
                    } catch (e: Exception) {
                        result.error("SAVE_FAILED", e.message, null)
                    }
                } else if (call.method == "pickFolder") {
                    // {uri, name} of the folder picked; null: none.
                    if (pendingFolder != null) {
                        result.error("BUSY", "A folder is being picked", null)
                        return@setMethodCallHandler
                    }
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                        addFlags(
                            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
                        )
                        // Opens where the current one is.
                        val current = call.argument<String>("current")
                        if (current != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            try {
                                val tree = Uri.parse(current)
                                putExtra(
                                    DocumentsContract.EXTRA_INITIAL_URI,
                                    DocumentsContract.buildDocumentUriUsingTree(
                                        tree, DocumentsContract.getTreeDocumentId(tree)
                                    )
                                )
                            } catch (_: Exception) {}
                        }
                    }
                    pendingFolder = result
                    try {
                        @Suppress("DEPRECATION")
                        startActivityForResult(intent, REQ_FOLDER)
                    } catch (e: Exception) {
                        pendingFolder = null
                        result.error("NO_PICKER", e.message, null)
                    }
                } else if (call.method == "hasFolderAccess") {
                    // A folder restored from a backup comes without its access.
                    val uri = call.argument<String>("uri")
                    result.success(
                        contentResolver.persistedUriPermissions.any {
                            it.uri.toString() == uri && it.isWritePermission
                        }
                    )
                } else if (call.method == "releaseFolder") {
                    // The folder is no longer used: its access goes.
                    val uri = call.argument<String>("uri")
                    if (uri != null) {
                        try {
                            contentResolver.releasePersistableUriPermission(
                                Uri.parse(uri),
                                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                            )
                        } catch (_: Exception) {}
                    }
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }

        // App facts for the Settings header.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "openfinances/app")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Settings > About: installed from Play? Is there a newer version?
                    "checkUpdate" -> checkForUpdate(result)
                    "version" -> {
                        val info = packageManager.getPackageInfo(packageName, 0)
                        val code = if (Build.VERSION.SDK_INT >= 28) info.longVersionCode
                        else @Suppress("DEPRECATION") info.versionCode.toLong()
                        result.success("${info.versionName}+$code") // e.g. 1.0.6+10
                    }
                    // Where the splash's plate is (null: no splash to match);
                    // answered once the splash is about to leave.
                    "splashPlate" -> when {
                        Build.VERSION.SDK_INT < 31 -> result.success(null)
                        splashMeasured -> result.success(splashPlate)
                        else -> pendingPlate = result
                    }
                    "splashDone" -> {
                        removeSplash()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        val bankChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BANK_CHANNEL)
        // A message captured while the app is open: the SMS page reloads.
        val main = android.os.Handler(android.os.Looper.getMainLooper())
        BankStore.onChange = { main.post { bankChannel.invokeMethod("changed", null) } }
        bankChannel
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasAccess" -> result.success(BankNotificationListener.hasAccess(this))
                    "openAccessSettings" -> {
                        // Straight to this app's switch where the system
                        // allows it (API 30+), else the list of apps.
                        val detail = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS)
                                .putExtra(
                                    Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME,
                                    BankNotificationListener.component(this).flattenToString()
                                )
                        } else null
                        try {
                            startActivity(detail ?: Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                        } catch (_: Exception) {
                            startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                        }
                        result.success(null)
                    }
                    "takeSeen" -> result.success(BankStore.takeSeen(this))
                    "readLog" -> {
                        val formats = BankStore.formats(this)
                        val ignored = BankStore.ignoredSenderKeys(this)
                        result.success(BankStore.entries(this).map { e ->
                            val r = BankMessageReader.read(e.text, formats)
                            mapOf(
                                "key" to e.key,
                                "text" to e.text,
                                "sender" to e.sender,
                                "postedAt" to e.postedAt,
                                "status" to r.status.name.lowercase(),
                                "senderIgnored" to BankStore.isIgnored(e, ignored),
                                // The defined (or ignored) layout it matches.
                                "format" to BankMessageReader.formatFor(e.text, formats)?.skeleton,
                                "guesses" to r.guesses.map { g ->
                                    mapOf(
                                        "amount" to g.amount,
                                        "unit" to g.unit,
                                        "kind" to g.kind.name.lowercase(),
                                        "runIndex" to g.runIndex,
                                        "start" to g.start,
                                        "end" to g.end,
                                    )
                                },
                            )
                        })
                    }
                    "confirm" -> {
                        confirmReading(
                            call.argument<String>("key") ?: "",
                            call.argument<Int>("runIndex") ?: -1,
                            if (call.argument<String>("kind") == "income") "INCOME" else "EXPENSE",
                            call.argument<String>("unit") ?: "IRR",
                            call.argument<String>("name") ?: "",
                        )
                        result.success(null)
                    }
                    "ignore" -> {
                        val key = call.argument<String>("key") ?: ""
                        BankStore.entry(this, key)?.let {
                            BankStore.addFormat(
                                this,
                                BankMessageReader.ignoreFormat(it.text, System.currentTimeMillis()),
                            )
                        }
                        BankTxnNotifier.cancel(this, key)
                        result.success(null)
                    }
                    "listFormats" -> {
                        val entries = BankStore.entries(this)
                        val formats = BankStore.formats(this)
                        result.success(formats.map { f ->
                            val mine = entries.filter {
                                BankMessageReader.formatFor(it.text, formats)?.skeleton == f.skeleton
                            }
                            mapOf(
                                "skeleton" to f.skeleton,
                                "name" to f.name,
                                "kind" to f.kind,
                                "unit" to if (f.rialPerUnit == 10) "IRT" else "IRR",
                                "createdAt" to f.createdAt,
                                "count" to mine.size,
                                "sender" to mine.firstOrNull()?.sender,
                                "example" to mine.firstOrNull()?.text,
                            )
                        })
                    }
                    "updateFormat" -> {
                        BankStore.updateFormat(
                            this,
                            call.argument<String>("skeleton") ?: "",
                            call.argument<String>("kind") ?: "expense",
                            if (call.argument<String>("unit") == "IRT") 10 else 1,
                            call.argument<String>("name") ?: "",
                        )
                        result.success(null)
                    }
                    "deleteFormat" -> {
                        BankStore.deleteFormat(this, call.argument<String>("skeleton") ?: "")
                        result.success(null)
                    }
                    "setSenderIgnored" -> {
                        val sender = call.argument<String>("sender") ?: ""
                        val ignored = call.argument<Boolean>("ignored") ?: true
                        BankStore.setSenderIgnored(this, sender, ignored)
                        result.success(null)
                    }
                    "takePendingAdd" -> {
                        result.success(pendingAdd)
                        pendingAdd = null
                    }
                    "canPostNotifications" -> result.success(
                        NotificationManagerCompat.from(this).areNotificationsEnabled()
                    )
                    "requestPostNotifications" -> {
                        val needsAsk = Build.VERSION.SDK_INT >= 33 &&
                            ContextCompat.checkSelfPermission(
                                this, Manifest.permission.POST_NOTIFICATIONS
                            ) != PackageManager.PERMISSION_GRANTED
                        if (!needsAsk) {
                            result.success(NotificationManagerCompat.from(this).areNotificationsEnabled())
                        } else {
                            pendingNotifyPermission?.success(false)
                            pendingNotifyPermission = result
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                REQ_NOTIFY
                            )
                        }
                    }
                    "openNotificationSettings" -> {
                        val i = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                        } else {
                            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                                .setData(Uri.fromParts("package", packageName, null))
                        }
                        try {
                            startActivity(i)
                        } catch (_: Exception) {
                        }
                        result.success(null)
                    }
                    "exportData" -> result.success(BankStore.exportJson(this))
                    "importData" -> {
                        BankStore.importJson(
                            this,
                            call.argument<String>("formats"),
                            call.argument<String>("messages"),
                            call.argument<String>("ignoredSenders"),
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQ_FOLDER) return
        val res = pendingFolder ?: return
        pendingFolder = null
        val tree = data?.data
        if (resultCode != RESULT_OK || tree == null) {
            res.success(null)
            return
        }
        try {
            contentResolver.takePersistableUriPermission(
                tree,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            )
            res.success(mapOf("uri" to tree.toString(), "name" to folderName(tree)))
        } catch (e: Exception) {
            res.error("NO_ACCESS", e.message, null)
        }
    }

    /** A picked folder's name, as the Files app shows it. */
    private fun folderName(tree: Uri): String {
        val id = DocumentsContract.getTreeDocumentId(tree)
        try {
            val doc = DocumentsContract.buildDocumentUriUsingTree(tree, id)
            contentResolver.query(
                doc, arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME), null, null, null
            )?.use { c ->
                if (c.moveToFirst()) c.getString(0)?.let { if (it.isNotBlank()) return it }
            }
        } catch (_: Exception) {}
        return id.substringAfterLast('/').substringAfter(':').ifBlank { id }
    }

    @Throws(IOException::class)
    private fun saveToFolder(tree: Uri, fileName: String, mimeType: String, bytes: ByteArray): Uri {
        val parent = DocumentsContract.buildDocumentUriUsingTree(
            tree, DocumentsContract.getTreeDocumentId(tree)
        )
        val doc = DocumentsContract.createDocument(contentResolver, parent, mimeType, fileName)
            ?: throw IOException("Failed to create the file")
        contentResolver.openOutputStream(doc)?.use { out ->
            out.write(bytes)
            out.flush()
        } ?: throw IOException("Failed to open output stream")
        return doc
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode == REQ_NOTIFY) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingNotifyPermission?.success(granted)
            pendingNotifyPermission = null
            return
        }

        if (requestCode == REQ_WRITE) {
            val res = pendingResult
            val fileName = pendingFileName
            val mimeType = pendingMimeType
            val bytes = pendingBytes

            pendingResult = null
            pendingFileName = null
            pendingMimeType = null
            pendingBytes = null

            if (res == null || fileName == null || mimeType == null || bytes == null) return

            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                try {
                    val uri = saveToDownloads(fileName, mimeType, bytes)
                    res.success(uri.toString())
                } catch (e: Exception) {
                    res.error("SAVE_FAILED", e.message, null)
                }
            } else {
                res.error("PERMISSION_DENIED", "WRITE_EXTERNAL_STORAGE denied", null)
            }
        }
    }

    @Throws(IOException::class)
    private fun saveToDownloads(fileName: String, mimeType: String, bytes: ByteArray): Uri {
        val resolver = applicationContext.contentResolver

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Android 10+ (scoped storage): use MediaStore Downloads
            val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, mimeType)
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val item = resolver.insert(collection, values)
                ?: throw IOException("Failed to create MediaStore entry")

            resolver.openOutputStream(item)?.use { out ->
                out.write(bytes)
                out.flush()
            } ?: throw IOException("Failed to open output stream")

            val publish = ContentValues().apply {
                put(MediaStore.Downloads.IS_PENDING, 0)
            }
            resolver.update(item, publish, null, null)
            item
        } else {
            // Android 9 and below: write directly to public Downloads (needs permission)
            val downloadsDir =
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            if (!downloadsDir.exists()) downloadsDir.mkdirs()

            val outFile = File(downloadsDir, fileName)
            FileOutputStream(outFile).use { fos ->
                fos.write(bytes)
                fos.flush()
            }

            // Index so it appears immediately in Downloads apps
            MediaScannerConnection.scanFile(
                this,
                arrayOf(outFile.absolutePath),
                arrayOf(mimeType),
                null
            )

            Uri.fromFile(outFile)
        }
    }
}
