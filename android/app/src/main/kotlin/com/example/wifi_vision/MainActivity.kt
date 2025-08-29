package com.example.wifi_vision

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.net.wifi.ScanResult
import android.net.wifi.WifiManager
import android.net.wifi.rtt.RangingRequest
import android.net.wifi.rtt.RangingResult
import android.net.wifi.rtt.RangingResultCallback
import android.net.wifi.rtt.WifiRttManager
import android.os.Build
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val senseChannel = "sensor.heading"
    private val rttChannel = "rf.sensing"

    private var sensorManager: SensorManager? = null
    private var headingSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)

        // EventChannel para heading contínuo (graus 0..360, 0 = Norte)
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        EventChannel(engine.dartExecutor.binaryMessenger, senseChannel).setStreamHandler(object: EventChannel.StreamHandler{
            private var listener: SensorEventListener? = null
            override fun onListen(args: Any?, events: EventChannel.EventSink?) {
                headingSink = events
                val rot = sensorManager!!.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
                listener = object: SensorEventListener{
                    private val R = FloatArray(9)
                    private val I = FloatArray(9)
                    private val ori = FloatArray(3)
                    override fun onSensorChanged(ev: SensorEvent) {
                        if (ev.sensor.type == Sensor.TYPE_ROTATION_VECTOR) {
                            SensorManager.getRotationMatrixFromVector(R, ev.values)
                            SensorManager.getOrientation(R, ori)
                            var azimuth = Math.toDegrees(ori[0].toDouble()).toFloat() // -180..+180
                            if (azimuth < 0) azimuth += 360f
                            headingSink?.success(azimuth.toDouble())
                        }
                    }
                    override fun onAccuracyChanged(s: Sensor?, a: Int) {}
                }
                sensorManager!!.registerListener(listener, rot, SensorManager.SENSOR_DELAY_GAME)
            }
            override fun onCancel(args: Any?) {
                headingSink = null
                listener?.let { sensorManager!!.unregisterListener(it) }
            }
        })

        // MethodChannel para Wi‑Fi (scan + RTT)
        MethodChannel(engine.dartExecutor.binaryMessenger, rttChannel).setMethodCallHandler { call, result ->
            when(call.method){
                "wifiScan" -> {
                    try {
                        val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                        val list = wifi.scanResults.map { sr ->
                            mapOf(
                                "bssid" to sr.BSSID,
                                "ssid" to sr.SSID,
                                "is80211mcResponder" to sr.is80211mcResponder,
                                "frequency" to sr.frequency
                            )
                        }
                        result.success(list)
                    } catch (e: Exception) { result.error("SCAN_ERR", e.message, null) }
                }
                "rangeOnce" -> {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) { result.error("RTT_UNSUPPORTED","API<28",null); return@setMethodCallHandler }
                    try {
                        val wanted = (call.argument<List<String>>("bssids") ?: emptyList()).toSet()
                        val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                        val rtt = applicationContext.getSystemService(Context.WIFI_RTT_RANGING_SERVICE) as WifiRttManager
                        val scan: List<ScanResult> = wifi.scanResults
                        val candidates = (if (wanted.isEmpty()) scan else scan.filter { it.BSSID in wanted }).filter { it.is80211mcResponder }
                        if (candidates.isEmpty()) { result.success(emptyList<Map<String,Any>>()); return@setMethodCallHandler }
                        val req = RangingRequest.Builder().apply { candidates.forEach { addAccessPoint(it) } }.build()
                        rtt.startRanging(req, mainExecutor, object: RangingResultCallback(){
                            override fun onRangingResults(results: MutableList<RangingResult>) {
                                val mapped = results.map { rr ->
                                    mapOf("bssid" to rr.macAddress.toString(), "distanceMm" to rr.distanceMm, "distanceStdDevMm" to rr.distanceStdDevMm, "rssi" to rr.rssi, "status" to rr.status)
                                }
                                result.success(mapped)
                            }
                            override fun onRangingFailure(code: Int) { result.error("RTT_FAIL_$code","RTT failed",null) }
                        })
                    } catch (e: SecurityException) { result.error("PERMISSION","Conceda LOCATION/NEARBY_WIFI_DEVICES",null) }
                    catch (e: Exception) { result.error("RTT_ERR", e.message, null) }
                }
                else -> result.notImplemented()
            }
        }
    }
}