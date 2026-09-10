import 'package:flutter/material.dart';
import '../theme.dart';

/// Reusable scrollable text screen — used for About, Terms & Conditions,
/// and Privacy Policy so we don't repeat the same layout three times.
/// Restyled to match the app's card-based visual language, instead of
/// plain unstyled text on a background.
class InfoScreen extends StatelessWidget {
  final String title;
  final List<InfoSection> sections;

  const InfoScreen({super.key, required this.title, required this.sections});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < sections.length; i++) ...[
                  if (i > 0) ...[
                    const SizedBox(height: 8),
                    Divider(color: Colors.grey.shade100, height: 1),
                    const SizedBox(height: 20),
                  ],
                  if (sections[i].heading != null) ...[
                    Row(
                      children: [
                        Container(
                          width: 4, height: 16,
                          decoration: BoxDecoration(color: AppColors.mint, borderRadius: BorderRadius.circular(2)),
                        ),
                        const SizedBox(width: 8),
                        Text(sections[i].heading!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.teal)),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  Text(sections[i].body, style: const TextStyle(fontSize: 13, height: 1.6, color: Colors.black87)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class InfoSection {
  final String? heading;
  final String body;
  const InfoSection({this.heading, required this.body});
}

/// Static content for the three info pages, kept here so profile_screen.dart
/// stays focused on layout rather than copy.
class AppInfoContent {
  static const about = [
    InfoSection(
      body: 'DriveOrRide (v1.0.0) helps Malaysian commuters decide between '
          'driving and public transit for a given trip by comparing real cost, '
          'time, and distance — using live GTFS rail data, OpenStreetMap '
          'routing, and current fuel prices.',
    ),
    InfoSection(
      heading: 'Built for',
      body: 'A university mobile application development assignment (BMIT2073), '
          'aligned with SDG Goal 9 (Industry, Innovation and Infrastructure) by '
          'promoting smarter, more sustainable commuting choices.',
    ),
  ];

  static const terms = [
    InfoSection(
      body: 'DriveOrRide is a student course project provided for demonstration '
          'and educational purposes only. It is not a commercial product and '
          'comes with no warranty of accuracy for routing, fares, or fuel '
          'price data.',
    ),
    InfoSection(
      heading: 'Acceptable use',
      body: 'By using this app, you agree not to misuse it, attempt to disrupt '
          'its services, or rely on it for safety-critical navigation '
          'decisions.',
    ),
    InfoSection(
      heading: 'Changes',
      body: 'Features and data sources may change or be removed at any time '
          'as this project continues to be developed.',
    ),
  ];

  static const privacy = [
    InfoSection(
      body: 'DriveOrRide stores your account details (name, email, phone) and '
          'app data (saved locations, savings goals, trip history) to provide '
          'the app\'s features. Account data is stored securely with Supabase; '
          'trip and location data may also be cached locally on your device.',
    ),
    InfoSection(
      heading: 'What we don\'t do',
      body: 'We do not sell your data or share it with third parties for '
          'advertising. Location data is used only to power the app\'s own '
          'features, such as trip tracking and route comparison.',
    ),
    InfoSection(
      heading: 'Your control',
      body: 'You can edit or remove your saved data at any time from within '
          'the app, and delete your account by contacting your project team.',
    ),
  ];
}