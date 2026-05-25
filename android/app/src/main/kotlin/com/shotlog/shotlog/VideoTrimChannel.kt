package com.shotlog.shotlog

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaMuxer
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer

class VideoTrimChannel : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "shotlog/video_trim"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "trimVideo") { result.notImplemented(); return }

        val input   = call.argument<String>("input")  ?: return result.error("ARGS", "missing input", null)
        val output  = call.argument<String>("output") ?: return result.error("ARGS", "missing output", null)
        val startMs = (call.argument<Int>("startMs") ?: 0).toLong()

        Thread {
            try {
                trim(input, output, startMs)
                result.success(output)
            } catch (e: Exception) {
                result.error("TRIM_ERROR", e.message, null)
            }
        }.start()
    }

    private fun trim(inputPath: String, outputPath: String, startMs: Long) {
        val extractor = MediaExtractor()
        extractor.setDataSource(inputPath)

        // Preserve video rotation from the source container.
        val retriever = MediaMetadataRetriever()
        retriever.setDataSource(inputPath)
        val rotation = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
            ?.toIntOrNull() ?: 0
        retriever.release()

        val muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        muxer.setOrientationHint(rotation)
        val trackMap = mutableMapOf<Int, Int>()

        for (i in 0 until extractor.trackCount) {
            val format = extractor.getTrackFormat(i)
            val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
            if (mime.startsWith("video/") || mime.startsWith("audio/")) {
                extractor.selectTrack(i)
                trackMap[i] = muxer.addTrack(format)
            }
        }

        muxer.start()

        // Seek to nearest keyframe at or before startMs.
        extractor.seekTo(startMs * 1000L, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)
        val actualStartUs = extractor.sampleTime.coerceAtLeast(0L)

        val bufferInfo = MediaCodec.BufferInfo()
        val buffer = ByteBuffer.allocate(2 * 1024 * 1024)

        while (true) {
            val sampleSize = extractor.readSampleData(buffer, 0)
            if (sampleSize < 0) break

            val trackIndex = extractor.sampleTrackIndex
            val outputTrack = trackMap[trackIndex]
            if (outputTrack == null) { extractor.advance(); continue }

            val pts = extractor.sampleTime - actualStartUs
            if (pts < 0) { extractor.advance(); continue }

            bufferInfo.offset = 0
            bufferInfo.size = sampleSize
            bufferInfo.presentationTimeUs = pts
            bufferInfo.flags = extractor.sampleFlags

            muxer.writeSampleData(outputTrack, buffer, bufferInfo)
            extractor.advance()
        }

        muxer.stop()
        muxer.release()
        extractor.release()
    }
}
