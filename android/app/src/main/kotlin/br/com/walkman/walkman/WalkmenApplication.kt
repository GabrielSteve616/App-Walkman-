package br.com.walkman.walkman

import android.app.Application
import com.ryanheise.audioservice.AudioService

class WalkmenApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        AudioService.notificationCustomizer = AudioService.NotificationCustomizer { service, original ->
            WalkmenNotification.decorate(service,original)
        }
    }
}
