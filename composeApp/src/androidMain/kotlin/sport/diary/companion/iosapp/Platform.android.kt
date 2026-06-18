package sport.diary.companion.iosapp

import android.os.Build

actual fun getPlatformName(): String = "Android ${Build.VERSION.SDK_INT}"
