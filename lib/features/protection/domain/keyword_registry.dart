/// Centralized registry of restricted keywords used for content scanning.
///
/// These keywords are matched against visible text extracted by the Android
/// accessibility service from high-risk applications. All matching is
/// case-insensitive and performed natively before any data crosses the
/// Flutter platform bridge.
///
/// Privacy note: This file defines keywords only. Scanned text is NEVER
/// stored, logged, or persisted. Only detection results (true/false +
/// matched keyword list) are held in runtime memory.
const List<String> keywordRegistry = [
  // Explicit content
  'porn',
  'porno',
  'pornography',
  'xxx',
  'adult video',
  'sex video',
  'sex tape',
  'nsfw',
  'nude',
  'nudity',
  'nudes',
  'onlyfans',
  'only fans',
  'hentai',
  'erotic',
  'erotica',
  'fetish',
  'camgirl',
  'cam girl',
  'webcam sex',
  'live sex',
  'free sex',
  'free porn',
  'watch porn',
  'hot sex',
  'sex chat',
  'sexting',
  'naked',
  'xvideos',
  'xnxx',
  'pornhub',
  'redtube',
  'youporn',
  'brazzers',
  'bangbros',
  'fapello',
  'xhamster',
  'spankbang',

  // Self-harm / suicide (detection for potential safeguarding)
  // Note: These are listed for awareness monitoring only and do NOT trigger
  // blocking. Phase 2D.1 is detection-only.
  'how to kill myself',
  'ways to commit suicide',
  'suicide methods',
  'self harm tutorial',
];
