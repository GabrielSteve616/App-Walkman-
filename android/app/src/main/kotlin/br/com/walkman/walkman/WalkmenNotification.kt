package br.com.walkman.walkman

import android.app.Notification
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.os.SystemClock
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaControllerCompat
import android.support.v4.media.session.PlaybackStateCompat
import android.view.KeyEvent
import android.widget.RemoteViews
import android.media.session.MediaSession
import com.ryanheise.audioservice.AudioService
import com.ryanheise.audioservice.MediaButtonReceiver
import com.ryanheise.audioservice.R as AudioR

object WalkmenNotification {
    private var previousArt: Bitmap? = null
    private var smallArt: Bitmap? = null
    private var previousPhase = Float.NaN
    private var tapeArt: Bitmap? = null
    private var phase=0f
    private var lastTime=SystemClock.elapsedRealtime()
    private var wasPlaying=false
    fun mediaAction(context: Context, code: Int): PendingIntent {
        val intent=Intent(context,MediaButtonReceiver::class.java).setAction(Intent.ACTION_MEDIA_BUTTON)
            .putExtra(Intent.EXTRA_KEY_EVENT,KeyEvent(KeyEvent.ACTION_DOWN,code))
        return PendingIntent.getBroadcast(context,code,intent,PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }
    fun decorate(service: AudioService, original: Notification): Notification {
        val token=service.sessionToken?:return original
        val controller=MediaControllerCompat(service,token)
        if(!AudioService.uiVisible) {
            WalkmanWidget.updateFromSession(service,controller,phase)
            return original
        }
        val metadata=controller.metadata
        val state=controller.playbackState
        val playing=state?.state==PlaybackStateCompat.STATE_PLAYING
        val now=SystemClock.elapsedRealtime()
        if(wasPlaying)phase=(phase+(now-lastTime)*.018f)%360f
        lastTime=now;wasPlaying=playing
        var position:Long=state?.position?:0L
        if(playing&&state!=null)position+=((now-state.lastPositionUpdateTime)*state.playbackSpeed).toLong()
        val duration=metadata?.getLong(MediaMetadataCompat.METADATA_KEY_DURATION)?:0
        val views=RemoteViews(service.packageName,R.layout.walkmen_notification)
        views.setTextViewText(R.id.notif_title,metadata?.description?.title?:"Walkmen")
        views.setTextViewText(R.id.notif_artist,metadata?.description?.subtitle?:"")
        if(tapeArt==null || previousPhase!=phase) { tapeArt=TapeGraphics.cassette(phase);previousPhase=phase }
        views.setImageViewBitmap(R.id.notif_tape,tapeArt)
        val art=metadata?.getBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART)
        if(art!==previousArt) { previousArt=art;smallArt=art?.let { Bitmap.createScaledBitmap(it,96,96,true) } }
        if(smallArt!=null)views.setImageViewBitmap(R.id.notif_art,smallArt)
        else views.setImageViewResource(R.id.notif_art,R.mipmap.ic_launcher)
        views.setTextViewText(R.id.notif_time,"${time(position)} / ${time(duration)}")
        views.setProgressBar(R.id.notif_progress,1000,if(duration>0)((position*1000/duration).coerceIn(0,1000)).toInt()else 0,false)
        views.setImageViewResource(R.id.notif_play,if(playing)AudioR.drawable.audio_service_pause else AudioR.drawable.audio_service_play_arrow)
        views.setOnClickPendingIntent(R.id.notif_previous,mediaAction(service,KeyEvent.KEYCODE_MEDIA_PREVIOUS))
        views.setOnClickPendingIntent(R.id.notif_play,mediaAction(service,KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE))
        views.setOnClickPendingIntent(R.id.notif_next,mediaAction(service,KeyEvent.KEYCODE_MEDIA_NEXT))
        views.setOnClickPendingIntent(R.id.notif_tape,WidgetActions.open(service,"player"))
        val notification=Notification.Builder.recoverBuilder(service,original)
            .setCustomBigContentView(views)
            .setStyle(Notification.DecoratedMediaCustomViewStyle().setMediaSession(token.token as MediaSession.Token))
            .setOnlyAlertOnce(true).build()
        WalkmanWidget.updateFromSession(service,controller,phase)
        return notification
    }
    private fun time(ms:Long):String { val seconds=ms.coerceAtLeast(0)/1000;return "${seconds/60}:${(seconds%60).toString().padStart(2,'0')}" }
}
