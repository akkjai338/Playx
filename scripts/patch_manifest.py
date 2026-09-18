import re
import shutil
import sys
from pathlib import Path

path = "android/app/src/main/AndroidManifest.xml"

with open(path, "r", encoding="utf-8") as f:
    content = f.read()

permissions = """
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" tools:ignore="ScopedStorage" />
    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
    <uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" tools:ignore="ScopedStorage" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    <uses-permission android:name="android.permission.INTERNET" />
"""

# Ensure the tools namespace is declared on <manifest ...>
if "xmlns:tools" not in content:
    content = content.replace(
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android">',
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android"\n    xmlns:tools="http://schemas.android.com/tools">',
        1,
    )

# Insert permissions right after the opening <manifest ...> tag.
content = re.sub(
    r'(<manifest[^>]*>)',
    lambda m: m.group(1) + permissions,
    content,
    count=1,
)

# Add PiP support attributes to the MainActivity <activity> tag.
if "supportsPictureInPicture" not in content:
    content = re.sub(
        r'(<activity\s+android:name="\.MainActivity")',
        r'\1\n            android:supportsPictureInPicture="true"\n            android:resizeableActivity="true"',
        content,
        count=1,
    )

with open(path, "w", encoding="utf-8") as f:
    f.write(content)

# Use the supplied PlayX logo for the Android launcher/application branding.
logo = Path("assets/images/playx_logo.png")
drawable = Path("android/app/src/main/res/drawable")
if logo.exists():
    drawable.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(logo, drawable / "playx_logo.png")
    manifest = Path(path).read_text(encoding="utf-8")
    manifest = re.sub(r'\sandroid:icon="[^"]*"', '', manifest, count=1)
    manifest = re.sub(r'\sandroid:label="[^"]*"', '', manifest, count=1)
    manifest = re.sub(r'<application\b', '<application android:icon="@drawable/playx_logo" android:label="PlayX"', manifest, count=1)
    Path(path).write_text(manifest, encoding="utf-8")

# Flutter 3.24 generates Kotlin 1.7.x, while current Android dependencies
# resolve Kotlin 1.9 metadata. Upgrade the generated plugin before Gradle runs.
settings_path = Path("android/settings.gradle")
if settings_path.exists():
    settings = settings_path.read_text(encoding="utf-8")
    settings = re.sub(
        r'(id\s+"org\.jetbrains\.kotlin\.android"\s+version\s+")[^"]+("\s+apply\s+false)',
        r'\g<1>1.9.24\g<2>',
        settings,
    )
    settings_path.write_text(settings, encoding="utf-8")

# Flutter's generated activity gets the native MediaStore bridge used by the
# delete action. Keep this generated so a fresh `flutter create` remains safe.
activity = Path("android/app/src/main/kotlin/com/ankit/playx/MainActivity.kt")
activity.parent.mkdir(parents=True, exist_ok=True)
activity.write_text(r'''package com.ankit.playx

import android.content.ContentUris
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "com.ankit.playx/media_store"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            if (call.method != "deleteVideo") { result.notImplemented(); return@setMethodCallHandler }
            val path = call.argument<String>("path")
            if (path.isNullOrBlank()) { result.success(false); return@setMethodCallHandler }
            val projection = arrayOf(MediaStore.Video.Media._ID)
            val selection = "${MediaStore.Video.Media.DATA} = ?"
            val deleted = contentResolver.query(
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI, projection, selection, arrayOf(path), null
            )?.use { cursor ->
                if (!cursor.moveToFirst()) false else {
                    val id = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Video.Media._ID))
                    try {
                        contentResolver.delete(ContentUris.withAppendedId(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, id), null, null) > 0
                    } catch (_: SecurityException) { false }
                }
            } ?: false
            result.success(deleted)
        }
    }
}
''', encoding="utf-8")

print("AndroidManifest.xml patched successfully.")
