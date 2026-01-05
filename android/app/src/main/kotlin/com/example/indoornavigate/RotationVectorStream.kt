package com.example.indoornavigate

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.view.Display
import android.view.Surface
import android.view.WindowManager
import io.flutter.plugin.common.EventChannel
import kotlin.math.atan2
import kotlin.math.PI

class RotationVectorStream(private val context: Context) : EventChannel.StreamHandler, SensorEventListener {
    private var sensorManager: SensorManager? = null
    private var rotationVector: Sensor? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        rotationVector = sensorManager?.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
        if (rotationVector == null) {
            // Try geomagnetic rotation vector as fallback
            rotationVector = sensorManager?.getDefaultSensor(Sensor.TYPE_GEOMAGNETIC_ROTATION_VECTOR)
        }
        sensorManager?.registerListener(this, rotationVector, SensorManager.SENSOR_DELAY_GAME)
    }

    override fun onCancel(arguments: Any?) {
        sensorManager?.unregisterListener(this)
        eventSink = null
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // no-op
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null) return
        val rv = event.values
        // rv length may be 4 (x,y,z,w) or 3 (x,y,z)
        val quat = FloatArray(4)
        if (rv.size >= 4) {
            quat[0] = rv[3]
            quat[1] = rv[0]
            quat[2] = rv[1]
            quat[3] = rv[2]
        } else {
            // convert rotation vector to quaternion
            SensorManager.getQuaternionFromVector(quat, rv)
            // quaternion returned is in order (w, x, y, z) already
        }

        // Compute rotation matrix
        val rotMatrix = FloatArray(9)
        SensorManager.getRotationMatrixFromVector(rotMatrix, rv)

        // Remap coordinate system to display orientation so azimuth matches camera orientation
        val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val display: Display = wm.defaultDisplay
        val remapped = FloatArray(9)
        when (display.rotation) {
            Surface.ROTATION_0 -> System.arraycopy(rotMatrix, 0, remapped, 0, 9)
            Surface.ROTATION_90 -> SensorManager.remapCoordinateSystem(rotMatrix, SensorManager.AXIS_Y, SensorManager.AXIS_MINUS_X, remapped)
            Surface.ROTATION_180 -> SensorManager.remapCoordinateSystem(rotMatrix, SensorManager.AXIS_MINUS_X, SensorManager.AXIS_MINUS_Y, remapped)
            Surface.ROTATION_270 -> SensorManager.remapCoordinateSystem(rotMatrix, SensorManager.AXIS_MINUS_Y, SensorManager.AXIS_X, remapped)
            else -> System.arraycopy(rotMatrix, 0, remapped, 0, 9)
        }

        val orientation = FloatArray(3)
        SensorManager.getOrientation(remapped, orientation)
        // orientation[0] is azimuth (radians)
        val azimuthRad = orientation[0].toDouble()
        var heading = Math.toDegrees(azimuthRad)
        if (heading < 0) heading += 360.0

        val payload = mapOf(
            "quaternion" to listOf(quat[0].toDouble(), quat[1].toDouble(), quat[2].toDouble(), quat[3].toDouble()),
            "heading" to heading,
            "timestamp" to event.timestamp
        )

        eventSink?.success(payload)
    }
}
