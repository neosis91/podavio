import 'package:circle_flags/circle_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data/discover_languages.dart';

/// Drapeau rond (SVG) d’une langue d’Explorer.
///
/// Quand la langue a son propre drapeau (breton, corse, catalan…), il prime
/// sur le pays de la boutique. Ces SVG viennent surtout de circle-flags (MIT).
class LanguageFlag extends StatelessWidget {
  const LanguageFlag({
    super.key,
    required this.languageCode,
    this.size = 28,
    this.placeholder = true,
  });

  final String languageCode;
  final double size;

  /// Réserve la place quand aucun drapeau n’est connu, pour aligner la liste.
  final bool placeholder;

  @override
  Widget build(BuildContext context) {
    final asset = languageFlagAsset(languageCode);
    if (asset != null) {
      // Un SVG rectangulaire auquel on donne largeur et hauteur est ramené
      // à son ratio : le cercle devenait une ellipse. On le cadre d’abord
      // dans un carré, puis on rogne sans étirer.
      return ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: ClipOval(child: SvgPicture.asset(asset, fit: BoxFit.cover)),
        ),
      );
    }
    final iso = languageFlagIso(languageCode);
    if (iso == null) {
      return placeholder
          ? SizedBox.square(dimension: size)
          : const SizedBox.shrink();
    }
    return CircleFlag(iso, size: size);
  }
}

/// SVG propre à la langue, s’il diffère du drapeau national.
String? languageFlagAsset(String languageCode) {
  return _languageFlagAssets[languageCode.trim().toLowerCase()];
}

/// Pays représentatif d’un code du catalogue, s’il a un drapeau SVG.
String? languageFlagIso(String languageCode) {
  final code = languageCode.trim().toLowerCase();
  final region = switch (code) {
    'ro-mo' || 'ru-mo' => 'md',
    _ when code.contains('-') => code.split('-').last,
    _ => null,
  };
  if (region != null && Flag.values.contains(region)) return region;
  final country = appleCountryFor(code)?.code ?? '';
  if (country.isNotEmpty && Flag.values.contains(country)) return country;
  final extra = _extraLanguageFlags[code];
  if (extra != null && Flag.values.contains(extra)) return extra;
  return null;
}

/// Langues sans drapeau propre ni boutique Apple, rattachées à un pays.
const _extraLanguageFlags = <String, String>{
  'cr': 'ca',
  'lo': 'la',
  'ng': 'na',
  'oj': 'ca',
  'sa': 'in',
  'sh': 'rs',
  'ts': 'za',
};

/// Drapeaux de langue (circle-flags) distincts du pays affiché sinon.
const _languageFlagAssets = <String, String>{
  'aa': 'assets/flags/aa.svg',
  'ab': 'assets/flags/ab.svg',
  'an': 'assets/flags/an.svg',
  'as': 'assets/flags/as.svg',
  'av': 'assets/flags/av.svg',
  'ay': 'assets/flags/ay.svg',
  'ba': 'assets/flags/ba.svg',
  'bo': 'assets/flags/bo.svg',
  'br': 'assets/flags/br.svg',
  'ca': 'assets/flags/ca.svg',
  'ce': 'assets/flags/ce.svg',
  'co': 'assets/flags/co.svg',
  'cv': 'assets/flags/cv.svg',
  'cy': 'assets/flags/cy.svg',
  'ee': 'assets/flags/ee.svg',
  'eo': 'assets/flags/eo.svg',
  'eu': 'assets/flags/eu.svg',
  'fy': 'assets/flags/fy.svg',
  'gd': 'assets/flags/gd.svg',
  'gl': 'assets/flags/gl.svg',
  'gn': 'assets/flags/gn.svg',
  'gu': 'assets/flags/gu.svg',
  'ha': 'assets/flags/ha.svg',
  'haw': 'assets/flags/haw.svg',
  'ia': 'assets/flags/ia.svg',
  'ie': 'assets/flags/ie.svg',
  'io': 'assets/flags/io.svg',
  'jv': 'assets/flags/jv.svg',
  'kg': 'assets/flags/kg.svg',
  'ki': 'assets/flags/ki.svg',
  'kn': 'assets/flags/kn.svg',
  'kr': 'assets/flags/kr.svg',
  'ks': 'assets/flags/ks.svg',
  'ku': 'assets/flags/ku.svg',
  'kv': 'assets/flags/kv.svg',
  'kw': 'assets/flags/kw.svg',
  'la': 'assets/flags/la.svg',
  'ln': 'assets/flags/ln.svg',
  'mi': 'assets/flags/mi.svg',
  'ml': 'assets/flags/ml.svg',
  'mr': 'assets/flags/mr.svg',
  'nv': 'assets/flags/nv.svg',
  'oc': 'assets/flags/oc.svg',
  'om': 'assets/flags/om.svg',
  'or': 'assets/flags/or.svg',
  'os': 'assets/flags/os.svg',
  'qu': 'assets/flags/qu.svg',
  'rm': 'assets/flags/rm.svg',
  'sc': 'assets/flags/sc.svg',
  'sd': 'assets/flags/sd.svg',
  'se': 'assets/flags/se.svg',
  'su': 'assets/flags/su.svg',
  'ta': 'assets/flags/ta.svg',
  'te': 'assets/flags/te.svg',
  'ti': 'assets/flags/ti.svg',
  'tt': 'assets/flags/tt.svg',
  'ug': 'assets/flags/ug.svg',
  'vo': 'assets/flags/vo.svg',
  'wa': 'assets/flags/wa.svg',
  'yi': 'assets/flags/yi.svg',
  'yo': 'assets/flags/yo.svg',
};
