import 'package:flutter/material.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';

// ─── Language Model ────────────────────────────────────────────────────────────
class _Lang {
  final String appTitle;
  final String headerTitle;
  final String headerSubtitle;
  final String guideTitle;
  final String quickAccess;
  final String openButton;
  final String tip;
  final List<Map<String, String>> steps;

  const _Lang({
    required this.appTitle,
    required this.headerTitle,
    required this.headerSubtitle,
    required this.guideTitle,
    required this.quickAccess,
    required this.openButton,
    required this.tip,
    required this.steps,
  });
}

final _Lang _english = _Lang(
  appTitle: 'Instructions',
  headerTitle: 'How to Save WhatsApp Status?',
  headerSubtitle: 'Follow the steps below to save your friends\' statuses easily.',
  guideTitle: 'Step-by-Step Guide',
  quickAccess: 'Quick Access',
  openButton: 'Open WhatsApp',
  tip: 'Tip: After viewing a status, come back here and save it.',
  steps: [
    {
      'title': 'Open WhatsApp',
      'subtitle': 'Use the button below or open WhatsApp manually.',
    },
    {
      'title': 'Go to Status Tab',
      'subtitle': 'Tap the "Status" tab at the bottom of WhatsApp.',
    },
    {
      'title': 'View the Status',
      'subtitle': 'Watch the status you want to save completely.',
    },
    {
      'title': 'Come Back Here',
      'subtitle': 'After viewing, return to this app.',
    },
    {
      'title': 'Select & Save',
      'subtitle': 'Choose the status from the list and tap Save.',
    },
  ],
);

final _Lang _hindi = _Lang(
  appTitle: 'निर्देश',
  headerTitle: 'WhatsApp Status कैसे Save करें?',
  headerSubtitle:
  'नीचे दिए गए स्टेप्स फॉलो करें और आसानी से Status Save करें।',
  guideTitle: 'स्टेप-बाय-स्टेप गाइड',
  quickAccess: 'जल्दी खोलें',
  openButton: 'WhatsApp खोलें',
  tip: 'टिप: Status देखने के बाद यहाँ वापस आएं और Save करें।',
  steps: [
    {
      'title': 'WhatsApp खोलें',
      'subtitle': 'नीचे दिए बटन से या खुद WhatsApp खोलें।',
    },
    {
      'title': 'Status Tab पर जाएं',
      'subtitle': 'WhatsApp में नीचे "Status" टैब पर टैप करें।',
    },
    {
      'title': 'Status देखें',
      'subtitle': 'जो Status Save करना है, उसे पूरा देख लें।',
    },
    {
      'title': 'वापस आएं',
      'subtitle': 'Status देखने के बाद इस App में वापस आएं।',
    },
    {
      'title': 'Select करें & Save करें',
      'subtitle': 'लिस्ट से Status चुनें और Save बटन दबाएं।',
    },
  ],
);

const List<IconData> _stepIcons = [
  Icons.open_in_new_rounded,
  Icons.remove_red_eye_outlined,
  Icons.photo_library_outlined,
  Icons.arrow_back_rounded,
  Icons.download_done_rounded,
];

// ─── Main Screen ───────────────────────────────────────────────────────────────
class StatusSaverScreen extends StatefulWidget {
  const StatusSaverScreen({super.key});

  @override
  State<StatusSaverScreen> createState() => _StatusSaverScreenState();
}

class _StatusSaverScreenState extends State<StatusSaverScreen>
    with SingleTickerProviderStateMixin {
  bool _isHindi = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  _Lang get _lang => _isHindi ? _hindi : _english;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggleLanguage(bool toHindi) {
    if (_isHindi == toHindi) return;
    _animController.reverse().then((_) {
      setState(() => _isHindi = toHindi);
      _animController.forward();
    });
  }

  Future<void> _openWhatsApp() async {
    final AndroidIntent intent = AndroidIntent(
      action: 'android.intent.action.MAIN',
      package: 'com.whatsapp',
      componentName: 'com.whatsapp.Main',
      flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
    );

    try {
      await intent.launch();
    } catch (e) {
      // WhatsApp not found — open Play Store
      final AndroidIntent storeIntent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        data: 'market://details?id=com.whatsapp',
        flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      try {
        await storeIntent.launch();
      } catch (_) {
        // Play Store not found — open browser
        final AndroidIntent browserIntent = AndroidIntent(
          action: 'android.intent.action.VIEW',
          data:
          'https://play.google.com/store/apps/details?id=com.whatsapp',
          flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
        );
        await browserIntent.launch();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isHindi
                  ? 'WhatsApp इंस्टॉल नहीं है!'
                  : 'WhatsApp is not installed!',
            ),
            backgroundColor: const Color(0xFF25D366),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            const SizedBox(width: 10),
            Text(
              _lang.appTitle,
              style: const TextStyle(
                color: Color(0xFF0D1B2A),
                fontWeight: FontWeight.w800,
                fontSize: 20,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
        actions: [
          // ── Language Toggle Pill ──
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4F0),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: const Color(0xFFDDEDD8),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LangPill(
                  label: 'EN',
                  active: !_isHindi,
                  onTap: () => _toggleLanguage(false),
                ),
                const SizedBox(width: 3),
                _LangPill(
                  label: 'हिं',
                  active: _isHindi,
                  onTap: () => _toggleLanguage(true),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header Card ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF25D366), Color(0xFF075E54)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF25D366).withOpacity(0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.info_outline_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _lang.headerTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _lang.headerSubtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── Guide Title ──
                Text(
                  _lang.guideTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0D1B2A),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 14),

                // ── Step Cards ──
                ...List.generate(
                  _lang.steps.length,
                      (i) => _StepCard(
                    index: i + 1,
                    icon: _stepIcons[i],
                    title: _lang.steps[i]['title']!,
                    subtitle: _lang.steps[i]['subtitle']!,
                  ),
                ),

                const SizedBox(height: 24),

                // ── Divider ──
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: Colors.grey.shade200,
                        thickness: 1.5,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        _lang.quickAccess,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: Colors.grey.shade200,
                        thickness: 1.5,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Open WhatsApp Button ──
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _openWhatsApp,
                    icon: const Icon(Icons.open_in_new_rounded, size: 20),
                    label: Text(
                      _lang.openButton,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // ── Tip Banner ──
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.amber.shade100,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        color: Colors.amber.shade700,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _lang.tip,
                          style: TextStyle(
                            color: Colors.amber.shade800,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Language Toggle Pill ──────────────────────────────────────────────────────
class _LangPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _LangPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF25D366) : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
          boxShadow: active
              ? [
            BoxShadow(
              color: const Color(0xFF25D366).withOpacity(0.35),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.grey.shade500,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ─── Step Card ─────────────────────────────────────────────────────────────────
class _StepCard extends StatelessWidget {
  final int index;
  final IconData icon;
  final String title;
  final String subtitle;

  const _StepCard({
    required this.index,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF0F0F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Number Badge
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: Color(0xFFE8F9F0),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$index',
              style: const TextStyle(
                color: Color(0xFF25D366),
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Icon Box
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF3FAF6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF075E54), size: 18),
          ),
          const SizedBox(width: 12),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0D1B2A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.grey.shade500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}