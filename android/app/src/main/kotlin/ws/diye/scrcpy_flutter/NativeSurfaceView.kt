package ws.diye.scrcpy_flutter

import android.content.Context
import android.media.MediaCodec
import android.media.MediaFormat
import android.os.Build
import android.os.Handler
import android.view.Surface
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import android.widget.Button
import androidx.annotation.RequiresApi
import io.flutter.plugin.platform.PlatformView
import java.io.InputStream
import java.math.BigInteger
import java.net.Socket
import java.nio.ByteBuffer
import java.util.concurrent.atomic.AtomicBoolean

internal class NativeSurfaceView(context: Context, id: Int, creationParams: Map<String?, Any?>?) : PlatformView {
    private val surfaceView: SurfaceView = SurfaceView(context)
    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    val codec = MediaCodec.createDecoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
    private var worker: Worker? = null
    private var socket: Socket? = null
    private var inputStream: InputStream? = null

    private var surfaceWidth = 600
    private var surfaceHeight = 1200

    override fun getView(): View {
        return surfaceView
    }

    override fun dispose() {
        socket!!.close()
        codec.stop()
    }

    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    fun configure() {
        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, surfaceWidth, surfaceHeight)
        codec.configure(format, surfaceView.holder.surface, null, 0)
        codec.start()
    }

    private fun initSurface() {
        surfaceView.holder.addCallback(object : SurfaceHolder.Callback {
            override fun surfaceCreated(p0: SurfaceHolder) {
//                surface = p0.surface
//                configure()
//                val worker = Worker(codec, inputStream)
//                worker.start()
            }

            override fun surfaceChanged(p0: SurfaceHolder, p1: Int, p2: Int, p3: Int) {
                println("surfaceChanged, $p1, $p2, $p3")
                surfaceWidth = p2
                surfaceHeight = p3
            }

            override fun surfaceDestroyed(p0: SurfaceHolder) {
                println("surfaceDestroyed")
                worker?.interrupt()
            }

        })
    }

    fun start(socket: Socket, inputStream: InputStream) {
        this.socket = socket
        this.inputStream = inputStream

        configure()
        worker = Worker(codec, inputStream!!)
        worker!!.start()
    }

    init {
        initSurface()
//        configure()
//        val worker = Worker(codec, inputStream)
//        worker.start()
    }
}

private class Worker(private val codec: MediaCodec, private val inputStream: InputStream) : Thread() {
    var isDead = false
    private lateinit var readStream: Thread
    fun decodeFrame(data: ByteArray, offset: Int, size: Int) {
        if (isDead) return
        val index = codec.dequeueInputBuffer(-1)
        if (index >= 0) {
            val buffer = codec.getInputBuffer(index)
            if (buffer != null) {
                buffer.put(data, offset, size)
                codec.queueInputBuffer(index, 0, size, 0, 0)
            }
        }
    }

    override fun interrupt() {
        super.interrupt()
        isDead = true
    }

    override fun run() {
        super.run()

        readStream = Thread {

            run() {
                try {
                    while (!isDead) {
                        val metaByteArray = ByteArray(8)
                        val sizeByteArray = ByteArray(4)
                        inputStream.read(metaByteArray)
                        inputStream.read(sizeByteArray)
                        val size = BigInteger(sizeByteArray).toInt()
                        val frameByteArray = ByteArray(size)
                        inputStream.read(frameByteArray)
                        decodeFrame(frameByteArray, 0, size)
                    }
                } catch (e: Exception) {
                    println(e.printStackTrace())
                }
            }
        }
        readStream.start()

        try {
            while (!isDead) {
                val info = MediaCodec.BufferInfo()
                val index = codec.dequeueOutputBuffer(info, 0)
                if (index >= 0) {
                    codec.releaseOutputBuffer(index, true)
                    if ((info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) == MediaCodec.BUFFER_FLAG_END_OF_STREAM) {
                        break
                    }
                }
            }
        } catch (e: Exception) {
            println(e.printStackTrace())
        }
    }
}