#!/bin/bash
# GameZone project generator
set -e
mkdir -p "."
cat > "settings.gradle.kts" <<'GZEOF'
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}
rootProject.name = "GameZone"
include(":app")
GZEOF
mkdir -p "."
cat > "build.gradle.kts" <<'GZEOF'
plugins {
    id("com.android.application") version "8.5.2" apply false
    id("org.jetbrains.kotlin.android") version "2.0.20" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.0.20" apply false
}
GZEOF
mkdir -p "."
cat > "gradle.properties" <<'GZEOF'
org.gradle.jvmargs=-Xmx3g -Dfile.encoding=UTF-8
android.useAndroidX=true
kotlin.code.style=official
GZEOF
mkdir -p "app"
cat > "app/build.gradle.kts" <<'GZEOF'
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "com.example.gamezone"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.example.gamezone"
        minSdk = 29
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    buildFeatures { compose = true }
}

dependencies {
    implementation(platform("androidx.compose:compose-bom:2024.09.00"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.activity:activity-compose:1.9.2")
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
}
GZEOF
mkdir -p "app/src/main"
cat > "app/src/main/AndroidManifest.xml" <<'GZEOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.ACCESS_NOTIFICATION_POLICY" />
    <uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
    <uses-permission android:name="android.permission.CHANGE_WIFI_STATE" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE" />

    <queries>
        <intent>
            <action android:name="android.intent.action.MAIN" />
            <category android:name="android.intent.category.LAUNCHER" />
        </intent>
    </queries>

    <application
        android:allowBackup="true"
        android:icon="@android:drawable/sym_def_app_icon"
        android:label="GameZone"
        android:theme="@android:style/Theme.Material.NoActionBar">

        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

        <service
            android:name=".GameModeService"
            android:exported="false"
            android:foregroundServiceType="specialUse">
            <property
                android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE"
                android:value="game_mode_dnd_thermal_monitor" />
        </service>
    </application>
</manifest>
GZEOF
mkdir -p "app/src/main/java/com/example/gamezone"
cat > "app/src/main/java/com/example/gamezone/MainActivity.kt" <<'GZEOF'
package com.example.gamezone

import android.Manifest
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.core.graphics.drawable.toBitmap
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme(colorScheme = darkColorScheme()) {
                Surface(Modifier.fillMaxSize()) { GameScreen() }
            }
        }
    }
}

data class GameApp(val label: String, val pkg: String, val icon: ImageBitmap)

@Composable
fun GameScreen() {
    val ctx = LocalContext.current
    val on by GameModeService.running.collectAsState()
    val thermal by GameModeService.thermalStatus.collectAsState()
    var games by remember { mutableStateOf<List<GameApp>>(emptyList()) }

    LaunchedEffect(Unit) {
        games = withContext(Dispatchers.IO) { loadGames(ctx) }
    }

    val notifPermission = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { startGameMode(ctx) }

    Column(Modifier.fillMaxSize().statusBarsPadding().padding(16.dp)) {
        Text("GameZone", style = MaterialTheme.typography.headlineMedium)
        Spacer(Modifier.height(12.dp))

        Card(Modifier.fillMaxWidth()) {
            Row(
                Modifier.padding(16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(Modifier.weight(1f)) {
                    Text("गेमिंग मोड", style = MaterialTheme.typography.titleMedium)
                    Text(
                        if (on) "ON: नोटिफिकेशन म्यूट, हीट मॉनिटर चालू" else "OFF",
                        style = MaterialTheme.typography.bodySmall
                    )
                    if (on) Text("फोन: ${thermalLabel(thermal)}", style = MaterialTheme.typography.bodySmall)
                }
                Switch(checked = on, onCheckedChange = { checked ->
                    if (checked) {
                        val needsNotif = Build.VERSION.SDK_INT >= 33 &&
                            ctx.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                            PackageManager.PERMISSION_GRANTED
                        if (needsNotif) notifPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
                        else startGameMode(ctx)
                    } else {
                        ctx.startService(
                            Intent(ctx, GameModeService::class.java).setAction(GameModeService.ACTION_STOP)
                        )
                    }
                })
            }
        }

        Spacer(Modifier.height(16.dp))
        Text("मेरे गेम्स", style = MaterialTheme.typography.titleMedium)
        Spacer(Modifier.height(8.dp))

        LazyVerticalGrid(columns = GridCells.Fixed(3), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            items(games, key = { it.pkg }) { game ->
                Column(
                    Modifier.clickable {
                        ctx.packageManager.getLaunchIntentForPackage(game.pkg)?.let { ctx.startActivity(it) }
                    },
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Image(game.icon, game.label, Modifier.size(56.dp))
                    Text(game.label, maxLines = 1, overflow = TextOverflow.Ellipsis,
                        style = MaterialTheme.typography.labelSmall)
                }
            }
        }
    }
}

fun startGameMode(ctx: Context) {
    val nm = ctx.getSystemService(NotificationManager::class.java)
    if (!nm.isNotificationPolicyAccessGranted) {
        Toast.makeText(ctx, "GameZone को DND की परमिशन दो, फिर वापस आकर ON करो", Toast.LENGTH_LONG).show()
        ctx.startActivity(Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS))
        return
    }
    ContextCompat.startForegroundService(ctx, Intent(ctx, GameModeService::class.java))
}

fun thermalLabel(status: Int) = when (status) {
    0 -> "ठंडा ✅"
    1 -> "हल्का गर्म"
    2 -> "गर्म ⚠️"
    else -> "बहुत गर्म 🔥"
}

fun loadGames(ctx: Context): List<GameApp> {
    val pm = ctx.packageManager
    val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
    val infos = pm.queryIntentActivities(intent, 0)
        .map { it.activityInfo.applicationInfo }
        .distinctBy { it.packageName }
        .filter { it.packageName != ctx.packageName }

    // कई गेम्स में category सेट नहीं होती, तब सारे ऐप्स दिखाते हैं
    val games = infos.filter { it.category == ApplicationInfo.CATEGORY_GAME }
    val list = if (games.isEmpty()) infos else games

    return list.map {
        GameApp(
            pm.getApplicationLabel(it).toString(),
            it.packageName,
            pm.getApplicationIcon(it).toBitmap(96, 96).asImageBitmap()
        )
    }.sortedBy { it.label.lowercase() }
}
GZEOF
mkdir -p "app/src/main/java/com/example/gamezone"
cat > "app/src/main/java/com/example/gamezone/GameModeService.kt" <<'GZEOF'
package com.example.gamezone

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.wifi.WifiManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

class GameModeService : Service() {

    companion object {
        const val ACTION_STOP = "com.example.gamezone.STOP"
        private const val CHANNEL_ID = "game_mode"
        private const val NOTIF_ID = 1

        private val _running = MutableStateFlow(false)
        val running: StateFlow<Boolean> = _running

        private val _thermal = MutableStateFlow(0)
        val thermalStatus: StateFlow<Int> = _thermal
    }

    private var wifiLock: WifiManager.WifiLock? = null
    private var previousFilter = NotificationManager.INTERRUPTION_FILTER_ALL
    private var dndChanged = false
    private var thermalListener: PowerManager.OnThermalStatusChangedListener? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }
        if (_running.value) return START_NOT_STICKY

        createChannel()
        val type = if (Build.VERSION.SDK_INT >= 34)
            ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE else 0
        ServiceCompat.startForeground(this, NOTIF_ID, buildNotification("गेमिंग मोड ON"), type)

        enableDnd()
        lockWifi()
        watchThermal()
        _running.value = true
        return START_NOT_STICKY
    }

    private fun enableDnd() {
        val nm = getSystemService(NotificationManager::class.java)
        if (nm.isNotificationPolicyAccessGranted) {
            previousFilter = nm.currentInterruptionFilter
            nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALARMS)
            dndChanged = true
        }
    }

    private fun lockWifi() {
        val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        wifiLock = wm.createWifiLock(WifiManager.WIFI_MODE_FULL_LOW_LATENCY, "gamezone:wifi")
            .apply {
                setReferenceCounted(false)
                acquire()
            }
    }

    private fun watchThermal() {
        val pm = getSystemService(PowerManager::class.java)
        val listener = PowerManager.OnThermalStatusChangedListener { status ->
            _thermal.value = status
            val text = if (status >= PowerManager.THERMAL_STATUS_MODERATE)
                "⚠️ फोन गर्म है! ग्राफिक्स कम करो, चार्जर निकालो"
            else "गेमिंग मोड ON"
            getSystemService(NotificationManager::class.java)
                .notify(NOTIF_ID, buildNotification(text))
        }
        thermalListener = listener
        pm.addThermalStatusListener(listener)
        _thermal.value = pm.currentThermalStatus
    }

    private fun createChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID, "Game Mode", NotificationManager.IMPORTANCE_LOW
        )
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun buildNotification(text: String): Notification {
        val stopIntent = PendingIntent.getService(
            this, 0,
            Intent(this, GameModeService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("GameZone")
            .setContentText(text)
            .setOngoing(true)
            .addAction(0, "बंद करो", stopIntent)
            .build()
    }

    override fun onDestroy() {
        if (dndChanged) {
            val nm = getSystemService(NotificationManager::class.java)
            if (nm.isNotificationPolicyAccessGranted) nm.setInterruptionFilter(previousFilter)
        }
        wifiLock?.let { if (it.isHeld) it.release() }
        thermalListener?.let { getSystemService(PowerManager::class.java).removeThermalStatusListener(it) }
        _running.value = false
        _thermal.value = 0
        super.onDestroy()
    }
}
GZEOF
