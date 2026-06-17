package com.multimedia.player.ios_multimedia_player

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.media.MediaCodec
import java.nio.ByteBuffer
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    private val CONVERTER_CHANNEL = "com.videoplayermax.media/converter"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CONVERTER_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "extractAudio") {
                    val inputPath = call.argument<String>("inputPath")
                    val outputPath = call.argument<String>("outputPath")
                    if (inputPath != null && outputPath != null) {
                        Thread {
                            val success = extractAudioTrack(inputPath, outputPath)
                            runOnUiThread {
                                if (success) {
                                    result.success(outputPath)
                                } else {
                                    result.error("CONVERSION_FAILED", "Failed to extract audio natively on Android", null)
                                }
                            }
                        }.start()
                    } else {
                        result.error("INVALID_ARGUMENTS", "inputPath and outputPath must not be null", null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun extractAudioTrack(inputPath: String, outputPath: String): Boolean {
        var extractor: MediaExtractor? = null
        var muxer: MediaMuxer? = null
        try {
            extractor = MediaExtractor()
            extractor.setDataSource(inputPath)

            var audioTrackIndex = -1
            var audioFormat: MediaFormat? = null

            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME)
                if (mime != null && mime.startsWith("audio/")) {
                    audioTrackIndex = i
                    audioFormat = format
                    break
                }
            }

            if (audioTrackIndex == -1 || audioFormat == null) {
                return false
            }

            extractor.selectTrack(audioTrackIndex)

            val outputFile = File(outputPath)
            outputFile.parentFile?.mkdirs()

            muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            val trackIndex = muxer.addTrack(audioFormat)
            muxer.start()

            val maxBufferSize = if (audioFormat.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) {
                audioFormat.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE)
            } else {
                1024 * 1024
            }
            val buffer = ByteBuffer.allocate(maxBufferSize)
            val bufferInfo = MediaCodec.BufferInfo()

            while (true) {
                val sampleSize = extractor.readSampleData(buffer, 0)
                if (sampleSize < 0) {
                    break
                }

                bufferInfo.offset = 0
                bufferInfo.size = sampleSize
                bufferInfo.presentationTimeUs = extractor.sampleTime
                bufferInfo.flags = extractor.sampleFlags

                muxer.writeSampleData(trackIndex, buffer, bufferInfo)
                extractor.advance()
            }

            muxer.stop()
            return true
        } catch (e: Exception) {
            e.printStackTrace()
            return false
        } finally {
            extractor?.release()
            try {
                muxer?.release()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}
