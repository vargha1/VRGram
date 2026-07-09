import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

enum MediaAction { camera, gallery, voice, file, video }

class MediaPicker extends StatelessWidget {
  final Function(MediaAction) onSelected;

  const MediaPicker({super.key, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _ActionButton(
              icon: Icons.camera_alt,
              label: 'Camera',
              onTap: () => onSelected(MediaAction.camera),
            ),
            _ActionButton(
              icon: Icons.photo_library,
              label: 'Gallery',
              onTap: () => onSelected(MediaAction.gallery),
            ),
            _ActionButton(
              icon: Icons.mic,
              label: 'Voice',
              onTap: () => onSelected(MediaAction.voice),
            ),
            _ActionButton(
              icon: Icons.attach_file,
              label: 'File',
              onTap: () => onSelected(MediaAction.file),
            ),
            _ActionButton(
              icon: Icons.videocam,
              label: 'Video',
              onTap: () => onSelected(MediaAction.video),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: IconButton(
        icon: Icon(icon, size: 28),
        onPressed: onTap,
      ),
    );
  }
}
