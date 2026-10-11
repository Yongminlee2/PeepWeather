package com.peep.weather

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/** 홈 화면 위젯: 기관별 지금 기온을 나란히. 값은 앱(Dart)이 home_widget 으로 넣어 준다. */
class CompareWidget : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        val open = PendingIntent.getActivity(
            context, 0, Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val rows = intArrayOf(R.id.row0, R.id.row1, R.id.row2, R.id.row3)
        for (id in appWidgetIds) {
            val v = RemoteViews(context.packageName, R.layout.compare_widget)
            v.setTextViewText(R.id.place, widgetData.getString("place", context.getString(R.string.app_name)))
            v.setTextViewText(R.id.time, widgetData.getString("time", ""))
            v.setTextViewText(R.id.mid, widgetData.getString("mid", "—"))
            v.setTextViewText(R.id.range, widgetData.getString("range", ""))
            rows.forEachIndexed { i, rid ->
                val text = widgetData.getString("row$i", "") ?: ""
                v.setTextViewText(rid, text)
                v.setViewVisibility(rid, if (text.isEmpty()) View.GONE else View.VISIBLE)
            }
            v.setOnClickPendingIntent(R.id.root, open)
            appWidgetManager.updateAppWidget(id, v)
        }
    }
}
