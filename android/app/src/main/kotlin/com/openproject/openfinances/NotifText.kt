package com.openproject.openfinances

import android.content.Context
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Typeface
import android.text.Layout
import android.text.StaticLayout
import android.text.TextDirectionHeuristics
import android.text.TextPaint
import android.text.TextUtils
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import kotlin.math.ceil

/**
 * Our notification's text in the app's own font (Shabnam / Manrope, or the
 * device font if the user picked that in Settings).
 *
 * A notification is drawn by the system with the app's resources in a
 * restricted context, which ignores an app's font files. So the two lines
 * are drawn into images here and shown in a custom layout; the plain
 * title/text are still set on the notification for the lock screen and
 * accessibility. Colors follow the system's light/dark mode at posting time.
 */
object NotifText {
    private const val FONTS = "flutter_assets/assets/fonts/"
    private val cache = HashMap<String, Typeface>()

    private fun typeface(context: Context, fa: Boolean, bold: Boolean): Typeface {
        val useAppFont = try {
            context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .getBoolean(if (fa) "flutter.appFontFa" else "flutter.appFontEn", true)
        } catch (_: ClassCastException) {
            true
        }
        if (!useAppFont) return if (bold) Typeface.DEFAULT_BOLD else Typeface.DEFAULT
        val file = when {
            fa -> "Shabnam.ttf" // one weight: bold is drawn (as in the app)
            // The app's own cuts (normal text and w600/w700).
            bold -> "manrope/Manrope-600.ttf"
            else -> "manrope/Manrope-400.ttf"
        }
        return cache.getOrPut(file) {
            try {
                Typeface.createFromAsset(context.assets, FONTS + file)
            } catch (_: Exception) {
                Typeface.DEFAULT
            }
        }
    }

    private fun dark(context: Context) =
        context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK ==
            Configuration.UI_MODE_NIGHT_YES

    /** [text] as an image: [sp] size, at most [maxLines] lines as wide as a
     *  notification's content, ellipsized after that. */
    private fun draw(
        context: Context,
        text: String,
        sp: Float,
        primary: Boolean,
        fa: Boolean,
        maxLines: Int,
    ): Bitmap {
        val dm = context.resources.displayMetrics
        val isDark = dark(context)
        val paint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            textSize = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, sp, dm)
            color = when {
                primary && isDark -> 0xFFE8E8E8.toInt()
                primary -> 0xFF1F1F1F.toInt()
                isDark -> 0xFFBDC1C6.toInt()
                else -> 0xFF5F6368.toInt()
            }
            typeface = typeface(context, fa, bold = primary)
            isFakeBoldText = primary && fa
        }
        // The content area: the screen less the shade's side margins and
        // the template's icon column (a little under, to be safe).
        val maxWidth = (dm.widthPixels - 120 * dm.density).toInt().coerceAtLeast(160)
        val width = ceil(Layout.getDesiredWidth(text, paint)).toInt().coerceIn(1, maxWidth)
        val layout = StaticLayout.Builder.obtain(text, 0, text.length, paint, width)
            .setTextDirection(
                if (fa) TextDirectionHeuristics.FIRSTSTRONG_RTL
                else TextDirectionHeuristics.FIRSTSTRONG_LTR
            )
            .setAlignment(Layout.Alignment.ALIGN_NORMAL)
            .setIncludePad(false)
            .setMaxLines(maxLines)
            .setEllipsize(TextUtils.TruncateAt.END)
            .build()
        val bmp = Bitmap.createBitmap(width, layout.height.coerceAtLeast(1), Bitmap.Config.ARGB_8888)
        layout.draw(Canvas(bmp))
        return bmp
    }

    /** The custom content: [title] over [text]; [big] lets the text wrap. */
    fun views(context: Context, title: String, text: String, fa: Boolean, big: Boolean): RemoteViews {
        val rv = RemoteViews(
            context.packageName,
            if (fa) R.layout.notif_bank_rtl else R.layout.notif_bank_ltr,
        )
        rv.setImageViewBitmap(R.id.notif_title, draw(context, title, 14.5f, true, fa, 1))
        rv.setContentDescription(R.id.notif_title, title)
        if (text.isEmpty()) {
            rv.setViewVisibility(R.id.notif_text, View.GONE)
        } else {
            rv.setImageViewBitmap(
                R.id.notif_text,
                draw(context, text, 12.5f, false, fa, if (big) 3 else 1),
            )
            rv.setContentDescription(R.id.notif_text, text)
        }
        return rv
    }
}
