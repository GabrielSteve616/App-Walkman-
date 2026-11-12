package br.com.walkman.walkman

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Bundle
import android.os.SystemClock
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaControllerCompat
import android.support.v4.media.session.PlaybackStateCompat
import android.view.KeyEvent
import android.view.View
import android.widget.RemoteViews
import com.ryanheise.audioservice.AudioService
import com.ryanheise.audioservice.R as AudioR
import org.json.JSONArray

object WidgetActions {
    fun open(context:Context,action:String,id:String="",request:Int=0):PendingIntent {
        val intent=Intent(context,MainActivity::class.java)
            .setAction("${context.packageName}.widget.$action.$request")
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            .putExtra("walkmen_action",action).putExtra("walkmen_id",id)
        return PendingIntent.getActivity(context,request,intent,PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }
}

class ShelfWidget : AppWidgetProvider() {
    override fun onUpdate(context:Context,manager:AppWidgetManager,ids:IntArray){ids.forEach { update(context,manager,it) }}
    override fun onAppWidgetOptionsChanged(context:Context,manager:AppWidgetManager,id:Int,options:Bundle){update(context,manager,id)}
    override fun onReceive(context:Context,intent:Intent){
        super.onReceive(context,intent)
        if(intent.action=="${context.packageName}.SHELF_PAGE"){
            val id=intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID,0)
            val prefs=context.getSharedPreferences("companion",Context.MODE_PRIVATE)
            val count=try{JSONArray(prefs.getString("tapes","[]")).length()}catch(_:Exception){0}
            val pages=((count+1)/2).coerceAtLeast(1)
            val page=Math.floorMod(prefs.getInt("page_$id",0)+intent.getIntExtra("delta",1),pages)
            prefs.edit().putInt("page_$id",page).apply();update(context,AppWidgetManager.getInstance(context),id)
        }
    }
    companion object {
        fun updateAll(context:Context){val m=AppWidgetManager.getInstance(context);m.getAppWidgetIds(ComponentName(context,ShelfWidget::class.java)).forEach{update(context,m,it)}}
        fun update(context:Context,manager:AppWidgetManager,id:Int){
            val prefs=context.getSharedPreferences("companion",Context.MODE_PRIVATE)
            val tapes=try{JSONArray(prefs.getString("tapes","[]"))}catch(_:Exception){JSONArray()}
            val pages=((tapes.length()+1)/2).coerceAtLeast(1)
            val page=prefs.getInt("page_$id",0).coerceIn(0,pages-1)
            val views=RemoteViews(context.packageName,R.layout.widget_shelf)
            views.setTextViewText(R.id.shelf_title,if(tapes.length()==0)"CRIE SUAS FITAS NO APP" else "MINHAS FITAS  ${page+1}/$pages")
            for(slot in 0..1){
                val index=page*2+slot
                val container=if(slot==0)R.id.shelf_left else R.id.shelf_right
                val image=if(slot==0)R.id.shelf_left_art else R.id.shelf_right_art
                val name=if(slot==0)R.id.shelf_left_name else R.id.shelf_right_name
                val tape=tapes.optJSONObject(index)
                if(tape==null){
                    views.setImageViewResource(image,R.mipmap.ic_launcher)
                    views.setTextViewText(name,if(tapes.length()==0)"Abrir coleção" else "")
                    views.setViewVisibility(container,if(slot==1&&tapes.length()>0)View.INVISIBLE else View.VISIBLE)
                    views.setOnClickPendingIntent(container,WidgetActions.open(context,"collection",request=id*10+slot))
                }else{
                    views.setViewVisibility(container,View.VISIBLE);views.setTextViewText(name,tape.optString("name"))
                    val path=tape.optString("image")
                    val bitmap=if(path.isNotEmpty())BitmapFactory.decodeFile(path,BitmapFactory.Options().apply{inSampleSize=4})else null
                    if(bitmap!=null)views.setImageViewBitmap(image,Bitmap.createScaledBitmap(bitmap,144,94,true))else views.setImageViewResource(image,R.mipmap.ic_launcher)
                    views.setOnClickPendingIntent(container,WidgetActions.open(context,"tape",tape.optString("id"),id*10+slot))
                }
            }
            for((view,delta) in listOf(R.id.shelf_previous to -1,R.id.shelf_next to 1)){
                val intent=Intent(context,ShelfWidget::class.java).setAction("${context.packageName}.SHELF_PAGE")
                    .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID,id).putExtra("delta",delta)
                views.setOnClickPendingIntent(view,PendingIntent.getBroadcast(context,id*10+delta+4,intent,PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            }
            manager.updateAppWidget(id,views)
        }
    }
}

class WalkmanWidget : AppWidgetProvider() {
    override fun onUpdate(context:Context,manager:AppWidgetManager,ids:IntArray){updateAll(context)}
    override fun onAppWidgetOptionsChanged(context:Context,manager:AppWidgetManager,id:Int,options:Bundle){updateAll(context)}
    companion object {
        private var lastUpdate=0L
        private var lastPlaying:Boolean?=null
        private var lastTitle:String?=null
        fun updateAll(context:Context){
            val token=AudioService.activeSessionToken()
            val controller=if(token!=null)try{MediaControllerCompat(context,token)}catch(_:Exception){null}else null
            updateFromSession(context,controller,0f,true)
        }
        fun updateFromSession(context:Context,controller:MediaControllerCompat?,phase:Float,force:Boolean=false){
            val manager=AppWidgetManager.getInstance(context)
            val ids=manager.getAppWidgetIds(ComponentName(context,WalkmanWidget::class.java));if(ids.isEmpty())return
            val playing=controller?.playbackState?.state==PlaybackStateCompat.STATE_PLAYING
            val title=controller?.metadata?.description?.title?.toString()?:"Walkmen • toque para ouvir"
            val now=SystemClock.elapsedRealtime()
            if(!force&&lastPlaying==playing&&lastTitle==title&&now-lastUpdate<2000)return
            lastUpdate=now;lastPlaying=playing;lastTitle=title
            val art=controller?.metadata?.getBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART)
            val image=TapeGraphics.cassette(phase,true,art)
            for(id in ids){
                val views=RemoteViews(context.packageName,R.layout.widget_walkman)
                views.setTextViewText(R.id.widget_song,title);views.setImageViewBitmap(R.id.widget_device,image)
                views.setImageViewResource(R.id.widget_toggle,if(playing)AudioR.drawable.audio_service_pause else AudioR.drawable.audio_service_play_arrow)
                views.setOnClickPendingIntent(R.id.widget_device,WidgetActions.open(context,"resume",request=id*10+8))
                views.setOnClickPendingIntent(R.id.widget_song,WidgetActions.open(context,"player",request=id*10+9))
                for((view,key) in listOf(R.id.widget_previous to KeyEvent.KEYCODE_MEDIA_PREVIOUS,R.id.widget_toggle to KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE,R.id.widget_next to KeyEvent.KEYCODE_MEDIA_NEXT)){
                    views.setOnClickPendingIntent(view,if(controller!=null)WalkmenNotification.mediaAction(context,key)else WidgetActions.open(context,"resume",request=id*10+key))
                }
                manager.updateAppWidget(id,views)
            }
        }
    }
}
