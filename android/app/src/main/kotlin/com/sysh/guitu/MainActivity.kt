package com.sysh.guitu

import android.app.Activity
import android.content.Intent
import android.net.Uri
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
    private var pendingResult: MethodChannel.Result? = null
    private var pendingExportData: String? = null

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

    private fun importSnapshot(result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("BUSY", "A document action is already running.", null)
            return
        }
        pendingResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/json"
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
