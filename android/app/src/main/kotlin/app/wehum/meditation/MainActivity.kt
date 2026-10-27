package app.wehum.meditation

import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.IntegrityTokenRequest
import android.app.PictureInPictureParams
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.FileProvider
import java.io.File
import android.util.Rational
import com.ryanheise.audioservice.AudioServiceFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// A FragmentActivity: Health Connect's permission sheet (health plugin) needs registerForActivityResult.
class MainActivity : AudioServiceFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.wehum/pip").setMethodCallHandler { call, result ->
            if (call.method != "enter") return@setMethodCallHandler result.notImplemented()
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return@setMethodCallHandler result.success(false)
            result.success(enterPictureInPictureMode(PictureInPictureParams.Builder().setAspectRatio(Rational(16, 9)).build()))
        }
        // Instagram "Share to Stories": the PNG goes to Instagram's story composer as a content URI. No Instagram login:
        // the person is signed in to Instagram already; `source_application` is our Meta App ID.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.wehum/share").setMethodCallHandler { call, result ->
            when (call.method) {
                "instagramAvailable" -> result.success(instagramInstalled())
                "instagramStory" -> {
                    val path = call.argument<String>("path")
                    val appId = call.argument<String>("appId")
                    if (path == null || appId == null) return@setMethodCallHandler result.error("bad_args", "path/appId missing", null)
                    if (!instagramInstalled()) return@setMethodCallHandler result.success(false)
                    val uri = FileProvider.getUriForFile(this, "$packageName.wehum.share", File(path))
                    val intent = Intent("com.instagram.share.ADD_TO_STORY").apply {
                        putExtra("source_application", appId)
                        setDataAndType(uri, "image/png")
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        setPackage(INSTAGRAM)
                    }
                    grantUriPermission(INSTAGRAM, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    try {
                        startActivity(intent)
                        result.success(true)
                    } catch (e: ActivityNotFoundException) {
                        result.success(false)
                    }
                }
                // No Meta App ID yet: a plain share intent sent straight to Instagram (it asks Feed / Story / Message).
                "instagramSend" -> {
                    val path = call.argument<String>("path") ?: return@setMethodCallHandler result.error("bad_args", "path missing", null)
                    if (!instagramInstalled()) return@setMethodCallHandler result.success(false)
                    val uri = FileProvider.getUriForFile(this, "$packageName.wehum.share", File(path))
                    val intent = Intent(Intent.ACTION_SEND).apply {
                        type = "image/png"
                        putExtra(Intent.EXTRA_STREAM, uri)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        setPackage(INSTAGRAM)
                    }
                    try {
                        startActivity(intent)
                        result.success(true)
                    } catch (e: ActivityNotFoundException) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
        // Play Integrity: the verdict token is bound to the server's one-time challenge (the nonce).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.wehum/attest").setMethodCallHandler { call, result ->
            if (call.method != "integrity") return@setMethodCallHandler result.notImplemented()
            val challenge = call.argument<String>("challenge")
            val project = call.argument<Number>("project")?.toLong()
            if (challenge == null || project == null) return@setMethodCallHandler result.error("bad_args", "challenge/project missing", null)
            IntegrityManagerFactory.create(applicationContext)
                .requestIntegrityToken(IntegrityTokenRequest.builder().setNonce(challenge).setCloudProjectNumber(project).build())
                .addOnSuccessListener { result.success(it.token()) }
                .addOnFailureListener { result.error("integrity_failed", it.message, null) }
        }
    }

    private fun instagramInstalled(): Boolean = try {
        packageManager.getPackageInfo(INSTAGRAM, 0)
        true
    } catch (e: PackageManager.NameNotFoundException) {
        false
    }

    private companion object {
        const val INSTAGRAM = "com.instagram.android"
    }
}
