package ws.diye.scrcpy_flutter

import android.content.Context
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import java.lang.Exception
import java.math.BigInteger
import java.net.Socket
import java.nio.charset.StandardCharsets

internal class NativeSurfaceViewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    private lateinit var socket: Socket
    private lateinit var inputStream: InputStream
    private lateinit var outputStream: OutputStream
    var deviceInfo = HashMap<String, Any>()
    var nativeSurfaceView: NativeSurfaceView? = null

    fun connect(addr: String, port: Int, callback: (params: HashMap<String, Any>) -> Unit): Boolean {
        deviceInfo.clear()
        val thread = Thread {
            run() {
                try {
                    connectImpl(addr, port, callback)
                } catch (e: Exception) {
                    println(e.printStackTrace())
                    callback(HashMap<String, Any>())
                }
            }
        }
        thread.start()
        return true
    }

    private fun connectImpl(addr: String, port: Int, callback: (params: HashMap<String, Any>) -> Unit) {
        socket = Socket(addr, port)
//        val socket1 = Socket(addr, port)
        inputStream = socket.getInputStream()
        outputStream = socket.getOutputStream()  // maybe useless

        val testByte = ByteArray(1)
        inputStream.read(testByte)
        val firstByteValue = BigInteger(testByte).toInt()
        println(firstByteValue)
        val deviceNameByteArray = ByteArray(64)
        val widthByteArray = ByteArray(2)
        val heightByteArray = ByteArray(2)
        inputStream.read(deviceNameByteArray)
        inputStream.read(widthByteArray)
        inputStream.read(heightByteArray)

        val name = String(deviceNameByteArray, StandardCharsets.UTF_8).replace("\u0000", "")
        val width = BigInteger(widthByteArray).toInt();
        val height = BigInteger(heightByteArray).toInt()
        deviceInfo.set("name", name)
        deviceInfo.set("width", width)
        deviceInfo.set("height", height)
        callback(deviceInfo)
        println(name)
        println(width)
        println(height)
    }

    fun start() {
        nativeSurfaceView!!.start(socket, inputStream)
    }

    fun disconnect(): Boolean {
        try {
            socket.close()
        } catch (e: IOException) {
            println(e.printStackTrace())
        }
        return true
    }

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val creationParams = args as Map<String?, Any?>?
        nativeSurfaceView = NativeSurfaceView(context, viewId, creationParams)
        return nativeSurfaceView!!
    }
}