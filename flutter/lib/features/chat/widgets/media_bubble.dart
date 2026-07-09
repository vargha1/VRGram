import 'dart:io';
import 'package:flutter/material.dart';
import '../providers/chat_provider.dart';
import '../../media/screens/image_viewer_screen.dart';
import '../../media/screens/video_player_screen.dart';
import '../../media/screens/file_viewer_screen.dart';

enum MediaBubbleType { image, voice, video, file }

class MediaBubble extends StatelessWidget {
  final ChatMessage message;

  const MediaBubble({super.key, required this.message});

  MediaBubbleType? get _type {
    final mime = message.mimeType;
    if (mime == null) return null;
    if (mime.startsWith('image/')) return MediaBubbleType.image;
    if (mime.startsWith('audio/')) return MediaBubbleType.voice;
    if (mime.startsWith('video/')) return MediaBubbleType.video;
    return MediaBubbleType.file;
  }

  @override
  Widget build(BuildContext context) {
    final type = _type;
    if (type == null) return const SizedBox.shrink();

    final progress = message.mediaProgress;
    if (progress != null && progress < 1.0) {
      return _buildProgressIndicator(progress);
    }

    switch (type) {
      case MediaBubbleType.image:
        return _buildImage(context);
      case MediaBubbleType.voice:
        return _buildVoice();
      case MediaBubbleType.video:
        return _buildVideo(context);
      case MediaBubbleType.file:
        return _buildFile(context);
    }
  }

  Widget _buildImage(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (message.localFilePath != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ImageViewerScreen(imagePath: message.localFilePath!),
            ),
          );
        }
      },
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: message.localFilePath != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(File(message.localFilePath!), fit: BoxFit.cover),
              )
            : const Icon(Icons.image, size: 48, color: Colors.grey),
      ),
    );
  }

  Widget _buildVoice() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: () {},
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          Text('Voice', style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildVideo(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (message.localFilePath != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VideoPlayerScreen(videoPath: message.localFilePath!),
            ),
          );
        }
      },
      child: Container(
        width: 200,
        height: 150,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Icon(Icons.play_circle, size: 48, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildFile(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (message.localFilePath != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FileViewerScreen(
                filePath: message.localFilePath!,
                fileName: message.filename ?? message.text,
              ),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insert_drive_file, size: 32),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.filename ?? message.text,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(double progress) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 8),
          Text(
            '${(progress * 100).toInt()}%',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
