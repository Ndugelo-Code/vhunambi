import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/studio/domain/models/lyrics_review_models.dart';

/// T12.1 — Studio lyrics review domain model suite.
void main() {
  group('lyricsSectionTypeFromTag', () {
    test('maps every supported bracketed tag onto its stanza type', () {
      expect(lyricsSectionTypeFromTag('Intro'), LyricsSectionType.intro);
      expect(lyricsSectionTypeFromTag('Verse 1'), LyricsSectionType.verse);
      expect(lyricsSectionTypeFromTag('chorus'), LyricsSectionType.chorus);
      expect(lyricsSectionTypeFromTag('Hook'), LyricsSectionType.hook);
      expect(lyricsSectionTypeFromTag('Bridge'), LyricsSectionType.bridge);
      expect(lyricsSectionTypeFromTag('Outro'), LyricsSectionType.outro);
    });

    test('falls back to verse for unknown tags', () {
      expect(lyricsSectionTypeFromTag('Ad-lib'), LyricsSectionType.verse);
      expect(lyricsSectionTypeFromTag('  '), LyricsSectionType.verse);
    });

    test('exposes human readable labels for the stanza badges', () {
      expect(lyricsSectionTypeLabel(LyricsSectionType.intro), 'Intro');
      expect(lyricsSectionTypeLabel(LyricsSectionType.chorus), 'Chorus');
      expect(lyricsSectionTypeLabel(LyricsSectionType.bridge), 'Bridge');
    });
  });

  group('parseLyricsSections', () {
    test('splits bracketed stanzas into typed, ordered sections', () {
      final sections = parseLyricsSections(_rawLyrics);

      expect(sections, hasLength(4));
      expect(
        sections.map((section) => section.type),
        <LyricsSectionType>[
          LyricsSectionType.intro,
          LyricsSectionType.verse,
          LyricsSectionType.chorus,
          LyricsSectionType.outro,
        ],
      );
      expect(sections[1].lines, <String>[
        'Ndi khou vhona the light',
        'Zwithu zwoṱhe zwi khou shuma',
      ]);
      expect(
        sections.map((section) => section.id),
        <String>['section_1', 'section_2', 'section_3', 'section_4'],
      );
    });

    test('keeps trailing header metadata and trims trailing blank lines', () {
      final sections = parseLyricsSections(
        '[Verse 1] • 8 bars\nLine one\nLine two\n\n\n[Chorus]\nSing it\n\n',
      );

      expect(sections.first.header, '[Verse 1] • 8 bars');
      expect(sections.first.type, LyricsSectionType.verse);
      expect(sections.first.lines, <String>['Line one', 'Line two']);
      expect(sections.last.lines, <String>['Sing it']);
    });

    test('turns leading free text into an implicit verse', () {
      final sections = parseLyricsSections(
        'Unofficial intro line\n\n[Chorus]\nChorus line',
      );

      expect(sections, hasLength(2));
      expect(sections.first.header, '[Verse]');
      expect(sections.first.lines, <String>['Unofficial intro line']);
      expect(sections.last.type, LyricsSectionType.chorus);
    });

    test('returns an empty list for blank lyrics', () {
      expect(parseLyricsSections('   \n\n'), isEmpty);
    });

    test('inherits stanza ids and rhyme notes by index on re-parse', () {
      final previous = <LyricsSection>[
        const LyricsSection(
          id: 'stanza_intro',
          type: LyricsSectionType.intro,
          header: '[Intro]',
          lines: <String>['old'],
          rhymeNotes: <String>['AABB'],
        ),
      ];

      final reparsed = parseLyricsSections(
        '[Intro]\nnew line\n[Chorus]\nfresh line',
        previous: previous,
      );

      expect(reparsed.first.id, 'stanza_intro');
      expect(reparsed.first.rhymeNotes, <String>['AABB']);
      expect(reparsed.first.lines, <String>['new line']);
      expect(reparsed.last.id, 'section_2');
    });
  });

  group('LyricsSection', () {
    test('toFormattedString round-trips header and lines', () {
      final section = parseLyricsSections(_rawLyrics).last;

      expect(section.toFormattedString(), '[Outro]\nSiyabonga, siyabonga');
      expect(
        parseLyricsSections(section.toFormattedString()).single.header,
        section.header,
      );
    });

    test('renders a header-only stanza when no lines are present', () {
      const section = LyricsSection(
        id: 'section_1',
        type: LyricsSectionType.bridge,
        header: '[Bridge]',
        lines: <String>[],
      );

      expect(section.toFormattedString(), '[Bridge]');
    });

    test('copyWith replaces lines and rhyme notes only', () {
      final section = parseLyricsSections(_rawLyrics).first;
      final edited = section.copyWith(
        lines: <String>['New hook'],
        rhymeNotes: <String>['free'],
      );

      expect(edited.lines, <String>['New hook']);
      expect(edited.rhymeNotes, <String>['free']);
      expect(edited.header, section.header);
      expect(edited.type, section.type);
      expect(edited.id, section.id);
    });

    test('equality is structural', () {
      final section = parseLyricsSections(_rawLyrics).first;

      expect(section, parseLyricsSections(_rawLyrics).first);
      expect(section.hashCode, parseLyricsSections(_rawLyrics).first.hashCode);
      expect(section, isNot(section.copyWith(lines: <String>['Other'])));
    });
  });

  group('LyricsReviewDraft', () {
    test('fromRawText parses stanzas and carries the studio metadata', () {
      final draft = LyricsReviewDraft.fromRawText(
        prompt: 'Amapiano anthem about heritage',
        genre: 'Amapiano',
        language: 'Tshivenḓa',
        rawText: _rawLyrics,
        culturalIdioms: <String>['Ndi khou vhona'],
      );

      expect(draft.prompt, 'Amapiano anthem about heritage');
      expect(draft.genre, 'Amapiano');
      expect(draft.language, 'Tshivenḓa');
      expect(draft.sectionCount, 4);
      expect(draft.sections.first.type, LyricsSectionType.intro);
      expect(draft.culturalIdioms, <String>['Ndi khou vhona']);
      expect(draft.isRawEditorMode, isFalse);
    });

    test('rebuildRawText joins every stanza with a blank line', () {
      final draft = LyricsReviewDraft.fromRawText(
        prompt: 'prompt',
        genre: 'Gqom',
        language: 'isiZulu',
        rawText: _rawLyrics,
      );

      final rebuilt = draft.rebuildRawText();

      expect(rebuilt.split('\n\n'), hasLength(4));
      expect(rebuilt, contains('[Chorus]'));
      expect(parseLyricsSections(rebuilt), draft.sections);
    });

    test('allLines and copyWith surface the edited draft state', () {
      final draft = LyricsReviewDraft.fromRawText(
        prompt: 'prompt',
        genre: 'Maskandi',
        language: 'Sepedi',
        rawText: _rawLyrics,
      );

      final raw = draft.copyWith(isRawEditorMode: true, rawText: '[Verse]\nhi');

      expect(draft.allLines, contains('Say it loud'));
      expect(raw.isRawEditorMode, isTrue);
      expect(raw.rawText, '[Verse]\nhi');
      expect(raw.sections, draft.sections);
      expect(raw, isNot(draft));
      expect(draft.sectionCount, 4);
    });
  });
}

/// Deterministic fixture shared by the parser, section and draft groups.
const String _rawLyrics = '[Intro]\nYebo, yebo\n'
    '[Verse 1]\nNdi khou vhona the light\nZwithu zwoṱhe zwi khou shuma\n'
    '[Chorus]\nSay it loud\n'
    '[Outro]\nSiyabonga, siyabonga';
