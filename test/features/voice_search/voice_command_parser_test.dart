import 'package:flutter_test/flutter_test.dart';
import 'package:videoplayer/features/voice_search/domain/entities/media_kind.dart';
import 'package:videoplayer/features/voice_search/domain/entities/video_search_query.dart';
import 'package:videoplayer/features/voice_search/domain/parser/voice_command_parser.dart';

void main() {
  // Fixed "now" so date-based assertions are deterministic.
  final fixedNow = DateTime(2026, 8, 8, 15, 30);
  VoiceCommandParser parser() => VoiceCommandParser(now: () => fixedNow);

  group('media kind', () {
    test('no kind word -> defaults to video', () {
      final q = parser().parse('recent videos');
      expect(q.mediaKind, MediaKind.video);
    });

    test('"photo dikhao" -> photo', () {
      final q = parser().parse('photo dikhao');
      expect(q.mediaKind, MediaKind.photo);
      expect(q.isEmpty, isFalse);
    });

    test('"image dikhao" -> photo', () {
      expect(parser().parse('image dikhao').mediaKind, MediaKind.photo);
    });

    test('"mp3 bolta hai to photo ya image dikhao" -> mp3 switches to music', () {
      // Real device testing surfaced this exact sentence; "mp3" must switch
      // to music even mid-sentence, ahead of "photo"/"image" which follow it.
      final q = parser().parse('mp3 bolta hai to photo ya image dikhao');
      expect(q.mediaKind, MediaKind.music);
    });

    test('"mp3 dikhao" -> music', () {
      expect(parser().parse('mp3 dikhao').mediaKind, MediaKind.music);
    });

    test('"gana dikhao" (Hindi for "song") -> music', () {
      expect(parser().parse('gana dikhao').mediaKind, MediaKind.music);
    });

    test('"Downloads folder ki photo dikhao" -> photo + folder combined', () {
      final q = parser().parse('Downloads folder ki photo dikhao');
      expect(q.mediaKind, MediaKind.photo);
      expect(q.folder, 'download');
    });

    test('"Sippy gana dikhao" -> music + filename text', () {
      final q = parser().parse('Sippy gana dikhao');
      expect(q.mediaKind, MediaKind.music);
      expect(q.text, 'sippy');
    });

    test('"mere photos dikhao" -> photo, "mere" must not leak into text', () {
      // Real device gap: only "mera"/"meri" were stopwords, not the plural
      // oblique form "mere" — it was leaking into the filename filter and
      // zeroing out every otherwise-correct photo search.
      final q = parser().parse('mere photos dikhao');
      expect(q.mediaKind, MediaKind.photo);
      expect(q.text, isNull);
    });

    test('"gaane sunao" -> music, "sunao" must not leak into text', () {
      final q = parser().parse('gaane sunao');
      expect(q.mediaKind, MediaKind.music);
      expect(q.text, isNull);
    });

    test('"Sippy gaana bajao" -> music + filename text', () {
      final q = parser().parse('Sippy gaana bajao');
      expect(q.mediaKind, MediaKind.music);
      expect(q.text, 'sippy');
    });
  });

  group('extension', () {
    test('"MP4 videos dikhao" -> extension only', () {
      final q = parser().parse('MP4 videos dikhao');
      expect(q.extension, 'mp4');
      expect(q.text, isNull);
      expect(q.folder, isNull);
      expect(q.minSizeBytes, isNull);
      expect(q.minDuration, isNull);
      expect(q.fromDate, isNull);
    });

    test('mixed case and extra whitespace are normalised the same way', () {
      final a = parser().parse('MP4 VIDEOS Dikhao');
      final b = parser().parse('  mp4   videos  dikhao  ');
      expect(a, b);
      expect(a.extension, 'mp4');
    });

    test('"MKV videos" -> extension mkv', () {
      expect(parser().parse('MKV videos').extension, 'mkv');
    });
  });

  group('folder', () {
    test('"Downloads videos" -> folder = download', () {
      final q = parser().parse('Downloads videos');
      expect(q.folder, 'download');
      expect(q.text, isNull);
    });

    test('"Downloads folder ki videos dikhao" -> folder = download', () {
      final q = parser().parse('Downloads folder ki videos dikhao');
      expect(q.folder, 'download');
      expect(q.text, isNull);
    });

    test('"WhatsApp ki videos dikhao" -> folder = whatsapp', () {
      final q = parser().parse('WhatsApp ki videos dikhao');
      expect(q.folder, 'whatsapp');
    });

    test('"Camera folder ki videos dikhao" -> folder = camera', () {
      final q = parser().parse('Camera folder ki videos dikhao');
      expect(q.folder, 'camera');
    });
  });

  group('date', () {
    test('"today videos" -> today\'s range', () {
      final q = parser().parse('today videos');
      expect(q.fromDate, DateTime(2026, 8, 8));
      expect(q.toDate, fixedNow);
    });

    test('"aaj ki videos dikhao" -> today\'s range', () {
      final q = parser().parse('aaj ki videos dikhao');
      expect(q.fromDate, DateTime(2026, 8, 8));
      expect(q.toDate, fixedNow);
    });

    test('"kal ki videos dikhao" -> yesterday (per spec: kal = yesterday)', () {
      final q = parser().parse('kal ki videos dikhao');
      expect(q.fromDate, DateTime(2026, 8, 7));
      expect(q.toDate, DateTime(2026, 8, 7, 23, 59, 59, 999));
    });

    test('"parso ki videos dikhao" -> day before yesterday', () {
      final q = parser().parse('parso ki videos dikhao');
      expect(q.fromDate, DateTime(2026, 8, 6));
      expect(q.toDate, DateTime(2026, 8, 6, 23, 59, 59, 999));
    });

    test('"last week ki videos dikhao" -> last 7 days', () {
      final q = parser().parse('last week ki videos dikhao');
      expect(q.fromDate, DateTime(2026, 8, 1));
      expect(q.toDate, fixedNow);
    });

    test(
      '"Mujhe parson ki video chahie" -> date only, "chahie" must not leak into text',
      () {
        final q = parser().parse('Mujhe parson ki video chahie');
        expect(q.fromDate, DateTime(2026, 8, 6));
        expect(q.toDate, DateTime(2026, 8, 6, 23, 59, 59, 999));
        expect(q.text, isNull);
      },
    );

    test('"pichle hafte ki videos" -> last 7 days', () {
      final q = parser().parse('pichle hafte ki videos');
      expect(q.fromDate, DateTime(2026, 8, 1));
      expect(q.toDate, fixedNow);
    });

    test('"recent videos" -> last 30 days, newest first', () {
      final q = parser().parse('recent videos');
      expect(q.fromDate, fixedNow.subtract(const Duration(days: 30)));
      expect(q.toDate, isNull);
      expect(q.sortBy, VideoSortOrder.dateDesc);
    });

    test('"latest videos" -> same as recent', () {
      final q = parser().parse('latest videos');
      expect(q.sortBy, VideoSortOrder.dateDesc);
    });
  });

  group('file size', () {
    test('"1 GB se badi videos dikhao" -> minSizeBytes = 1GB', () {
      final q = parser().parse('1 GB se badi videos dikhao');
      expect(q.minSizeBytes, 1024 * 1024 * 1024);
      expect(q.maxSizeBytes, isNull);
      expect(q.text, isNull);
    });

    test('"500 MB se choti videos dikhao" -> maxSizeBytes = 500MB', () {
      final q = parser().parse('500 MB se choti videos dikhao');
      expect(q.maxSizeBytes, 500 * 1024 * 1024);
      expect(q.minSizeBytes, isNull);
    });

    test('"1.5 GB se badi videos" -> decimal sizes parse correctly', () {
      final q = parser().parse('1.5 GB se badi videos');
      expect(q.minSizeBytes, (1.5 * 1024 * 1024 * 1024).round());
    });

    test('"badi videos dikhao" (no number) -> default min threshold', () {
      final q = parser().parse('badi videos dikhao');
      expect(q.minSizeBytes, 100 * 1024 * 1024);
    });

    test('"choti videos dikhao" (no number) -> default max threshold', () {
      final q = parser().parse('choti videos dikhao');
      expect(q.maxSizeBytes, 100 * 1024 * 1024);
    });

    test('"2 KB videos" with no direction word defaults to "at least"', () {
      final q = parser().parse('2 KB videos');
      expect(q.minSizeBytes, 2 * 1024);
    });
  });

  group('duration', () {
    test('"5 minute se zyada duration wali videos dikhao" -> minDuration = 5m', () {
      final q = parser().parse('5 minute se zyada duration wali videos dikhao');
      expect(q.minDuration, const Duration(minutes: 5));
      expect(q.maxDuration, isNull);
      expect(q.text, isNull);
    });

    test('"5 minute se lambi videos dikhao" -> minDuration = 5m', () {
      final q = parser().parse('5 minute se lambi videos dikhao');
      expect(q.minDuration, const Duration(minutes: 5));
    });

    test('"2 minute se choti videos dikhao" -> maxDuration = 2m', () {
      final q = parser().parse('2 minute se choti videos dikhao');
      expect(q.maxDuration, const Duration(minutes: 2));
    });

    test('"lambi videos dikhao" (no number) -> default min threshold', () {
      final q = parser().parse('lambi videos dikhao');
      expect(q.minDuration, const Duration(minutes: 10));
    });

    test('"1 hour se zyada videos" -> minDuration = 1 hour', () {
      final q = parser().parse('1 hour se zyada videos');
      expect(q.minDuration, const Duration(hours: 1));
    });
  });

  group('filename text search', () {
    test('"birthday video search karo" -> text = birthday', () {
      final q = parser().parse('birthday video search karo');
      expect(q.text, 'birthday');
      expect(q.folder, isNull);
      expect(q.extension, isNull);
    });

    test('"salman video dikhao" -> text = salman', () {
      expect(parser().parse('salman video dikhao').text, 'salman');
    });

    test('gibberish with no recognised keywords becomes free text', () {
      final q = parser().parse('asdkjfh qwer');
      expect(q.text, 'asdkjfh qwer');
    });
  });

  group('combined commands', () {
    test(
      '"Downloads folder me 1 GB se badi MP4 videos dikhao" -> folder + size + extension',
      () {
        final q =
            parser().parse('Downloads folder me 1 GB se badi MP4 videos dikhao');
        expect(q.folder, 'download');
        expect(q.minSizeBytes, 1024 * 1024 * 1024);
        expect(q.extension, 'mp4');
        expect(q.text, isNull);
      },
    );

    test(
      '"kal ki 5 minute se lambi videos dikhao" -> date + duration',
      () {
        final q = parser().parse('kal ki 5 minute se lambi videos dikhao');
        expect(q.fromDate, DateTime(2026, 8, 7));
        expect(q.toDate, DateTime(2026, 8, 7, 23, 59, 59, 999));
        expect(q.minDuration, const Duration(minutes: 5));
      },
    );
  });

  group('edge cases', () {
    test('empty string -> empty query', () {
      expect(parser().parse('').isEmpty, isTrue);
    });

    test('whitespace-only string -> empty query', () {
      expect(parser().parse('    ').isEmpty, isTrue);
    });

    test('only filler words -> empty query, not free text', () {
      final q = parser().parse('dikhao karo videos please');
      expect(q.isEmpty, isTrue);
      expect(q.text, isNull);
    });
  });
}
