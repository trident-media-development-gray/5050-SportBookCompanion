package sport.diary.companion.iosapp

import platform.UIKit.UIDevice

actual fun getPlatformName(): String =
    UIDevice.currentDevice.systemName() + " " + UIDevice.currentDevice.systemVersion
