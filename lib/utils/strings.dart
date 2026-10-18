import 'package:provider/provider.dart';
import 'package:flutter/widgets.dart';

/// Hindi + English strings. Every user-facing string in the app goes
/// through [Strings.t] so the language toggle works everywhere.
enum AppLanguage { english, hindi }

class LanguageProvider extends ChangeNotifier {
  AppLanguage _lang = AppLanguage.english;
  AppLanguage get lang => _lang;
  bool get isHindi => _lang == AppLanguage.hindi;

  void toggle() {
    _lang = isHindi ? AppLanguage.english : AppLanguage.hindi;
    notifyListeners();
  }

  void set(AppLanguage l) {
    if (_lang != l) {
      _lang = l;
      notifyListeners();
    }
  }

  String t(String key) => Strings.t(key, _lang);
}

class Strings {
  static String t(String key, AppLanguage lang) {
    final map = _all[key];
    if (map == null) return key;
    return lang == AppLanguage.hindi ? map['hi']! : map['en']!;
  }

  static const Map<String, Map<String, String>> _all = {
    'app_name': {'en': 'KingCric', 'hi': 'किंगक्रिक'},
    'tagline': {
      'en': 'Har Ball, Har Stat, King Jaisa.',
      'hi': 'हर बॉल, हर स्टैट, किंग जैसा।'
    },
    'home': {'en': 'Home', 'hi': 'होम'},
    'live': {'en': 'Live', 'hi': 'लाइव'},
    'upcoming': {'en': 'Upcoming', 'hi': 'आने वाले'},
    'recent': {'en': 'Finished', 'hi': 'समाप्त'},
    'finished': {'en': 'Finished', 'hi': 'समाप्त'},
    'info': {'en': 'Info', 'hi': 'जानकारी'},
    'preview_info': {'en': 'Preview & Info', 'hi': 'प्रीव्यू और जानकारी'},
    'overs_graph': {'en': 'Over-by-Over', 'hi': 'ओवर-दर-ओवर'},
    'points_table': {'en': 'Points Table', 'hi': 'अंक तालिका'},
    'top_players': {'en': 'Top Players', 'hi': 'टॉप खिलाड़ी'},
    'format': {'en': 'Format', 'hi': 'फॉर्मेट'},
    'all': {'en': 'All', 'hi': 'सभी'},
    'disclaimer': {
      'en': 'For information & entertainment only. Not betting advice.',
      'hi': 'सिर्फ जानकारी और मनोरंजन के लिए। सट्टेबाजी की सलाह नहीं है।'
    },
    'source': {'en': 'Source', 'hi': 'स्रोत'},
    'matches': {'en': 'Matches', 'hi': 'मैच'},
    'last_updated_prefix': {'en': 'Last updated', 'hi': 'आखिरी अपडेट'},
    // Home (Team 1) — every user-facing Home string, EN + हिं.
    // Each key lives ONCE here (deduped 2026-10-18: the earlier
    // speculative copies were removed — a duplicate const-map key
    // is a compile error). Home composes no_matches_found with the
    // search query, so its value ends with "for" by design.
    'trending_players': {'en': 'Trending Players', 'hi': 'ट्रेंडिंग खिलाड़ी'},
    'next_up': {'en': 'Next up', 'hi': 'अगला मैच'},
    'no_live_matches': {
      'en': 'No live matches right now.',
      'hi': 'अभी कोई लाइव मैच नहीं है।'
    },
    'no_matches_section': {
      'en': 'No matches in this section.',
      'hi': 'इस सेक्शन में कोई मैच नहीं है।'
    },
    'no_matches_found': {
      'en': 'No matches found for',
      'hi': 'इसके लिए कोई मैच नहीं मिला'
    },
    'no_trending': {
      'en': 'No trending players yet.',
      'hi': 'अभी कोई ट्रेंडिंग खिलाड़ी नहीं है।'
    },
    'offline_banner': {
      'en': 'Offline — showing last verified data.',
      'hi': 'ऑफ़लाइन — आखिरी वेरिफाइड डेटा दिख रहा है।'
    },
    'refresh': {'en': 'Refresh', 'hi': 'रीफ़्रेश'},
    'updating': {'en': 'Updating…', 'hi': 'अपडेट हो रहा है…'},
    'format_filter_label': {'en': 'Format filter', 'hi': 'फॉर्मेट फ़िल्टर'},
    'leagues': {'en': 'Leagues', 'hi': 'लीग'},
    'stats': {'en': 'Stats', 'hi': 'स्टैट्स'},
    'favourites': {'en': 'Favourites', 'hi': 'पसंदीदा'},
    'compare': {'en': 'Compare', 'hi': 'तुलना'},
    'player_profile': {'en': 'Player Profile', 'hi': 'खिलाड़ी प्रोफाइल'},
    'match_detail': {'en': 'Match Detail', 'hi': 'मैच डिटेल'},
    'overall': {'en': 'Overall', 'hi': 'कुल'},
    'vs_opponent': {'en': 'vs Opponent', 'hi': 'vs विरोधी'},
    'format_wise': {'en': 'Format-wise', 'hi': 'फॉर्मेट के हिसाब से'},
    'venue': {'en': 'Venue', 'hi': 'मैदान'},
    'recent_form': {'en': 'Recent Form', 'hi': 'हालिया फॉर्म'},
    'matchup': {'en': 'Bowler vs Batter', 'hi': 'बॉलर vs बैटर'},
    'prediction': {'en': 'Prediction', 'hi': 'भविष्यवाणी'},
    'will_perform': {'en': 'Likely to perform', 'hi': 'चलने की संभावना'},
    'risky': {'en': 'Risky', 'hi': 'रिस्की'},
    'unlikely': {'en': 'Unlikely to fire', 'hi': 'चलना मुश्किल'},
    'h2h': {'en': 'Head to Head', 'hi': 'आमने-सामने'},
    'squad': {'en': 'Squad', 'hi': 'स्क्वाड'},
    'scorecard': {'en': 'Scorecard', 'hi': 'स्कोरकार्ड'},
    'commentary': {'en': 'Commentary', 'hi': 'कमेंट्री'},
    'runs': {'en': 'Runs', 'hi': 'रन'},
    'balls': {'en': 'Balls', 'hi': 'गेंदें'},
    'average': {'en': 'Average', 'hi': 'औसत'},
    'strike_rate': {'en': 'Strike Rate', 'hi': 'स्ट्राइक रेट'},
    'wickets': {'en': 'Wickets', 'hi': 'विकेट'},
    'economy': {'en': 'Economy', 'hi': 'इकॉनमी'},
    'fifties': {'en': '50s', 'hi': '50s'},
    'hundreds': {'en': '100s', 'hi': '100s'},
    'data_complete': {'en': 'Data complete', 'hi': 'डेटा पूरा है'},
    'data_checking': {
      'en': 'Verifying across sources…',
      'hi': 'सोर्स से वेरिफाई हो रहा है…'
    },
    'last_updated': {'en': 'Last updated', 'hi': 'आखिरी अपडेट'},
    'just_now': {'en': 'just now', 'hi': 'अभी-अभी'},
    'search_hint': {
      'en': 'Search player, team, match…',
      'hi': 'खिलाड़ी, टीम, मैच खोजें…'
    },

    'mock_mode': {
      'en': 'Demo data — add a free API key to go live',
      'hi': 'डेमो डेटा — लाइव के लिए फ्री API key डालें'
    },
  };
}

extension StringsContext on BuildContext {
  String tr(String key) => Provider.of<LanguageProvider>(this).t(key);
}
