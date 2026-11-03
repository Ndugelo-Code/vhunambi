/// Peer-branch Southern Bantu model (Phase 36, Track A).
///
/// Tshivenda is a PEER branch alongside Nguni, Sotho-Tswana and Tswa-Ronga.
/// There is deliberately no hub / pivot branch anywhere in this model:
/// routing a Nguni pair through any other branch destroys shared branch
/// features (e.g. clicks), so intra-branch pairs always map directly.
library;

/// The four equal peer branches of Southern Bantu (Guthrie zones S20-S50).
const double kDepressorOnsetExemptionDurationMs = 60.0;
const double kLexicalTonePolarityMinDeltaSt = 2.0;

enum BantuLanguageBranch {
  nguni('S40', 'Nguni'),
  sothoTswana('S30', 'Sotho-Tswana'),
  tshivenda('S20', 'Tshivenda'),
  tswaRonga('S50', 'Tswa-Ronga');

  const BantuLanguageBranch(this.guthrieZone, this.label);

  final String guthrieZone;
  final String label;
}

/// The nine mainstream Southern Bantu languages supported by Vhunambi.
enum BantuLanguage {
  zu('zu', 'isiZulu', BantuLanguageBranch.nguni),
  xh('xh', 'isiXhosa', BantuLanguageBranch.nguni),
  ss('ss', 'siSwati', BantuLanguageBranch.nguni),
  nr('nr', 'isiNdebele', BantuLanguageBranch.nguni),
  nso('nso', 'Sepedi', BantuLanguageBranch.sothoTswana),
  tn('tn', 'Setswana', BantuLanguageBranch.sothoTswana),
  st('st', 'Sesotho', BantuLanguageBranch.sothoTswana),
  ve('ve', 'Tshivenda', BantuLanguageBranch.tshivenda),
  ts('ts', 'Xitsonga', BantuLanguageBranch.tswaRonga);

  const BantuLanguage(this.code, this.displayName, this.branch);

  final String code;
  final String displayName;
  final BantuLanguageBranch branch;

  static BantuLanguage? fromCode(String? code) {
    if (code == null) return null;
    final base = code.toLowerCase().split(RegExp('[-_]')).first;
    for (final l in BantuLanguage.values) {
      if (l.code == base) return l;
    }
    return null;
  }
}

/// Branch-specific phonological protection profile consumed by the vocal
/// idealizer DSP guards.
///
/// NOTE: the grapheme lists are a STARTER set derived from Zania Explore's
/// phonology modules and need native-speaker validation before being treated
/// as authoritative.
class BantuBranchProfile {
  const BantuBranchProfile({
    required this.branch,
    required this.hasDepressorOnsets,
    required this.protectedGraphemes,
    required this.notes,
  });

  final BantuLanguageBranch branch;

  /// Voiced depressor consonants lower F0 of the following vowel onset.
  final bool hasDepressorOnsets;

  /// Graphemes whose acoustic realisation must not be smeared/flattened.
  final List<String> protectedGraphemes;

  final String notes;

  /// Duration (ms) at the start of a voiced run that is exempt from full
  /// scale-lock correction when [hasDepressorOnsets] is true.
  int get depressorExemptMs => hasDepressorOnsets ? 60 : 0;

  static const BantuBranchProfile nguni = BantuBranchProfile(
    branch: BantuLanguageBranch.nguni,
    hasDepressorOnsets: true,
    protectedGraphemes: [
      'c', 'q', 'x', 'ch', 'qh', 'xh', 'gc', 'gq', 'gx', 'nc', 'nq', 'nx', //
      'b', 'd', 'g', 'z', 'j', 'v', // depressors
    ],
    notes: 'Clicks (c/q/x series) and depressor-consonant onsets.',
  );

  static const BantuBranchProfile sothoTswana = BantuBranchProfile(
    branch: BantuLanguageBranch.sothoTswana,
    hasDepressorOnsets: false,
    protectedGraphemes: ['tl', 'tlh', 'kg', 'tlh', 'ph', 'th', 'kh'],
    notes: 'Lateral affricates and 7-vowel height contrasts (e/E, o/O).',
  );

  static const BantuBranchProfile tshivenda = BantuBranchProfile(
    branch: BantuLanguageBranch.tshivenda,
    hasDepressorOnsets: true,
    protectedGraphemes: [
      'ḓ',
      'ṱ',
      'ṋ',
      'ḽ',
      'ṅ',
      'vh',
      'fh',
      'dz',
      'ts',
      'tsh',
    ],
    notes: 'Dental plosives/nasals, lateral flap and breathy vh.',
  );

  static const BantuBranchProfile tswaRonga = BantuBranchProfile(
    branch: BantuLanguageBranch.tswaRonga,
    hasDepressorOnsets: false,
    protectedGraphemes: ['sw', 'zv', 'xh', 'hl', 'ts', 'dz'],
    notes: 'Whistled sibilants and aspirated nasals.',
  );

  static BantuBranchProfile forBranch(BantuLanguageBranch branch) {
    switch (branch) {
      case BantuLanguageBranch.nguni:
        return nguni;
      case BantuLanguageBranch.sothoTswana:
        return sothoTswana;
      case BantuLanguageBranch.tshivenda:
        return tshivenda;
      case BantuLanguageBranch.tswaRonga:
        return tswaRonga;
    }
  }

  static BantuBranchProfile forLanguage(BantuLanguage language) =>
      forBranch(language.branch);

  static BantuBranchProfile profileFor(BantuLanguageBranch branch) =>
      forBranch(branch);
}

typedef BantuPhonology = BantuBranchProfile;
