import 'models.dart';

class SongSection {
  const SongSection({
    required this.type,
    required this.label,
    required this.text,
  });

  final String type;
  final String label;
  final String text;
}

class Song {
  const Song({required this.title, required this.sections});
  final String title;
  final List<SongSection> sections;
}

const sampleSongs = [
  Song(
    title: 'Great Is Thy Faithfulness',
    sections: [
      SongSection(
        type: 'verse',
        label: 'Verse 1',
        text: 'Great is thy faithfulness, O God my Father',
      ),
      SongSection(
        type: 'chorus',
        label: 'Chorus',
        text: 'Great is Thy faithfulness, Lord unto me',
      ),
      SongSection(
        type: 'bridge',
        label: 'Bridge',
        text: 'Morning by morning new mercies I see',
      ),
    ],
  ),
  Song(
    title: 'Way Maker',
    sections: [
      SongSection(
        type: 'chorus',
        label: 'Chorus',
        text: 'Way maker, miracle worker, promise keeper',
      ),
    ],
  ),
];

const sampleScripture = [
  ScriptureDraft(
    reference: 'John 3:16',
    text:
        'For God so loved the world, that he gave his only begotten Son.',
  ),
  ScriptureDraft(
    reference: 'Psalm 23',
    text: 'The Lord is my shepherd; I shall not want.',
  ),
];
