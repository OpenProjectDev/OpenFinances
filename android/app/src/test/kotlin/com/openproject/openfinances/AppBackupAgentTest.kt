package com.openproject.openfinances

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** The backup switch's rule (developer, 2026-11-08). Flag values as in
 *  android.app.backup.BackupAgent: encrypted 1, device-to-device 2. */
class AppBackupAgentTest {
    private val encrypted = 1
    private val d2d = 2

    @Test fun offTakesNothing() {
        for (f in listOf(null, 0, encrypted, d2d, encrypted or d2d)) {
            assertFalse(AppBackupAgent.backupAllowed(false, f))
        }
    }

    @Test fun onTakesEncryptedCloudAndPhoneToPhone() {
        assertTrue(AppBackupAgent.backupAllowed(true, encrypted))
        assertTrue(AppBackupAgent.backupAllowed(true, d2d))
        assertTrue(AppBackupAgent.backupAllowed(true, encrypted or d2d))
    }

    @Test fun onNeverTakesAnUnencryptedCloudBackup() {
        assertFalse(AppBackupAgent.backupAllowed(true, 0))
        assertFalse(AppBackupAgent.backupAllowed(true, null))
    }
}
