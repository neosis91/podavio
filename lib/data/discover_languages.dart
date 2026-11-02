import 'package:podcast_search/podcast_search.dart';

/// Valeur enregistrée quand Explorer ne filtre plus par langue.
const discoverLanguagesAll = '*';

const discoverLanguagesDefault = <String>['fr'];

/// Nombre max de boutiques Apple interrogées pour une sélection.
const discoverAppleStoreLimit = 8;

class DiscoverLanguage {
  const DiscoverLanguage(this.code, this.label);

  final String code;
  final String label;
}

/// Codes ISO 639-1 et variantes régionales du RSS Language Spec.
const discoverLanguageCatalog = <DiscoverLanguage>[
  DiscoverLanguage('ab', 'Abkhaze'),
  DiscoverLanguage('aa', 'Afar'),
  DiscoverLanguage('af', 'Afrikaans'),
  DiscoverLanguage('ak', 'Akan'),
  DiscoverLanguage('sq', 'Albanais'),
  DiscoverLanguage('de', 'Allemand'),
  DiscoverLanguage('de-de', 'Allemand (Allemagne)'),
  DiscoverLanguage('de-at', 'Allemand (Autriche)'),
  DiscoverLanguage('de-li', 'Allemand (Liechtenstein)'),
  DiscoverLanguage('de-lu', 'Allemand (Luxembourg)'),
  DiscoverLanguage('de-ch', 'Allemand (Suisse)'),
  DiscoverLanguage('am', 'Amharique'),
  DiscoverLanguage('en', 'Anglais'),
  DiscoverLanguage('en-za', 'Anglais (Afrique du Sud)'),
  DiscoverLanguage('en-au', 'Anglais (Australie)'),
  DiscoverLanguage('en-bz', 'Anglais (Belize)'),
  DiscoverLanguage('en-ca', 'Anglais (Canada)'),
  DiscoverLanguage('en-us', 'Anglais (États-Unis)'),
  DiscoverLanguage('en-ie', 'Anglais (Irlande)'),
  DiscoverLanguage('en-jm', 'Anglais (Jamaïque)'),
  DiscoverLanguage('en-nz', 'Anglais (Nouvelle-Zélande)'),
  DiscoverLanguage('en-ph', 'Anglais (Philippines)'),
  DiscoverLanguage('en-gb', 'Anglais (Royaume-Uni)'),
  DiscoverLanguage('en-tt', 'Anglais (Trinité-et-Tobago)'),
  DiscoverLanguage('en-zw', 'Anglais (Zimbabwe)'),
  DiscoverLanguage('ar', 'Arabe'),
  DiscoverLanguage('ar-dz', 'Arabe (Algérie)'),
  DiscoverLanguage('ar-sa', 'Arabe (Arabie saoudite)'),
  DiscoverLanguage('ar-bh', 'Arabe (Bahreïn)'),
  DiscoverLanguage('ar-eg', 'Arabe (Égypte)'),
  DiscoverLanguage('ar-ae', 'Arabe (Émirats arabes unis)'),
  DiscoverLanguage('ar-iq', 'Arabe (Irak)'),
  DiscoverLanguage('ar-jo', 'Arabe (Jordanie)'),
  DiscoverLanguage('ar-kw', 'Arabe (Koweït)'),
  DiscoverLanguage('ar-lb', 'Arabe (Liban)'),
  DiscoverLanguage('ar-ly', 'Arabe (Libye)'),
  DiscoverLanguage('ar-ma', 'Arabe (Maroc)'),
  DiscoverLanguage('ar-om', 'Arabe (Oman)'),
  DiscoverLanguage('ar-qa', 'Arabe (Qatar)'),
  DiscoverLanguage('ar-sy', 'Arabe (Syrie)'),
  DiscoverLanguage('ar-tn', 'Arabe (Tunisie)'),
  DiscoverLanguage('ar-ye', 'Arabe (Yémen)'),
  DiscoverLanguage('an', 'Aragonais'),
  DiscoverLanguage('hy', 'Arménien'),
  DiscoverLanguage('as', 'Assamais'),
  DiscoverLanguage('av', 'Avar'),
  DiscoverLanguage('ae', 'Avestique'),
  DiscoverLanguage('ay', 'Aymara'),
  DiscoverLanguage('az', 'Azéri'),
  DiscoverLanguage('ba', 'Bachkir'),
  DiscoverLanguage('bm', 'Bambara'),
  DiscoverLanguage('eu', 'Basque'),
  DiscoverLanguage('bn', 'Bengali'),
  DiscoverLanguage('bi', 'Bichelamar'),
  DiscoverLanguage('be', 'Biélorusse'),
  DiscoverLanguage('bh', 'Bihari'),
  DiscoverLanguage('my', 'Birman'),
  DiscoverLanguage('bs', 'Bosnien'),
  DiscoverLanguage('br', 'Breton'),
  DiscoverLanguage('bg', 'Bulgare'),
  DiscoverLanguage('ks', 'Cachemiri'),
  DiscoverLanguage('ca', 'Catalan'),
  DiscoverLanguage('ch', 'Chamorro'),
  DiscoverLanguage('ny', 'Chichewa'),
  DiscoverLanguage('zh', 'Chinois'),
  DiscoverLanguage('zh-cn', 'Chinois (simplifié)'),
  DiscoverLanguage('zh-tw', 'Chinois (traditionnel)'),
  DiscoverLanguage('si', 'Cingalais'),
  DiscoverLanguage('ko', 'Coréen'),
  DiscoverLanguage('kw', 'Cornique'),
  DiscoverLanguage('co', 'Corse'),
  DiscoverLanguage('ht', 'Créole haïtien'),
  DiscoverLanguage('cr', 'Cri'),
  DiscoverLanguage('hr', 'Croate'),
  DiscoverLanguage('da', 'Danois'),
  DiscoverLanguage('dz', 'Dzongkha'),
  DiscoverLanguage('es', 'Espagnol'),
  DiscoverLanguage('es-ar', 'Espagnol (Argentine)'),
  DiscoverLanguage('es-bo', 'Espagnol (Bolivie)'),
  DiscoverLanguage('es-cl', 'Espagnol (Chili)'),
  DiscoverLanguage('es-co', 'Espagnol (Colombie)'),
  DiscoverLanguage('es-cr', 'Espagnol (Costa Rica)'),
  DiscoverLanguage('es-ec', 'Espagnol (Équateur)'),
  DiscoverLanguage('es-es', 'Espagnol (Espagne)'),
  DiscoverLanguage('es-gt', 'Espagnol (Guatemala)'),
  DiscoverLanguage('es-hn', 'Espagnol (Honduras)'),
  DiscoverLanguage('es-mx', 'Espagnol (Mexique)'),
  DiscoverLanguage('es-ni', 'Espagnol (Nicaragua)'),
  DiscoverLanguage('es-pa', 'Espagnol (Panama)'),
  DiscoverLanguage('es-py', 'Espagnol (Paraguay)'),
  DiscoverLanguage('es-pe', 'Espagnol (Pérou)'),
  DiscoverLanguage('es-pr', 'Espagnol (Porto Rico)'),
  DiscoverLanguage('es-do', 'Espagnol (République dominicaine)'),
  DiscoverLanguage('es-sv', 'Espagnol (Salvador)'),
  DiscoverLanguage('es-uy', 'Espagnol (Uruguay)'),
  DiscoverLanguage('es-ve', 'Espagnol (Venezuela)'),
  DiscoverLanguage('eo', 'Espéranto'),
  DiscoverLanguage('et', 'Estonien'),
  DiscoverLanguage('ee', 'Ewe'),
  DiscoverLanguage('fo', 'Féroïen'),
  DiscoverLanguage('fj', 'Fidjien'),
  DiscoverLanguage('fi', 'Finnois'),
  DiscoverLanguage('fr', 'Français'),
  DiscoverLanguage('fr-be', 'Français (Belgique)'),
  DiscoverLanguage('fr-ca', 'Français (Canada)'),
  DiscoverLanguage('fr-fr', 'Français (France)'),
  DiscoverLanguage('fr-lu', 'Français (Luxembourg)'),
  DiscoverLanguage('fr-mc', 'Français (Monaco)'),
  DiscoverLanguage('fr-ch', 'Français (Suisse)'),
  DiscoverLanguage('fy', 'Frison'),
  DiscoverLanguage('gd', 'Gaélique'),
  DiscoverLanguage('gl', 'Galicien'),
  DiscoverLanguage('cy', 'Gallois'),
  DiscoverLanguage('lg', 'Ganda'),
  DiscoverLanguage('ka', 'Géorgien'),
  DiscoverLanguage('el', 'Grec'),
  DiscoverLanguage('kl', 'Groenlandais'),
  DiscoverLanguage('gn', 'Guarani'),
  DiscoverLanguage('gu', 'Gujarati'),
  DiscoverLanguage('ha', 'Haoussa'),
  DiscoverLanguage('haw', 'Hawaïen'),
  DiscoverLanguage('he', 'Hébreu'),
  DiscoverLanguage('hz', 'Héréro'),
  DiscoverLanguage('hi', 'Hindi'),
  DiscoverLanguage('ho', 'Hiri motu'),
  DiscoverLanguage('hu', 'Hongrois'),
  DiscoverLanguage('io', 'Ido'),
  DiscoverLanguage('ig', 'Igbo'),
  DiscoverLanguage('in', 'Indonésien'),
  DiscoverLanguage('ia', 'Interlingua'),
  DiscoverLanguage('iu', 'Inuktitut'),
  DiscoverLanguage('ik', 'Inupiak'),
  DiscoverLanguage('ga', 'Irlandais'),
  DiscoverLanguage('is', 'Islandais'),
  DiscoverLanguage('it', 'Italien'),
  DiscoverLanguage('it-it', 'Italien (Italie)'),
  DiscoverLanguage('it-ch', 'Italien (Suisse)'),
  DiscoverLanguage('ja', 'Japonais'),
  DiscoverLanguage('jv', 'Javanais'),
  DiscoverLanguage('kn', 'Kannada'),
  DiscoverLanguage('kr', 'Kanouri'),
  DiscoverLanguage('kk', 'Kazakh'),
  DiscoverLanguage('km', 'Khmer'),
  DiscoverLanguage('kg', 'Kikongo'),
  DiscoverLanguage('ki', 'Kikuyu'),
  DiscoverLanguage('rw', 'Kinyarwanda'),
  DiscoverLanguage('ky', 'Kirghiz'),
  DiscoverLanguage('rn', 'Kirundi'),
  DiscoverLanguage('kv', 'Komi'),
  DiscoverLanguage('kj', 'Kuanyama'),
  DiscoverLanguage('ku', 'Kurde'),
  DiscoverLanguage('lo', 'Lao'),
  DiscoverLanguage('la', 'Latin'),
  DiscoverLanguage('lv', 'Letton'),
  DiscoverLanguage('li', 'Limbourgeois'),
  DiscoverLanguage('ln', 'Lingala'),
  DiscoverLanguage('lt', 'Lituanien'),
  DiscoverLanguage('lu', 'Luba'),
  DiscoverLanguage('lb', 'Luxembourgeois'),
  DiscoverLanguage('mk', 'Macédonien'),
  DiscoverLanguage('ms', 'Malais'),
  DiscoverLanguage('ml', 'Malayalam'),
  DiscoverLanguage('dv', 'Maldivien'),
  DiscoverLanguage('mg', 'Malgache'),
  DiscoverLanguage('mt', 'Maltais'),
  DiscoverLanguage('gv', 'Mannois'),
  DiscoverLanguage('mi', 'Maori'),
  DiscoverLanguage('mr', 'Marathi'),
  DiscoverLanguage('mh', 'Marshallais'),
  DiscoverLanguage('mn', 'Mongol'),
  DiscoverLanguage('na', 'Nauruan'),
  DiscoverLanguage('nv', 'Navajo'),
  DiscoverLanguage('nd', 'Ndébélé du Nord'),
  DiscoverLanguage('nr', 'Ndébélé du Sud'),
  DiscoverLanguage('ng', 'Ndonga'),
  DiscoverLanguage('nl', 'Néerlandais'),
  DiscoverLanguage('nl-be', 'Néerlandais (Belgique)'),
  DiscoverLanguage('nl-nl', 'Néerlandais (Pays-Bas)'),
  DiscoverLanguage('ne', 'Népalais'),
  DiscoverLanguage('no', 'Norvégien'),
  DiscoverLanguage('nb', 'Norvégien bokmål'),
  DiscoverLanguage('nn', 'Norvégien nynorsk'),
  DiscoverLanguage('ie', 'Occidental'),
  DiscoverLanguage('oc', 'Occitan'),
  DiscoverLanguage('oj', 'Ojibwé'),
  DiscoverLanguage('or', 'Oriya'),
  DiscoverLanguage('om', 'Oromo'),
  DiscoverLanguage('os', 'Ossète'),
  DiscoverLanguage('ug', 'Ouïghour'),
  DiscoverLanguage('ur', 'Ourdou'),
  DiscoverLanguage('uz', 'Ouzbek'),
  DiscoverLanguage('ps', 'Pachto'),
  DiscoverLanguage('pi', 'Pali'),
  DiscoverLanguage('pa', 'Pendjabi'),
  DiscoverLanguage('fa', 'Persan'),
  DiscoverLanguage('ff', 'Peul'),
  DiscoverLanguage('pl', 'Polonais'),
  DiscoverLanguage('pt', 'Portugais'),
  DiscoverLanguage('pt-br', 'Portugais (Brésil)'),
  DiscoverLanguage('pt-pt', 'Portugais (Portugal)'),
  DiscoverLanguage('qu', 'Quechua'),
  DiscoverLanguage('rm', 'Romanche'),
  DiscoverLanguage('ro', 'Roumain'),
  DiscoverLanguage('ro-mo', 'Roumain (Moldavie)'),
  DiscoverLanguage('ro-ro', 'Roumain (Roumanie)'),
  DiscoverLanguage('ru', 'Russe'),
  DiscoverLanguage('ru-mo', 'Russe (Moldavie)'),
  DiscoverLanguage('ru-ru', 'Russe (Russie)'),
  DiscoverLanguage('se', 'Same du Nord'),
  DiscoverLanguage('sm', 'Samoan'),
  DiscoverLanguage('sg', 'Sango'),
  DiscoverLanguage('sa', 'Sanskrit'),
  DiscoverLanguage('sc', 'Sarde'),
  DiscoverLanguage('sr', 'Serbe'),
  DiscoverLanguage('sh', 'Serbo-croate'),
  DiscoverLanguage('sn', 'Shona'),
  DiscoverLanguage('sd', 'Sindhi'),
  DiscoverLanguage('sk', 'Slovaque'),
  DiscoverLanguage('sl', 'Slovène'),
  DiscoverLanguage('so', 'Somali'),
  DiscoverLanguage('st', 'Sotho du Sud'),
  DiscoverLanguage('su', 'Soundanais'),
  DiscoverLanguage('sv', 'Suédois'),
  DiscoverLanguage('sv-fi', 'Suédois (Finlande)'),
  DiscoverLanguage('sv-se', 'Suédois (Suède)'),
  DiscoverLanguage('sw', 'Swahili'),
  DiscoverLanguage('ss', 'Swati'),
  DiscoverLanguage('tg', 'Tadjik'),
  DiscoverLanguage('tl', 'Tagalog'),
  DiscoverLanguage('ty', 'Tahitien'),
  DiscoverLanguage('ta', 'Tamoul'),
  DiscoverLanguage('tt', 'Tatar'),
  DiscoverLanguage('cs', 'Tchèque'),
  DiscoverLanguage('ce', 'Tchétchène'),
  DiscoverLanguage('cv', 'Tchouvache'),
  DiscoverLanguage('te', 'Télougou'),
  DiscoverLanguage('th', 'Thaï'),
  DiscoverLanguage('bo', 'Tibétain'),
  DiscoverLanguage('ti', 'Tigrigna'),
  DiscoverLanguage('to', 'Tongien'),
  DiscoverLanguage('ts', 'Tsonga'),
  DiscoverLanguage('tn', 'Tswana'),
  DiscoverLanguage('tr', 'Turc'),
  DiscoverLanguage('tk', 'Turkmène'),
  DiscoverLanguage('tw', 'Twi'),
  DiscoverLanguage('uk', 'Ukrainien'),
  DiscoverLanguage('ve', 'Venda'),
  DiscoverLanguage('vi', 'Vietnamien'),
  DiscoverLanguage('cu', 'Vieux-slave'),
  DiscoverLanguage('vo', 'Volapük'),
  DiscoverLanguage('wa', 'Wallon'),
  DiscoverLanguage('wo', 'Wolof'),
  DiscoverLanguage('xh', 'Xhosa'),
  DiscoverLanguage('ii', 'Yi'),
  DiscoverLanguage('yi', 'Yiddish'),
  DiscoverLanguage('yo', 'Yoruba'),
  DiscoverLanguage('za', 'Zhuang'),
  DiscoverLanguage('zu', 'Zoulou'),
];

final _catalogCodes = {
  for (final language in discoverLanguageCatalog) language.code,
};

final _labels = {
  for (final language in discoverLanguageCatalog) language.code: language.label,
};

/// Langue de base → boutique Apple principale. Les codes sans pays n’y sont pas.
const _primaryAppleStore = <String, Country>{
  'af': Country.southAfrica,
  'ak': Country.ghana,
  'sq': Country.albania,
  'de': Country.germany,
  'am': Country.ethiopia,
  'en': Country.unitedStates,
  'ar': Country.saudiArabia,
  'hy': Country.armenia,
  'as': Country.india,
  'az': Country.azerbaijan,
  'bm': Country.mali,
  'bn': Country.bangladesh,
  'bi': Country.vanuatu,
  'be': Country.belarus,
  'bh': Country.india,
  'my': Country.myanmar,
  'bs': Country.bosniaAndHerzegovina,
  'br': Country.france,
  'bg': Country.bulgaria,
  'ch': Country.guam,
  'ny': Country.malawi,
  'zh': Country.china,
  'zh-cn': Country.china,
  'zh-tw': Country.taiwan,
  'si': Country.sriLanka,
  'ko': Country.southKorea,
  'kw': Country.unitedKingdom,
  'co': Country.france,
  'ht': Country.haiti,
  'hr': Country.croatia,
  'da': Country.denmark,
  'dz': Country.bhutan,
  'es': Country.spain,
  'et': Country.estonia,
  'fo': Country.faroeIslands,
  'fj': Country.fiji,
  'fi': Country.finland,
  'fr': Country.france,
  'fy': Country.netherlands,
  'cy': Country.unitedKingdom,
  'lg': Country.uganda,
  'ka': Country.georgia,
  'el': Country.greece,
  'kl': Country.greenland,
  'gn': Country.paraguay,
  'gu': Country.india,
  'ha': Country.nigeria,
  'he': Country.israel,
  'hi': Country.india,
  'ho': Country.papuaNewGuinea,
  'hu': Country.hungary,
  'ig': Country.nigeria,
  'in': Country.indonesia,
  'iu': Country.canada,
  'ga': Country.ireland,
  'is': Country.iceland,
  'it': Country.italy,
  'ja': Country.japan,
  'jv': Country.indonesia,
  'kn': Country.india,
  'kk': Country.kazakhstan,
  'km': Country.cambodia,
  'kg': Country.congo,
  'ki': Country.kenya,
  'rw': Country.rwanda,
  'ky': Country.kyrgyzstan,
  'rn': Country.burundi,
  'la': Country.vaticanCity,
  'lv': Country.latvia,
  'li': Country.netherlands,
  'ln': Country.congoDemocraticRepublicOf,
  'lt': Country.lithuania,
  'lb': Country.luxembourg,
  'mk': Country.macedonia,
  'ms': Country.malaysia,
  'ml': Country.india,
  'dv': Country.maldives,
  'mg': Country.madagascar,
  'mt': Country.malta,
  'gv': Country.isleOfMan,
  'mi': Country.newZealand,
  'mr': Country.india,
  'mh': Country.marshallIslands,
  'mn': Country.mongolia,
  'na': Country.nauru,
  'nd': Country.zimbabwe,
  'nr': Country.southAfrica,
  'nl': Country.netherlands,
  'ne': Country.nepal,
  'no': Country.norway,
  'nb': Country.norway,
  'nn': Country.norway,
  'om': Country.ethiopia,
  'or': Country.india,
  'ur': Country.pakistan,
  'uz': Country.uzbekistan,
  'ps': Country.afghanistan,
  'pa': Country.india,
  'fa': Country.iran,
  'pl': Country.poland,
  'pt': Country.portugal,
  'qu': Country.peru,
  'rm': Country.switzerland,
  'ro': Country.romania,
  'ru': Country.russianFederation,
  'sm': Country.samoa,
  'sg': Country.centralAfricanRepublic,
  'sr': Country.serbia,
  'sn': Country.zimbabwe,
  'sd': Country.pakistan,
  'sk': Country.slovakia,
  'sl': Country.slovenia,
  'so': Country.somalia,
  'st': Country.lesotho,
  'su': Country.indonesia,
  'sv': Country.sweden,
  'sw': Country.tanzania,
  'ss': Country.swaziland,
  'tg': Country.tajikistan,
  'tl': Country.philippines,
  'ty': Country.frenchPolynesia,
  'ta': Country.india,
  'cs': Country.czechia,
  'te': Country.india,
  'th': Country.thailand,
  'ti': Country.eritrea,
  'to': Country.tonga,
  'tn': Country.botswana,
  'tr': Country.turkey,
  'tk': Country.turkmenistan,
  'tw': Country.ghana,
  'uk': Country.ukraine,
  've': Country.southAfrica,
  'vi': Country.vietNam,
  'wa': Country.belgium,
  'wo': Country.senegal,
  'xh': Country.southAfrica,
  'yo': Country.nigeria,
  'zu': Country.southAfrica,
};

bool discoverLanguagesAreAll(List<String> codes) {
  return codes.isEmpty || codes.contains(discoverLanguagesAll);
}

/// Sélection précise mémorisée pendant que « Toutes les langues » est actif.
/// `*` et les codes inconnus sont ignorés. Vide → français.
List<String> normalizeDiscoverLanguagesPicked(List<String>? stored) {
  if (stored == null || stored.isEmpty) return discoverLanguagesDefault;
  if (stored.contains(discoverLanguagesAll)) return discoverLanguagesDefault;
  return normalizeDiscoverLanguages(stored);
}

/// Absence de préférence → toutes les langues. Une valeur inconnue est ignorée.
List<String> normalizeDiscoverLanguages(List<String>? stored) {
  if (stored == null || stored.isEmpty) {
    return const [discoverLanguagesAll];
  }
  if (stored.contains(discoverLanguagesAll)) {
    return const [discoverLanguagesAll];
  }
  final kept = <String>[];
  for (final raw in stored) {
    final code = raw.trim().toLowerCase();
    if (_catalogCodes.contains(code) && !kept.contains(code)) kept.add(code);
  }
  if (kept.isEmpty) return const [discoverLanguagesAll];
  return kept;
}

/// Libellé du catalogue, ou le code s’il n’y est pas.
String discoverLanguageLabel(String code) => _labels[code] ?? code;

/// Langue de base et ses variantes (`en`, puis `en-us`, `en-gb`…).
class DiscoverLanguageGroup {
  const DiscoverLanguageGroup({required this.language, required this.variants});

  final DiscoverLanguage language;
  final List<DiscoverLanguage> variants;
}

/// Variantes rangées sous le code qui précède le tiret. L’ordre du catalogue
/// est conservé. Un code sans langue parente reste une ligne seule.
final discoverLanguageGroups = _groupDiscoverLanguages();

List<DiscoverLanguageGroup> _groupDiscoverLanguages() {
  final bases = <String>{
    for (final language in discoverLanguageCatalog)
      if (!language.code.contains('-')) language.code,
  };
  final variants = <String, List<DiscoverLanguage>>{};
  final orphans = <String>{};
  for (final language in discoverLanguageCatalog) {
    final dash = language.code.indexOf('-');
    if (dash < 0) continue;
    final parent = language.code.substring(0, dash);
    if (bases.contains(parent)) {
      (variants[parent] ??= []).add(language);
    } else {
      orphans.add(language.code);
    }
  }
  return [
    for (final language in discoverLanguageCatalog)
      if (!language.code.contains('-'))
        DiscoverLanguageGroup(
          language: language,
          variants: variants[language.code] ?? const [],
        )
      else if (orphans.contains(language.code))
        DiscoverLanguageGroup(language: language, variants: const []),
  ];
}

String discoverLanguagesSummary(List<String> codes) {
  if (discoverLanguagesAreAll(codes)) return 'Toutes les langues';
  final labels = [for (final code in codes) _labels[code] ?? code];
  if (labels.length <= 2) return labels.join(', ');
  return '${labels.length} langues';
}

/// Codes historiques ou macrolangues que le préfixe ne relie pas.
const _extraCodes = <String, List<String>>{
  'he': ['iw'],
  'in': ['id'],
  'no': ['nb', 'nn'],
};

bool _covers(String language, String code) {
  if (language == code || language.startsWith('$code-')) return true;
  for (final extra in _extraCodes[code] ?? const <String>[]) {
    if (language == extra || language.startsWith('$extra-')) return true;
  }
  return false;
}

/// Genres `itunes:category` et `podcast:category` du `<channel>`, avant le
/// premier épisode. Les entités XML sont décodées.
List<String> rssChannelCategories(String xml) {
  final lower = xml.toLowerCase();
  final itemAt = lower.indexOf('<item');
  final head = itemAt < 0 ? xml : xml.substring(0, itemAt);
  final seen = <String>{};
  final genres = <String>[];
  final tags = RegExp(
    '<(?:[a-z0-9]+:)?category\\b([^>]*)>',
    caseSensitive: false,
  );
  final textAttr = RegExp(
    '\\btext\\s*=\\s*(["\'])(.*?)\\1',
    caseSensitive: false,
  );
  for (final match in tags.allMatches(head)) {
    final raw = textAttr.firstMatch(match.group(1) ?? '')?.group(2);
    if (raw == null) continue;
    final genre = _decodeXmlText(raw).trim();
    if (genre.isEmpty || !seen.add(genre.toLowerCase())) continue;
    genres.add(genre);
  }
  return genres;
}

String _decodeXmlText(String value) {
  return value
      .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (match) {
        final code = int.tryParse(match.group(1)!, radix: 16);
        return code == null ? match.group(0)! : String.fromCharCode(code);
      })
      .replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
        final code = int.tryParse(match.group(1)!);
        return code == null ? match.group(0)! : String.fromCharCode(code);
      })
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&');
}

/// Langue déclarée dans le `<channel>`, avant le premier épisode.
String? rssChannelLanguage(String xml) {
  final lower = xml.toLowerCase();
  final itemAt = lower.indexOf('<item');
  final head = itemAt < 0 ? xml : xml.substring(0, itemAt);
  final match = RegExp(
    r'<(?:itunes:)?language\b[^>]*>\s*([^<]*?)\s*</(?:itunes:)?language>',
    caseSensitive: false,
  ).firstMatch(head);
  final value = match?.group(1)?.trim() ?? '';
  return value.isEmpty ? null : value;
}

/// Une langue choisie n’accepte que ses codes. Un flux sans langue est écarté.
/// `en` couvre `en-us`, pas l’inverse.
bool discoverLanguageMatches(String? feedLanguage, List<String> selected) {
  if (discoverLanguagesAreAll(selected)) return true;
  final language = _normalizeCode(feedLanguage);
  if (language.isEmpty) return false;
  for (final code in selected) {
    if (code == discoverLanguagesAll) continue;
    if (_covers(language, code)) return true;
  }
  return false;
}

/// Codes à passer à Podcast Index : la sélection, plus les variantes du catalogue.
List<String> podcastIndexLanguageQuery(List<String> selected) {
  if (discoverLanguagesAreAll(selected)) return const [];
  final out = <String>[];
  for (final code in selected) {
    if (code == discoverLanguagesAll) continue;
    for (final language in discoverLanguageCatalog) {
      final candidate = language.code;
      if (_covers(candidate, code) && !out.contains(candidate)) {
        out.add(candidate);
      }
    }
    for (final extra in _extraCodes[code] ?? const <String>[]) {
      if (!out.contains(extra)) out.add(extra);
    }
  }
  return out;
}

/// Boutique Apple d’une langue, ou null si l’annuaire n’a pas de pays pour elle.
Country? appleCountryFor(String languageCode) {
  final code = _normalizeCode(languageCode);
  if (code.isEmpty || code == discoverLanguagesAll) return null;
  final primary = _primaryAppleStore[code];
  if (primary != null) return primary;
  final split = code.split('-');
  if (split.length < 2) return null;
  final region = switch (code) {
    'ro-mo' || 'ru-mo' => 'md',
    _ => split.last,
  };
  for (final country in Country.values) {
    if (country != Country.none && country.code == region) return country;
  }
  return null;
}

/// Tendances Apple. « Toutes » utilise les États-Unis : l’URL exige un pays.
List<Country> appleChartStores(List<String> selected) {
  if (discoverLanguagesAreAll(selected)) return const [Country.unitedStates];
  return _appleStores(selected);
}

/// Recherche Apple. « Toutes » omet le pays.
List<Country> appleSearchStores(List<String> selected) {
  if (discoverLanguagesAreAll(selected)) return const [Country.none];
  return _appleStores(selected);
}

/// `true` quand la sélection viserait plus de boutiques que le plafond.
/// « Toutes » ne fixe pas de pays : pas d’avertissement.
bool appleStoresExceedLimit(List<String> selected) {
  if (discoverLanguagesAreAll(selected)) return false;
  final stores = <Country>[];
  for (final code in selected) {
    final country = appleCountryFor(code);
    if (country == null || stores.contains(country)) continue;
    stores.add(country);
    if (stores.length > discoverAppleStoreLimit) return true;
  }
  return false;
}

List<Country> _appleStores(List<String> selected) {
  final stores = <Country>[];
  for (final code in selected) {
    final country = appleCountryFor(code);
    if (country == null || stores.contains(country)) continue;
    stores.add(country);
    if (stores.length == discoverAppleStoreLimit) break;
  }
  return stores;
}

String _normalizeCode(String? value) {
  return (value ?? '').trim().toLowerCase().replaceAll('_', '-');
}
