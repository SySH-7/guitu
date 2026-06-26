package com.sysh.guitu

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "guitu/storage"
    private val importRequestCode = 4101
    private val exportRequestCode = 4102
    private val storagePermissionRequestCode = 4103
    private val preferenceName = "guitu_preferences"
    private val documentAccessNoticeKeyPrefix = "document_access_notice_seen"
    private var pendingResult: MethodChannel.Result? = null
    private var pendingExportData: String? = null
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingPermissionNames: List<String> = emptyList()

    private val snapshotFile: File
        get() = File(filesDir, "guitu_archive_snapshot.json")

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "readSnapshot" -> readSnapshot(result)
                "writeSnapshot" -> writeSnapshot(call, result)
                "importSnapshot" -> importSnapshot(result)
                "exportSnapshot" -> exportSnapshot(call, result)
                "hasSeenDocumentAccessNotice" -> hasSeenDocumentAccessNotice(call, result)
                "markDocumentAccessNoticeSeen" -> markDocumentAccessNoticeSeen(call, result)
                "requestDocumentAccess" -> requestDocumentAccess(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun readSnapshot(result: MethodChannel.Result) {
        try {
            result.success(if (snapshotFile.exists()) snapshotFile.readText(Charsets.UTF_8) else null)
        } catch (error: Exception) {
            result.error("READ_FAILED", error.message, null)
        }
    }

    private fun writeSnapshot(call: MethodCall, result: MethodChannel.Result) {
        try {
            val data = call.argument<String>("data") ?: ""
            snapshotFile.parentFile?.mkdirs()
            snapshotFile.writeText(data, Charsets.UTF_8)
            result.success(null)
        } catch (error: Exception) {
            result.error("WRITE_FAILED", error.message, null)
        }
    }

    private fun hasSeenDocumentAccessNotice(call: MethodCall, result: MethodChannel.Result) {
        val key = documentAccessNoticeKey(call)
        val preferences = getSharedPreferences(preferenceName, MODE_PRIVATE)
        result.success(preferences.getBoolean(key, false))
    }

    private fun markDocumentAccessNoticeSeen(call: MethodCall, result: MethodChannel.Result) {
        val key = documentAccessNoticeKey(call)
        getSharedPreferences(preferenceName, MODE_PRIVATE)
            .edit()
            .putBoolean(key, true)
            .apply()
        result.success(null)
    }

    private fun documentAccessNoticeKey(call: MethodCall): String {
        val action = call.argument<String>("action") ?: "general"
        return "${documentAccessNoticeKeyPrefix}_$action"
    }

    private fun requestDocumentAccess(result: MethodChannel.Result) {
        if (pendingPermissionResult != null) {
            result.error("BUSY", "A permission request is already running.", null)
            return
        }

        val permissions = requiredDocumentPermissions()
        if (permissions.isEmpty() || permissions.all { checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED }) {
            result.success(permissionPayload(granted = true, systemDialogShown = false, permanentlyDenied = false))
            return
        }

        pendingPermissionResult = result
        pendingPermissionNames = permissions
        requestPermissions(permissions.toTypedArray(), storagePermissionRequestCode)
    }

    private fun requiredDocumentPermissions(): List<String> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return emptyList()
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            return emptyList()
        }
        val permissions = mutableListOf(Manifest.permission.READ_EXTERNAL_STORAGE)
        if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.P) {
            permissions.add(Manifest.permission.WRITE_EXTERNAL_STORAGE)
        }
        return permissions
    }

    private fun permissionPayload(
        granted: Boolean,
        systemDialogShown: Boolean,
        permanentlyDenied: Boolean,
    ): Map<String, Any> {
        return mapOf(
            "granted" to granted,
            "systemDialogShown" to systemDialogShown,
            "permanentlyDenied" to permanentlyDenied,
            "sdkInt" to Build.VERSION.SDK_INT,
        )
    }

    private fun importSnapshot(result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("BUSY", "A document action is already running.", null)
            return
        }
        pendingResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(
                Intent.EXTRA_MIME_TYPES,
                arrayOf("application/json", "text/json", "text/plain", "application/octet-stream"),
            )
        }
        startActivityForResult(intent, importRequestCode)
    }

    private fun exportSnapshot(call: MethodCall, result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("BUSY", "A document action is already running.", null)
            return
        }
        pendingResult = result
        pendingExportData = call.argument<String>("data") ?: ""
        val fileName = call.argument<String>("fileName") ?: "guitu_export.json"
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/json"
            putExtra(Intent.EXTRA_TITLE, fileName)
        }
        startActivityForResult(intent, exportRequestCode)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            importRequestCode -> finishImport(resultCode, data?.data)
            exportRequestCode -> finishExport(resultCode, data?.data)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (requestCode == storagePermissionRequestCode) {
            val result = pendingPermissionResult ?: return
            val requestedPermissions = pendingPermissionNames
            pendingPermissionResult = null
            pendingPermissionNames = emptyList()

            val granted = grantResults.isNotEmpty() &&
                grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            val permanentlyDenied = !granted && requestedPermissions.any {
                !shouldShowRequestPermissionRationale(it)
            }
            result.success(
                permissionPayload(
                    granted = granted,
                    systemDialogShown = true,
                    permanentlyDenied = permanentlyDenied,
                ),
            )
            return
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    private fun finishImport(resultCode: Int, uri: Uri?) {
        val result = pendingResult ?: return
        pendingResult = null
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        try {
            val text = contentResolver.openInputStream(uri)?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }
            result.success(text)
        } catch (error: Exception) {
            result.error("IMPORT_FAILED", error.message, null)
        }
    }

    private fun finishExport(resultCode: Int, uri: Uri?) {
        val result = pendingResult ?: return
        val data = pendingExportData ?: ""
        pendingResult = null
        pendingExportData = null
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        try {
            contentResolver.openOutputStream(uri)?.bufferedWriter(Charsets.UTF_8)?.use { it.write(data) }
            result.success(uri.toString())
        } catch (error: Exception) {
            result.error("EXPORT_FAILED", error.message, null)
        }
    }
}
