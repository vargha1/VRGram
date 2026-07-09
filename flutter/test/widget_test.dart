import 'package:flutter_test/flutter_test.dart';
import 'package:vrgram/features/chat/widgets/media_picker.dart';

void main() {
  test('MediaAction enum values are correct', () {
    expect(MediaAction.values.length, 5);
    expect(MediaAction.values[0], MediaAction.camera);
    expect(MediaAction.values[1], MediaAction.gallery);
    expect(MediaAction.values[2], MediaAction.voice);
    expect(MediaAction.values[3], MediaAction.file);
    expect(MediaAction.values[4], MediaAction.video);
  });
}
