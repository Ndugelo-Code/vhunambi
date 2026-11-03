import 'dart:math' as math;

import 'bantu_phonology.dart';

/// Cognate classification of a word pair.
enum BantuCognateType { direct, shifted, falseFriend }

/// Result of comparing two words from two Bantu languages.
class BantuSimilarityResult {
  const BantuSimilarityResult({
    required this.score,
    required this.type,
    required this.sourceWord,
    required this.targetWord,
    required this.source,
    required this.target,
    required this.levenshteinScore,
    required this.shiftScore,
    required this.nounClassScore,
    required this.route,
  });

  final int score;
  final BantuCognateType type;
  final String sourceWord;
  final String targetWord;
  final BantuLanguage source;
  final BantuLanguage target;
  final int levenshteinScore;
  final int shiftScore;
  final int nounClassScore;
  final BantuRoute route;
}

/// A routing plan between two languages. By construction it only ever
/// contains the two endpoints: there is no hub / pivot language.
class BantuRoute {
  const BantuRoute({required this.hops, required this.isIntraBranch});

  final List<BantuLanguage> hops;
  final bool isIntraBranch;
}

/// Plans language routes. Always direct (peer-branch topology).
class BantuRoutePlanner {
  const BantuRoutePlanner._();

  static BantuRoute route(BantuLanguage source, BantuLanguage target) {
    return BantuRoute(
      hops: List.unmodifiable([source, target]),
      isIntraBranch: source.branch == target.branch,
    );
  }
}

/// One directional cross-branch sound correspondence.
class PairwiseShiftRule {
  const PairwiseShiftRule({
    required this.from,
    required this.to,
    required this.sourceBranch,
    required this.targetBranch,
    this.initialOnly = false,
    this.finalOnly = false,
    this.description = '',
  });

  final String from;
  final String to;
  final BantuLanguageBranch sourceBranch;
  final BantuLanguageBranch targetBranch;
  final bool initialOnly;
  final bool finalOnly;
  final String description;
}

/// Flag indicating that shift and prefix rules are a starter set (REQ-BANTU-SIM-06).
const bool kBantuTablesValidated = false;

/// Pure-Dart cognate scorer for peer-branch Southern Bantu languages.
///
/// score = round(0.40 * Levenshtein + 0.30 * PairwiseShift + 0.30 * NounClass)
///
/// * Intra-branch pairs use identity routing: no shift rules are applied
///   (the branches share their phonology), so the shift term equals the
///   direct stem similarity.
/// * Cross-branch pairs apply the pairwise `sourceBranch -> targetBranch`
///   rules below.
///
/// The rule and prefix tables are a STARTER set (from Zania Explore) that
/// requires native-speaker / linguist validation.
class BantuSimilarity {
  const BantuSimilarity._();

  static const List<PairwiseShiftRule> shiftRules = [
    PairwiseShiftRule(
      from: 'th',
      to: 'r',
      sourceBranch: BantuLanguageBranch.nguni,
      targetBranch: BantuLanguageBranch.tshivenda,
      description: 'Nguni th ~ Venda r',
    ),
    PairwiseShiftRule(
      from: 'l',
      to: 'h',
      sourceBranch: BantuLanguageBranch.nguni,
      targetBranch: BantuLanguageBranch.tshivenda,
      initialOnly: true,
      description: 'Nguni l- ~ Venda h- (lapha/hafha)',
    ),
    PairwiseShiftRule(
      from: 'q',
      to: 'fh',
      sourceBranch: BantuLanguageBranch.nguni,
      targetBranch: BantuLanguageBranch.tshivenda,
      description: 'Nguni click q ~ Venda fh (qeda/fhela)',
    ),
    PairwiseShiftRule(
      from: 'ny',
      to: 'n',
      sourceBranch: BantuLanguageBranch.tshivenda,
      targetBranch: BantuLanguageBranch.nguni,
      description: 'Venda ny ~ Nguni n',
    ),
    PairwiseShiftRule(
      from: 'dz',
      to: 'z',
      sourceBranch: BantuLanguageBranch.tshivenda,
      targetBranch: BantuLanguageBranch.nguni,
      description: 'Venda dz ~ Nguni z',
    ),
    PairwiseShiftRule(
      from: 'dz',
      to: 'z',
      sourceBranch: BantuLanguageBranch.tshivenda,
      targetBranch: BantuLanguageBranch.sothoTswana,
      description: 'Venda dz ~ Sotho-Tswana z',
    ),
    PairwiseShiftRule(
      from: 'f',
      to: 'p',
      sourceBranch: BantuLanguageBranch.sothoTswana,
      targetBranch: BantuLanguageBranch.nguni,
      description: 'Sotho-Tswana f ~ Nguni p',
    ),
    PairwiseShiftRule(
      from: 'tl',
      to: 'kl',
      sourceBranch: BantuLanguageBranch.sothoTswana,
      targetBranch: BantuLanguageBranch.nguni,
      description: 'Sotho-Tswana tl ~ Nguni kl',
    ),
    PairwiseShiftRule(
      from: 'k',
      to: 'g',
      sourceBranch: BantuLanguageBranch.nguni,
      targetBranch: BantuLanguageBranch.sothoTswana,
      description: 'Nguni k ~ Sotho-Tswana g',
    ),
    PairwiseShiftRule(
      from: 'b',
      to: 'p',
      sourceBranch: BantuLanguageBranch.nguni,
      targetBranch: BantuLanguageBranch.sothoTswana,
      finalOnly: true,
      description: 'Final devoicing Nguni b ~ Sotho-Tswana p',
    ),
  ];

  /// Noun-class prefixes per language: class number -> prefixes (longest
  /// match wins). Class 1/3 and 9 share surface forms in several languages so
  /// only unambiguous classes are listed.
  static const Map<BantuLanguage, Map<int, List<String>>> nounClassPrefixes = {
    BantuLanguage.zu: _nguniPrefixes,
    BantuLanguage.ss: _nguniPrefixes,
    BantuLanguage.nr: _nguniPrefixes,
    BantuLanguage.xh: _nguniPrefixes,
    BantuLanguage.nso: {
      1: ['mo'], 2: ['ba'], 4: ['me'], 5: ['le'], 6: ['ma'], //
      7: ['se'], 8: ['di'], 14: ['bo'], 15: ['go'],
    },
    BantuLanguage.tn: {
      1: ['mo'], 2: ['ba'], 4: ['me'], 5: ['le'], 6: ['ma'], //
      7: ['se'], 8: ['di'], 14: ['bo'], 15: ['go'],
    },
    BantuLanguage.st: {
      1: ['mo'], 2: ['ba'], 4: ['me'], 5: ['le'], 6: ['ma'], //
      7: ['se'], 8: ['di'], 14: ['bo'], 15: ['ho'],
    },
    BantuLanguage.ve: {
      1: ['mu'], 2: ['vha'], 4: ['mi'], 5: ['ḽi', 'li'], 6: ['ma'], //
      7: ['tshi'], 8: ['zwi'], 10: ['dzi'], 14: ['vhu'], 15: ['u'],
    },
    BantuLanguage.ts: {
      1: ['mu'], 2: ['va'], 4: ['mi'], 5: ['ri'], 6: ['ma'], //
      7: ['xi'], 8: ['swi'], 14: ['vu'], 15: ['ku'],
    },
  };

  static const Map<int, List<String>> _nguniPrefixes = {
    1: ['umu', 'um'],
    2: ['aba', 'abe'],
    4: ['imi'],
    5: ['ili'],
    6: ['ama'],
    7: ['isi'],
    8: ['izi'],
    14: ['ubu'],
    15: ['uku'],
  };

  /// Compares [sourceWord] (in [source]) with [targetWord] (in [target]).
  static BantuSimilarityResult compare(
    String sourceWord,
    BantuLanguage source,
    String targetWord,
    BantuLanguage target,
  ) {
    final route = BantuRoutePlanner.route(source, target);
    final srcNorm = sourceWord.trim().toLowerCase();
    final tgtNorm = targetWord.trim().toLowerCase();

    final srcSplit = _splitPrefix(srcNorm, source);
    final tgtSplit = _splitPrefix(tgtNorm, target);

    final lev = _similarity(srcSplit.stem, tgtSplit.stem);

    int shift;
    if (route.isIntraBranch) {
      // Identity routing inside a branch: no rule is applied.
      shift = lev;
    } else {
      final shifted = applyShifts(srcSplit.stem, source.branch, target.branch);
      shift = math.max(lev, _similarity(shifted, tgtSplit.stem));
    }

    int nounClass;
    if (srcNorm == tgtNorm && source == target) {
      nounClass = 100;
    } else if (srcSplit.classNumber != null && tgtSplit.classNumber != null) {
      nounClass = srcSplit.classNumber == tgtSplit.classNumber ? 100 : 0;
    } else if (srcSplit.classNumber == null && tgtSplit.classNumber == null) {
      nounClass = srcSplit.stem == tgtSplit.stem ? 100 : 50;
    } else {
      nounClass = 40;
    }

    final score = (0.40 * lev + 0.30 * shift + 0.30 * nounClass).round();
    final BantuCognateType type;
    if (score > 80) {
      type = BantuCognateType.direct;
    } else if (score >= 50) {
      type = BantuCognateType.shifted;
    } else {
      type = BantuCognateType.falseFriend;
    }

    return BantuSimilarityResult(
      score: score,
      type: type,
      sourceWord: sourceWord,
      targetWord: targetWord,
      source: source,
      target: target,
      levenshteinScore: lev,
      shiftScore: shift,
      nounClassScore: nounClass,
      route: route,
    );
  }

  /// Searches for cognates for [word] in [source] against [candidates] in [target].
  static List<BantuSimilarityResult> findCognates({
    required String word,
    required BantuLanguage source,
    required List<String> candidates,
    required BantuLanguage target,
    int minScore = 50,
  }) {
    final results = <BantuSimilarityResult>[];
    for (final cand in candidates) {
      final res = compare(word, source, cand, target);
      if (res.score >= minScore) {
        results.add(res);
      }
    }
    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  /// Applies the pairwise `from -> to` branch rules to [stem]. Returns [stem]
  /// unchanged for intra-branch pairs.
  static String applyShifts(
    String stem,
    BantuLanguageBranch from,
    BantuLanguageBranch to,
  ) {
    if (from == to) return stem;
    var out = stem;
    for (final r in shiftRules) {
      if (r.sourceBranch != from || r.targetBranch != to) continue;
      if (r.initialOnly) {
        if (out.startsWith(r.from)) {
          out = r.to + out.substring(r.from.length);
        }
      } else if (r.finalOnly) {
        if (out.endsWith(r.from)) {
          out = out.substring(0, out.length - r.from.length) + r.to;
        }
      } else {
        out = out.replaceAll(r.from, r.to);
      }
    }
    return out;
  }

  static ({String stem, int? classNumber}) _splitPrefix(
    String word,
    BantuLanguage language,
  ) {
    final table = nounClassPrefixes[language];
    if (table == null) return (stem: word, classNumber: null);
    String? bestPrefix;
    int? bestClass;
    table.forEach((cls, prefixes) {
      for (final p in prefixes) {
        if (word.startsWith(p) &&
            word.length - p.length >= 2 &&
            (bestPrefix == null || p.length > bestPrefix!.length)) {
          bestPrefix = p;
          bestClass = cls;
        }
      }
    });
    if (bestPrefix == null) return (stem: word, classNumber: null);
    return (stem: word.substring(bestPrefix!.length), classNumber: bestClass);
  }

  static int _similarity(String a, String b) {
    if (a.isEmpty && b.isEmpty) return 100;
    final maxLen = math.max(a.runes.length, b.runes.length);
    if (maxLen == 0) return 100;
    final d = _levenshtein(a, b);
    return ((1.0 - d / maxLen).clamp(0.0, 1.0) * 100).round();
  }

  static int _levenshtein(String a, String b) {
    final ar = a.runes.toList();
    final br = b.runes.toList();
    var prev = List<int>.generate(br.length + 1, (i) => i);
    for (var i = 1; i <= ar.length; i++) {
      final cur = List<int>.filled(br.length + 1, 0)..[0] = i;
      for (var j = 1; j <= br.length; j++) {
        final cost = ar[i - 1] == br[j - 1] ? 0 : 1;
        cur[j] = math.min(
          math.min(cur[j - 1] + 1, prev[j] + 1),
          prev[j - 1] + cost,
        );
      }
      prev = cur;
    }
    return prev[br.length];
  }
}

