package com.openproject.openfinances

import android.app.backup.BackupAgent
import android.app.backup.BackupAgent.FLAG_CLIENT_SIDE_ENCRYPTION_ENABLED
import android.app.backup.BackupAgent.FLAG_DEVICE_TO_DEVICE_TRANSFER
import android.app.backup.BackupDataInput
import android.app.backup.BackupDataOutput
import android.app.backup.FullBackupDataOutput
import android.os.Build
import android.os.ParcelFileDescriptor

/**
 * Android's own backup of the app's data, behind Settings > Data's
 * "Encrypted Android backup" (developer, 2026-11-08), off by default:
 * - off: nothing goes, to Google or to a new phone (the pass writes an
 *   empty backup, and Android keeps only the latest one);
 * - on: a phone-to-phone transfer goes; to Google, only when Android
 *   encrypts it end to end (a screen lock, Android 9+), so Google can't
 *   read it.
 *
 * Runs without Flutter (Android's restricted mode: no plugins, maybe the
 * app not running), so it reads the switch from the prefs file
 * shared_preferences writes: `FlutterSharedPreferences`, the key with
 * Dart's `flutter.` prefix (SettingsProvider.kAndroidBackup).
 * Restores are Android's default: a backup made while the switch was on
 * comes back on reinstall.
 */
class AppBackupAgent : BackupAgent() {
    override fun onFullBackup(data: FullBackupDataOutput) {
        if (allowed(data)) super.onFullBackup(data)
    }

    private fun allowed(data: FullBackupDataOutput): Boolean {
        val on = getSharedPreferences(PREFS, MODE_PRIVATE).getBoolean(SWITCH, false)
        // Transport flags came with Android 9.
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) data.transportFlags else null
        return backupAllowed(on, flags)
    }

    // Key-value backup: unused (fullBackupOnly in the manifest).
    override fun onBackup(
        oldState: ParcelFileDescriptor?,
        data: BackupDataOutput?,
        newState: ParcelFileDescriptor?,
    ) {}

    override fun onRestore(
        data: BackupDataInput?,
        appVersionCode: Int,
        newState: ParcelFileDescriptor?,
    ) {}

    companion object {
        const val PREFS = "FlutterSharedPreferences"
        const val SWITCH = "flutter.androidBackup"

        /**
         * Whether a pass may take the app's data: the switch on, and a
         * phone-to-phone transfer or an end-to-end encrypted one. No [flags]
         * (before Android 9): nothing is known about encryption, so no.
         */
        fun backupAllowed(on: Boolean, flags: Int?): Boolean {
            if (!on || flags == null) return false
            return flags and FLAG_DEVICE_TO_DEVICE_TRANSFER != 0 ||
                flags and FLAG_CLIENT_SIDE_ENCRYPTION_ENABLED != 0
        }
    }
}
