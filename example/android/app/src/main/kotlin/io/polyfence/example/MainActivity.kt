package io.polyfence.example

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Update the intent for singleTop behavior
        setIntent(intent)
    }
}
