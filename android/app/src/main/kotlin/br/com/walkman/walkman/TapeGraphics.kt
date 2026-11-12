package br.com.walkman.walkman

import android.graphics.*
import kotlin.math.*

object TapeGraphics {
    fun cassette(angle: Float = 0f, walkman: Boolean = false, art: Bitmap? = null): Bitmap {
        val bitmap = Bitmap.createBitmap(280, 120, Bitmap.Config.ARGB_8888)
        val c = Canvas(bitmap)
        val p = Paint(Paint.ANTI_ALIAS_FLAG)
        p.shader = LinearGradient(0f,0f,280f,120f,intArrayOf(Color.rgb(45,52,60),Color.rgb(12,16,22)),null,Shader.TileMode.CLAMP)
        c.drawRoundRect(0f,0f,280f,120f,14f,14f,p); p.shader=null
        if (walkman) {
            p.color=Color.rgb(192,200,202);c.drawRoundRect(6f,5f,274f,115f,11f,11f,p)
            p.color=Color.rgb(21,62,103);c.drawRoundRect(12f,10f,268f,109f,8f,8f,p)
            p.color=Color.rgb(233,223,201);p.textSize=8f;p.typeface=Typeface.DEFAULT_BOLD
            c.drawText("WALKMEN  /  STEREO",23f,22f,p)
        }
        p.color=Color.rgb(34,39,42);c.drawRoundRect(27f,28f,253f,105f,8f,8f,p)
        p.color=Color.rgb(226,214,189);c.drawRoundRect(37f,34f,243f,91f,7f,7f,p)
        p.color=Color.rgb(171,53,39);c.drawRect(37f,48f,243f,55f,p)
        p.color=Color.rgb(10,14,17);c.drawRoundRect(48f,59f,232f,86f,13f,13f,p)
        for (x in listOf(90f,190f)) {
            p.color=Color.rgb(220,208,183);c.drawCircle(x,72f,15f,p)
            p.color=Color.rgb(20,25,28);c.drawCircle(x,72f,11f,p)
            c.save();c.rotate(angle,x,72f)
            p.color=Color.rgb(220,208,183)
            repeat(6) { c.drawRect(x-2,58f,x+2,65f,p);c.rotate(60f,x,72f) };c.restore()
        }
        if (art!=null) {c.drawBitmap(art,null,RectF(123f,59f,157f,85f),p)}
        else {p.color=Color.rgb(92,66,49);c.drawRect(123f,61f,157f,83f,p)}
        p.color=Color.rgb(8,12,15);c.drawRect(82f,97f,198f,103f,p)
        return bitmap
    }
}
