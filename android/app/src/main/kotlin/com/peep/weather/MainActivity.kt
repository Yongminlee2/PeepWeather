package com.peep.weather

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // 개발자의 다른 게임: 삼성 폰에서 스토어 선택창 없이 플레이 스토어를 정해서 연다.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app/store")
            .setMethodCallHandler { call, result ->
                val q = call.arguments as? String
                if (call.method != "open" || q == null) {
                    result.notImplemented(); return@setMethodCallHandler
                }
                try {
                    startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("market://$q")).setPackage("com.android.vending"))
                } catch (e: ActivityNotFoundException) {
                    startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/apps/$q")))
                }
                result.success(null)
            }
    }
}
