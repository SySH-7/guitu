package com.sysh.guitu

import android.Manifest
import android.app.Activity
import android.content.ContentUris
import android.content.Intent
import android.content.pm.PackageManager
import android.database.Cursor
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import androidx.exifinterface.media.ExifInterface
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val channelName = "guitu/storage"
    private val deviceEntryChannelName = "guitu/device_entry"
    private val photoScanEventChannelName = "guitu/photo_scan_events"
    private val importRequestCode = 4101
    private val exportRequestCode = 4102
    private val storagePermissionRequestCode = 4103
    private val locationPermissionRequestCode = 4104
    private val photoPermissionRequestCode = 4105
    private val preferenceName = "guitu_preferences"
    private val documentAccessNoticeKeyPrefix = "document_access_notice_seen"
    private val mainHandler = Handler(Looper.getMainLooper())
    private val photoScanExecutor = Executors.newSingleThreadExecutor()

    private var pendingResult: MethodChannel.Result? = null
    private var pendingExportData: String? = null
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingPermissionNames: List<String> = emptyList()
    private var pendingLocationResult: MethodChannel.Result? = null
    private var pendingPhotoPermissionResult: MethodChannel.Result? = null
    private var activeLocationListener: LocationListener? = null
    private var locationTimeout: Runnable? = null

    @Volatile
    private var photoScanCancelled = false

    @Volatile
    private var photoScanRunning = false

    @Volatile
    private var photoScanEventSink: EventChannel.EventSink? = null

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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, deviceEntryChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "getCurrentLocation" -> getCurrentLocation(result)
                "recognizeCoverText" -> recognizeCoverText(call, result)
                "requestPhotoLibraryAccess" -> requestPhotoLibraryAccess(result)
                "startPhotoScan" -> startPhotoScan(result)
                "cancelPhotoScan" -> {
                    photoScanCancelled = true
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, photoScanEventChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    photoScanEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    photoScanEventSink = null
                    if (photoScanRunning) {
                        photoScanCancelled = true
                    }
                }
            })
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

    private fun getCurrentLocation(result: MethodChannel.Result) {
        if (pendingLocationResult != null) {
            result.error("LOCATION_BUSY", "A location request is already running.", null)
            return
        }
        val permissions = requiredLocationPermissions()
        if (permissions.isNotEmpty() && !hasAnyLocationPermission()) {
            pendingLocationResult = result
            requestPermissions(permissions.toTypedArray(), locationPermissionRequestCode)
            return
        }
        requestSingleLocation(result)
    }

    private fun recognizeCoverText(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        if (path.isNullOrBlank()) {
            result.error("OCR_INPUT_INVALID", "An image path is required.", null)
            return
        }
        try {
            val image = InputImage.fromFilePath(this, Uri.fromFile(File(path)))
            val recognizer = TextRecognition.getClient(
                ChineseTextRecognizerOptions.Builder().build(),
            )
            recognizer.process(image)
                .addOnSuccessListener { text ->
                    result.success(
                        mapOf(
                            "text" to text.text,
                            "lines" to text.textBlocks.flatMap { block ->
                                block.lines.map { line -> line.text }
                            },
                        ),
                    )
                }
                .addOnFailureListener { error ->
                    result.error("OCR_FAILED", error.message, null)
                }
                .addOnCompleteListener {
                    recognizer.close()
                }
        } catch (error: Exception) {
            result.error("OCR_INPUT_INVALID", error.message, null)
        }
    }

    private fun requiredLocationPermissions(): List<String> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return emptyList()
        }
        return listOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION,
        )
    }

    private fun hasAnyLocationPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return true
        }
        return checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
            checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
    }

    private fun hasFineLocationPermission(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestSingleLocation(result: MethodChannel.Result) {
        if (!hasAnyLocationPermission()) {
            result.error("LOCATION_PERMISSION_DENIED", "Location permission was denied.", null)
            return
        }
        val locationManager = getSystemService(LOCATION_SERVICE) as LocationManager
        val preferredProviders = mutableListOf<String>()
        if (hasFineLocationPermission()) {
            preferredProviders.add(LocationManager.GPS_PROVIDER)
        }
        preferredProviders.add(LocationManager.NETWORK_PROVIDER)
        val enabledProviders = preferredProviders.filter { provider ->
            try {
                locationManager.isProviderEnabled(provider)
            } catch (_: Exception) {
                false
            }
        }
        if (enabledProviders.isEmpty()) {
            result.error("LOCATION_SERVICE_DISABLED", "No location provider is enabled.", null)
            return
        }
        val listener = object : LocationListener {
            override fun onLocationChanged(location: Location) {
                finishLocationRequest(location = location)
            }

            @Deprecated("Deprecated in Java")
            override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) = Unit

            override fun onProviderEnabled(provider: String) = Unit

            override fun onProviderDisabled(provider: String) = Unit
        }
        activeLocationListener = listener
        pendingLocationResult = result
        val timeout = Runnable { finishLocationRequest(errorCode = "LOCATION_TIMEOUT") }
        locationTimeout = timeout
        try {
            for (provider in enabledProviders) {
                locationManager.requestLocationUpdates(provider, 0L, 0f, listener, Looper.getMainLooper())
            }
            mainHandler.postDelayed(timeout, 12_000L)
        } catch (error: SecurityException) {
            finishLocationRequest(errorCode = "LOCATION_PERMISSION_DENIED")
        } catch (error: Exception) {
            finishLocationRequest(errorCode = "LOCATION_UNAVAILABLE")
        }
    }

    private fun finishLocationRequest(location: Location? = null, errorCode: String? = null) {
        val result = pendingLocationResult ?: return
        pendingLocationResult = null
        locationTimeout?.let { mainHandler.removeCallbacks(it) }
        locationTimeout = null
        val locationManager = getSystemService(LOCATION_SERVICE) as LocationManager
        activeLocationListener?.let { listener ->
            try {
                locationManager.removeUpdates(listener)
            } catch (_: Exception) {
                // A provider may have been disabled after the request was started.
            }
        }
        activeLocationListener = null
        if (location != null) {
            result.success(
                mapOf(
                    "latitude" to location.latitude,
                    "longitude" to location.longitude,
                    "timestamp" to if (location.time > 0L) location.time else System.currentTimeMillis(),
                ),
            )
            return
        }
        result.error(errorCode ?: "LOCATION_UNAVAILABLE", "Current location is unavailable.", null)
    }

    private fun requestPhotoLibraryAccess(result: MethodChannel.Result) {
        if (pendingPhotoPermissionResult != null) {
            result.error("PHOTO_PERMISSION_BUSY", "A photo permission request is already running.", null)
            return
        }
        if (hasPhotoLibraryAccess() && hasMediaLocationPermission()) {
            result.success(photoPermissionPayload(systemDialogShown = false))
            return
        }
        pendingPhotoPermissionResult = result
        requestPermissions(requiredPhotoPermissions().toTypedArray(), photoPermissionRequestCode)
    }

    private fun requiredPhotoPermissions(): List<String> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return emptyList()
        }
        val permissions = mutableListOf<String>()
        when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE -> {
                permissions.add(Manifest.permission.READ_MEDIA_IMAGES)
                permissions.add(Manifest.permission.READ_MEDIA_VISUAL_USER_SELECTED)
            }
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU -> {
                permissions.add(Manifest.permission.READ_MEDIA_IMAGES)
            }
            else -> permissions.add(Manifest.permission.READ_EXTERNAL_STORAGE)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            permissions.add(Manifest.permission.ACCESS_MEDIA_LOCATION)
        }
        return permissions
    }

    private fun hasPhotoLibraryAccess(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return true
        }
        return when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE -> {
                checkSelfPermission(Manifest.permission.READ_MEDIA_IMAGES) == PackageManager.PERMISSION_GRANTED ||
                    checkSelfPermission(Manifest.permission.READ_MEDIA_VISUAL_USER_SELECTED) == PackageManager.PERMISSION_GRANTED
            }
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU ->
                checkSelfPermission(Manifest.permission.READ_MEDIA_IMAGES) == PackageManager.PERMISSION_GRANTED
            else -> checkSelfPermission(Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun hasMediaLocationPermission(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            checkSelfPermission(Manifest.permission.ACCESS_MEDIA_LOCATION) == PackageManager.PERMISSION_GRANTED
    }

    private fun hasLimitedPhotoLibraryAccess(): Boolean {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE &&
            checkSelfPermission(Manifest.permission.READ_MEDIA_IMAGES) != PackageManager.PERMISSION_GRANTED &&
            checkSelfPermission(Manifest.permission.READ_MEDIA_VISUAL_USER_SELECTED) == PackageManager.PERMISSION_GRANTED
    }

    private fun photoPermissionPayload(systemDialogShown: Boolean): Map<String, Any> {
        val granted = hasPhotoLibraryAccess() && hasMediaLocationPermission()
        val requested = requiredPhotoPermissions()
        val permanentlyDenied = !granted && requested.any { permission ->
            !shouldShowRequestPermissionRationale(permission)
        }
        return mapOf(
            "granted" to granted,
            "limited" to hasLimitedPhotoLibraryAccess(),
            "permanentlyDenied" to permanentlyDenied,
            "systemDialogShown" to systemDialogShown,
            "sdkInt" to Build.VERSION.SDK_INT,
        )
    }

    private fun startPhotoScan(result: MethodChannel.Result) {
        if (photoScanRunning) {
            result.error("PHOTO_SCAN_BUSY", "A photo scan is already running.", null)
            return
        }
        if (!hasPhotoLibraryAccess() || !hasMediaLocationPermission()) {
            result.error("PHOTO_PERMISSION_DENIED", "Photo or media location access was not granted.", null)
            return
        }
        if (photoScanEventSink == null) {
            result.error("PHOTO_SCAN_CHANNEL", "Photo scan progress channel is not connected.", null)
            return
        }
        photoScanCancelled = false
        photoScanRunning = true
        result.success(null)
        photoScanExecutor.execute {
            scanPhotoMetadata()
        }
    }

    private fun scanPhotoMetadata() {
        try {
            val collection = MediaStore.Images.Media.EXTERNAL_CONTENT_URI
            val projection = arrayOf(
                MediaStore.Images.Media._ID,
                MediaStore.Images.Media.DATE_TAKEN,
                MediaStore.Images.Media.DATE_ADDED,
                MediaStore.Images.Media.MIME_TYPE,
                MediaStore.Images.ImageColumns.LATITUDE,
                MediaStore.Images.ImageColumns.LONGITUDE,
            )
            val photos = ArrayList<Map<String, Any>>()
            val totalPhotoCount = contentResolver.query(
                collection,
                projection,
                "${MediaStore.Images.Media.MIME_TYPE} LIKE ?",
                arrayOf("image/%"),
                "${MediaStore.Images.Media.DATE_TAKEN} DESC",
            )?.use { cursor ->
                scanCursor(cursor, collection, photos)
            } ?: 0
            if (photoScanCancelled) {
                emitPhotoScanEvent(mapOf("type" to "cancelled"))
            } else {
                emitPhotoScanEvent(
                    mapOf(
                        "type" to "complete",
                        "total" to totalPhotoCount,
                        "photos" to photos,
                    ),
                )
            }
        } catch (error: Exception) {
            if (photoScanCancelled) {
                emitPhotoScanEvent(mapOf("type" to "cancelled"))
            } else {
                emitPhotoScanEvent(
                    mapOf(
                        "type" to "error",
                        "code" to "PHOTO_SCAN_FAILED",
                        "message" to (error.message ?: "Unable to read photo metadata."),
                    ),
                )
            }
        } finally {
            photoScanRunning = false
            photoScanCancelled = false
        }
    }

    private fun scanCursor(
        cursor: Cursor,
        collection: Uri,
        photos: MutableList<Map<String, Any>>,
    ): Int {
        val total = cursor.count
        val idIndex = cursor.getColumnIndexOrThrow(MediaStore.Images.Media._ID)
        val dateTakenIndex = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DATE_TAKEN)
        val dateAddedIndex = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DATE_ADDED)
        val latitudeIndex = cursor.getColumnIndex(MediaStore.Images.ImageColumns.LATITUDE)
        val longitudeIndex = cursor.getColumnIndex(MediaStore.Images.ImageColumns.LONGITUDE)
        var scanned = 0
        while (cursor.moveToNext()) {
            if (photoScanCancelled) {
                return total
            }
            val id = cursor.getLong(idIndex)
            val uri = ContentUris.withAppendedId(collection, id)
            val takenAt = cursor.getLong(dateTakenIndex).takeIf { it > 0L }
                ?: (cursor.getLong(dateAddedIndex) * 1000L)
            var latitude: Double? = null
            var longitude: Double? = null
            if (latitudeIndex >= 0 && longitudeIndex >= 0 &&
                !cursor.isNull(latitudeIndex) && !cursor.isNull(longitudeIndex)) {
                val candidateLatitude = cursor.getDouble(latitudeIndex)
                val candidateLongitude = cursor.getDouble(longitudeIndex)
                if (isValidCoordinate(candidateLatitude, candidateLongitude)) {
                    latitude = candidateLatitude
                    longitude = candidateLongitude
                }
            }
            if (latitude == null || longitude == null) {
                val exifLocation = readExifLocation(uri)
                if (exifLocation != null) {
                    latitude = exifLocation.first
                    longitude = exifLocation.second
                }
            }
            if (latitude != null && longitude != null) {
                photos.add(
                    mapOf(
                        "id" to id.toString(),
                        "uri" to uri.toString(),
                        "latitude" to latitude,
                        "longitude" to longitude,
                        "takenAt" to takenAt,
                    ),
                )
            }
            scanned += 1
            if (scanned == total || scanned % 40 == 0) {
                emitPhotoScanEvent(
                    mapOf(
                        "type" to "progress",
                        "scanned" to scanned,
                        "total" to total,
                        "stage" to "reading",
                    ),
                )
            }
        }
        return total
    }

    private fun readExifLocation(uri: Uri): Pair<Double, Double>? {
        return try {
            contentResolver.openFileDescriptor(uri, "r")?.use { descriptor ->
                val location = ExifInterface(descriptor.fileDescriptor).latLong ?: return@use null
                val latitude = location[0].toDouble()
                val longitude = location[1].toDouble()
                if (isValidCoordinate(latitude, longitude)) {
                    Pair(latitude, longitude)
                } else {
                    null
                }
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun isValidCoordinate(latitude: Double, longitude: Double): Boolean {
        return latitude in -90.0..90.0 && longitude in -180.0..180.0 &&
            !(latitude == 0.0 && longitude == 0.0)
    }

    private fun emitPhotoScanEvent(event: Map<String, Any>) {
        // EventChannel messages enter FlutterJNI, which is restricted to the
        // Android main thread. Metadata scanning intentionally runs on a
        // worker thread, so marshal progress and terminal events back first.
        mainHandler.post {
            photoScanEventSink?.success(event)
        }
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
        if (requestCode == locationPermissionRequestCode) {
            val result = pendingLocationResult ?: return
            pendingLocationResult = null
            if (hasAnyLocationPermission()) {
                requestSingleLocation(result)
            } else {
                result.error("LOCATION_PERMISSION_DENIED", "Location permission was denied.", null)
            }
            return
        }
        if (requestCode == photoPermissionRequestCode) {
            val result = pendingPhotoPermissionResult ?: return
            pendingPhotoPermissionResult = null
            result.success(photoPermissionPayload(systemDialogShown = true))
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
