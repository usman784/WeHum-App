package app.wehum.meditation

import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.IntegrityTokenRequest
import android.app.PictureInPictureParams
import android.os.Build
import android.util.Rational
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.wehum/pip").setMethodCallHandler { call, result ->
            if (call.method != "enter") return@setMethodCallHandler result.notImplemented()
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return@setMethodCallHandler result.success(false)
            result.success(enterPictureInPictureMode(PictureInPictureParams.Builder().setAspectRatio(Rational(16, 9)).build()))
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
}
