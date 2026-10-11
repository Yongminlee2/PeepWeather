# WorkManager(알림 확인)가 쓰는 Room DB 생성자 — 없으면 릴리스가 켜자마자 죽는다
-keep class * extends androidx.room.RoomDatabase { <init>(); }
