/// Centralized registry mapping monitored package names to user-friendly names.
const Map<String, String> monitoredAppsRegistry = {
  'com.instagram.android': 'Instagram',
  'com.google.android.youtube': 'YouTube',
  'com.facebook.katana': 'Facebook',
  'com.facebook.lite': 'Facebook Lite',
  'com.zhiliaoapp.musically': 'TikTok',
  'com.zhiliaoapp.musically.go': 'TikTok Go',
  'com.twitter.android': 'X (Twitter)',
  'com.snapchat.android': 'Snapchat',
  'com.pinterest': 'Pinterest',
  'com.linkedin.android': 'LinkedIn',
  'com.discord': 'Discord',
  'tv.twitch.android.app': 'Twitch',
  'com.android.chrome': 'Chrome',
  'com.microsoft.emmx': 'Edge',
  'org.mozilla.firefox': 'Firefox',
  'com.brave.browser': 'Brave',
  'com.opera.browser': 'Opera',
  'com.opera.mini.native': 'Opera Mini',
  'com.sec.android.app.sbrowser': 'Samsung Internet',
  'com.duckduckgo.mobile.android': 'DuckDuckGo Browser',
  'org.telegram.messenger': 'Telegram',
  'com.reddit.frontpage': 'Reddit',
  'com.dubox.drive': 'TeraBox',
  'com.onlyfans.android': 'OnlyFans',
  'com.tumblr': 'Tumblr',
  'com.microsoft.bing': 'Bing',
  'com.quora.android': 'Quora',
  'com.ninegag.android.app': '9GAG',
  'com.vkontakte.android': 'VK',
  'org.joinmastodon.android': 'Mastodon',
  'com.instagram.barcelona': 'Threads',
  'com.badoo.mobile': 'Badoo',
  'com.meetme.android': 'MeetMe',
  'kik.android': 'Kik',
};

/// Apps that support visible-text scanning via the Accessibility node tree.
///
/// Only packages in this set will trigger the keyword scanning engine.
/// Social media apps (Instagram, YouTube, etc.) are intentionally excluded
/// because they render content in custom views not accessible via standard
/// AccessibilityNodeInfo text extraction.
///
/// Browsers expose URLs and page text; messaging apps expose message threads —
/// these are the highest-risk surfaces for restricted content.
const Set<String> highRiskPackages = {
  // Browsers
  'com.android.chrome',
  'com.microsoft.emmx',
  'org.mozilla.firefox',
  'com.brave.browser',
  'com.opera.browser',
  'com.opera.mini.native',
  'com.sec.android.app.sbrowser',
  'com.duckduckgo.mobile.android',
  // Messaging
  'org.telegram.messenger',
  // Content aggregators
  'com.reddit.frontpage',
  // Cloud storage (may expose links/filenames)
  'com.dubox.drive',
};
