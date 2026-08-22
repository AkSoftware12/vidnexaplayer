import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:videoplayer/Photo/image_album.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import '../../DarkMode/dark_mode.dart';
import '../../DarkMode/styles/theme_data_style.dart';
import '../../DeviceSpace/device_space.dart';
import '../../LockScreen/LockScreen/lock_screen.dart';
import '../../NetWork Stream/stream_video.dart';
import '../../Notification/notification.dart';
import '../../NotifyListeners/AppBar/app_bar_color.dart';
import '../../NotifyListeners/AppBar/colorList.dart';
import '../../NotifyListeners/LanguageProvider/language_picker_sheet.dart';
import '../../NotifyListeners/LanguageProvider/language_provider.dart';
import '../../NotifyListeners/LanguageProvider/profile_strings.dart';
import '../../NotifyListeners/UserData/user_data.dart';
import '../../StatusSaverScreen/whatsapp_download.dart';
import '../../Utils/rating_popup.dart';
import '../HomeBottomnavigation/home_bottomNavigation.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  THEME  (Light / White)
// ─────────────────────────────────────────────────────────────────────────────
class _T {
  // backgrounds
  static const Color white    = Color(0xFFFFFFFF);
  static const Color surface  = Color(0xFFF0F1F6);

  // brand
  static const Color accent    = Color(0xFFE8382C);
  static const Color accentSoft= Color(0x18E8382C);
  static const Color gold      = Color(0xFFFFB800);

  // text
  static const Color textH = Color(0xFF111827);
  static const Color textB = Color(0xFF374151);
  static const Color textS = Color(0xFF9CA3AF);

  // border
  static const Color border  = Color(0xFFE5E7EB);
  static const Color borderM = Color(0xFFD1D5DB);

  // shadows
  static List<BoxShadow> get accentShadow => [
    BoxShadow(color: accent.withValues(alpha:0.25), blurRadius: 14, offset: const Offset(0, 4)),
  ];

  // gradients
  static LinearGradient get redGrad => const LinearGradient(
    colors: [Color(0xFFE8382C), Color(0xFFFF5722)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static LinearGradient get goldGrad => const LinearGradient(
    colors: [Color(0xFFFFB800), Color(0xFFFF8C00)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );

  // text styles
  static TextStyle orbitron({double size = 13, FontWeight w = FontWeight.w600, Color? color, double spacing = 0}) =>
      GoogleFonts.outfit(fontSize: size.sp, fontWeight: w, color: color ?? textH, letterSpacing: spacing);

  static TextStyle outfit({double size = 13, FontWeight w = FontWeight.w500, Color? color}) =>
      GoogleFonts.outfit(fontSize: size.sp, fontWeight: w, color: color ?? textB);
}

// ─────────────────────────────────────────────────────────────────────────────
//  MAIN PAGE
// ─────────────────────────────────────────────────────────────────────────────
class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});
  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> with TickerProviderStateMixin {

  final TextEditingController _nameController = TextEditingController();
  File? _pickedImage;
  bool _isLoading = true;
  int  _totalEntitiesCount = 0;
  final int _sizePerPage = 50;
  AssetPathEntity? _path;

  // Was a hardcoded 'v2.4.1' that never matched the actual installed build
  // (pubspec.yaml's real version). Filled in from the platform at runtime,
  // same as the app-update-check version display in HomeBottomnavigation.
  String _appVersion = '';

  late AnimationController _fadeCtrl, _slideCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();

    // ✅ FIX 1: Animation duration increased for smooth feel
    _fadeCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnim  = CurvedAnimation(parent: _fadeCtrl,  curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));

    // ✅ FIX 2: Animations start IMMEDIATELY — screen shows on click
    _fadeCtrl.forward();
    _slideCtrl.forward();

    // ✅ FIX 3: AppBar color loaded once here, NOT in build()
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<AppBarColorProvider>(context, listen: false).loadColor();
      }
    });

    // ✅ FIX 4: Assets load in background — does NOT block screen
    _requestAssets();

    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _appVersion = info.version);
    } catch (e) {
      debugPrint('PackageInfo failed: $e');
    }
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _requestAssets() async {
    final ps = await PhotoManager.requestPermissionExtend();
    if (!mounted) return;
    if (!ps.hasAccess) {
      // ✅ FIX 5: Only update state, no animation calls here
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final filter = FilterOptionGroup(
      imageOption: const FilterOption(sizeConstraint: SizeConstraint(ignoreSize: true)),
    );
    final paths = await PhotoManager.getAssetPathList(onlyAll: true, filterOption: filter);
    if (!mounted) return;
    if (paths.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    _path = paths.first;
    _totalEntitiesCount = await _path!.assetCountAsync;
    await _path!.getAssetListPaged(page: 0, size: _sizePerPage);
    if (!mounted) return;

    // ✅ FIX 6: Only update loading state — no animation forward here
    setState(() => _isLoading = false);
  }

  Future<void> _pickImage(StateSetter local, {ImageSource src = ImageSource.gallery}) async {
    final f = await ImagePicker().pickImage(source: src);
    if (f == null) return;
    final dir   = await getApplicationDocumentsDirectory();
    final dest  = File('${dir.path}/profile_${DateTime.now().millisecondsSinceEpoch}.png');
    final saved = await File(f.path).copy(dest.path);
    // The Edit Profile sheet may have been dismissed while the picker/file
    // copy was still pending — `local` (its StatefulBuilder's StateSetter)
    // throws if called after the sheet's element is already gone.
    try {
      local(() => _pickedImage = saved);
    } catch (_) {}
    if (mounted) setState(() {});
  }

  // ── EDIT PROFILE SHEET ────────────────────────────────────────────────────
  void _openEditSheet(BuildContext ctx, UserModel user) {
    // `user.name` is non-nullable, so `?? ''` was dead.
    _nameController.text = user.name;
    final lang = context.read<LocaleProvider>().locale.languageCode;
    String t(String key) => ProfileStrings.t(lang, key);
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (sCtx, local) => Container(
          decoration: const BoxDecoration(
            color: _T.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: EdgeInsets.only(bottom: MediaQuery.of(sCtx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: _T.borderM, borderRadius: BorderRadius.circular(2)),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(t('profile_edit_title'), style: _T.orbitron(size: 17, w: FontWeight.w700, spacing: 0.5)),
                      GestureDetector(
                        onTap: () => Navigator.pop(sCtx),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _T.surface, shape: BoxShape.circle,
                            border: Border.all(color: _T.border),
                          ),
                          child: Icon(Icons.close, color: _T.textS, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Avatar
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 100.sp, height: 100.sp,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: _T.accentShadow,
                        border: Border.all(color: _T.accent, width: 3),
                      ),
                      child: ClipOval(
                        child: _pickedImage != null
                            ? Image.file(_pickedImage!, fit: BoxFit.cover)
                            : user.imagePath != null
                            ? Image.file(File(user.imagePath!), fit: BoxFit.cover)
                            : Container(
                          color: _T.surface,
                          child: Icon(Icons.person, size: 46.sp, color: _T.textS),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _pickImage(local),
                      child: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          gradient: _T.redGrad, shape: BoxShape.circle,
                          boxShadow: _T.accentShadow,
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 15),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Chip(icon: Icons.camera_alt_outlined,    label: t('profile_camera'),  onTap: () => _pickImage(local, src: ImageSource.camera)),
                    const SizedBox(width: 12),
                    _Chip(icon: Icons.photo_library_outlined, label: t('profile_gallery'), onTap: () => _pickImage(local, src: ImageSource.gallery)),
                  ],
                ),
                const SizedBox(height: 24),
                Divider(color: _T.border, height: 1),
                const SizedBox(height: 16),
                // Name field
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: TextField(
                    controller: _nameController,
                    style: _T.outfit(size: 15, color: _T.textH),
                    cursorColor: _T.accent,
                    decoration: InputDecoration(
                      labelText: t('profile_display_name'),
                      labelStyle: _T.outfit(size: 12, color: _T.textS),
                      prefixIcon: Icon(Icons.person_outline, color: _T.textS),
                      suffixIcon: _nameController.text.isNotEmpty
                          ? GestureDetector(
                          onTap: () { _nameController.clear(); local(() {}); },
                          child: Icon(Icons.clear, color: _T.textS, size: 18))
                          : null,
                      filled: true, fillColor: _T.surface,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: _T.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: _T.accent, width: 2),
                      ),
                    ),
                    onChanged: (_) => local(() {}),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: GestureDetector(
                    onTap: () {
                      user.updateUser(
                        _nameController.text.trim().isEmpty ? user.name : _nameController.text.trim(),
                        _pickedImage?.path ?? user.imagePath,
                      );
                      Navigator.pop(sCtx);
                      setState(() {});
                    },
                    child: Container(
                      width: double.infinity, height: 52,
                      decoration: BoxDecoration(
                        gradient: _T.redGrad,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: _T.accentShadow,
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Text(t('profile_save_changes'), style: _T.outfit(size: 14, w: FontWeight.w700, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final user  = Provider.of<UserModel>(context);
    final lang = context.watch<LocaleProvider>().locale.languageCode;

    // ✅ FIX 8: Removed addPostFrameCallback from build() — moved to initState()

    return Scaffold(
      backgroundColor: Colors.white,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: CustomScrollView(
            slivers: [
              // ── HERO SLIVER APP BAR ──────────────────────────────────
              SliverAppBar(
                expandedHeight: 120.sp,
                automaticallyImplyLeading: false,
                pinned: false,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  background: _HeroBanner(
                    user: user,
                    pickedImage: _pickedImage,
                    onEditTap: () => _openEditSheet(context, user),
                  ),
                ),
              ),

              // ── BODY ─────────────────────────────────────────────────
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 10.sp),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    SizedBox(height: 5.sp),

                    _SectionHeader(title: ProfileStrings.t(lang, 'profile_storage_overview')),
                    SizedBox(height: 10.sp),
                    _StorageRow(isLoading: _isLoading, totalImages: _totalEntitiesCount),

                    SizedBox(height: 15.sp),

                    _SectionHeader(title: ProfileStrings.t(lang, 'profile_quick_actions')),
                    SizedBox(height: 10.sp),
                    const _QuickActionsGrid(),

                    SizedBox(height: 15.sp),

                    _SectionHeader(title: ProfileStrings.t(lang, 'profile_settings_more')),
                    SizedBox(height: 10.sp),
                    _SettingsCard(themeProvider: theme),

                    SizedBox(height: 20.sp),
                    Center(
                      child: Text(
                        _appVersion.isEmpty ? 'VIDNEXA' : 'VIDNEXA  v$_appVersion',
                        style: _T.outfit(size: 10, color: _T.textS),
                      ),
                    ),
                    SizedBox(height: 90.sp),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  HERO BANNER
// ─────────────────────────────────────────────────────────────────────────────
class _HeroBanner extends StatelessWidget {
  final UserModel user;
  final File? pickedImage;
  final VoidCallback onEditTap;
  const _HeroBanner({required this.user, required this.pickedImage, required this.onEditTap});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LocaleProvider>().locale.languageCode;
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        child: Stack(
          children: [
            Positioned(
              bottom: 20, left: 16, right: 16,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar
                  GestureDetector(
                    onTap: onEditTap,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 80.sp, height: 80.sp,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color:Colors.grey.shade300, width: 3),
                            boxShadow: _T.accentShadow,
                          ),
                          child: ClipOval(
                            child: pickedImage != null
                                ? Image.file(pickedImage!, fit: BoxFit.cover)
                                : user.imagePath != null
                                ? Image.file(File(user.imagePath!), fit: BoxFit.cover)
                                : Container(
                              color: _T.surface,
                              child: Icon(Icons.person, size: 38.sp, color: _T.textS),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            gradient: _T.redGrad,
                            shape: BoxShape.circle,
                            boxShadow: _T.accentShadow,
                          ),
                          child: const Icon(Icons.edit, color: Colors.white, size: 11),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 14.sp),
                  // User info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          // `user.name` is non-nullable, so `?? 'Guest User'`
                          // never fired — a user who had not set a name saw a
                          // blank line instead of the placeholder.
                          user.name.trim().isEmpty ? ProfileStrings.t(lang, 'profile_guest_user') : user.name,
                          style: GoogleFonts.outfit(
                            fontSize: 17.sp, fontWeight: FontWeight.w700,
                            color: _T.textH, letterSpacing: 0.5,
                          ),
                        ),

                        SizedBox(height: 8.sp),
                        // Premium badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: _T.accentSoft,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _T.accent.withValues(alpha:0.3), width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.workspace_premium, color: _T.gold, size: 13),
                              const SizedBox(width: 5),
                              Text(
                                ProfileStrings.t(lang, 'profile_premium_member'),
                                style: GoogleFonts.outfit(
                                  fontSize: 9.sp, fontWeight: FontWeight.w700,
                                  color: _T.accent, letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 4, height: 18,
        decoration: BoxDecoration(gradient: _T.redGrad, borderRadius: BorderRadius.circular(2)),
      ),
      const SizedBox(width: 10),
      Text(title, style: _T.orbitron(size: 12.sp, w: FontWeight.w700, color: _T.textH, spacing: 0.3)),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  STORAGE ROW
// ─────────────────────────────────────────────────────────────────────────────
class _StorageRow extends StatelessWidget {
  final bool isLoading;
  final int totalImages;
  const _StorageRow({required this.isLoading, required this.totalImages});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LocaleProvider>().locale.languageCode;
    final cards = [
      _SC(icon: Icons.folder_rounded,        label: ProfileStrings.t(lang, 'profile_files'),   sub: '3.2 GB',
          grad: [const Color(0xFF1D4ED8), const Color(0xFF3B82F6)],
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DeviceSpaceScreen()))),
      _SC(icon: Icons.video_library_rounded,  label: ProfileStrings.t(lang, 'profile_videos'),  sub: '124 GB',
          grad: [const Color(0xFFD97706), const Color(0xFFFBBF24)], onTap: () {}),
      _SC(icon: Icons.photo_rounded,
          label: isLoading ? '—' : '$totalImages', sub: ProfileStrings.t(lang, 'profile_images'),
          grad: [const Color(0xFFDC2626), const Color(0xFFF87171)],
          isLoading: isLoading,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AlbumScreen()))),
      _SC(icon: Icons.music_note_rounded,     label: ProfileStrings.t(lang, 'profile_music'),   sub: '5.6 GB',
          grad: [const Color(0xFF7C3AED), const Color(0xFFA78BFA)],
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const HomeBottomNavigation(bottomIndex: 1)))),
    ];

    return SizedBox(
      height: 80.sp,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => _StorageCard(c: cards[i]),
      ),
    );
  }
}

class _SC {
  final IconData icon;
  final String label, sub;
  final List<Color> grad;
  final bool isLoading;
  final VoidCallback onTap;
  const _SC({required this.icon, required this.label, required this.sub,
    required this.grad, required this.onTap, this.isLoading = false});
}

class _StorageCard extends StatelessWidget {
  final _SC c;
  const _StorageCard({required this.c});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: c.onTap,
    child: Container(
      width: 78.sp,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: c.grad, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 34.sp, height: 34.sp,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha:0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(c.icon, color: Colors.white, size: 18.sp),
          ),
          SizedBox(height: 5.sp),
          if (c.isLoading)
            const CupertinoActivityIndicator(radius: 6, color: Colors.white)
          else
            Text(c.label, textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 10.sp, fontWeight: FontWeight.w700, color: Colors.white)),
          Text(c.sub, style: GoogleFonts.outfit(fontSize: 9.sp, color: Colors.white70)),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  QUICK ACTIONS GRID
// ─────────────────────────────────────────────────────────────────────────────
class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid();

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LocaleProvider>().locale.languageCode;
    final items = [
      _QA(icon: Icons.folder_open_rounded, label: ProfileStrings.t(lang, 'profile_folders'),   sub: '3.2 GB',
          color: const Color(0xFF16A34A), bg: const Color(0xFFDCFCE7), onTap: () {}),
      _QA(icon: Icons.download_rounded,    label: ProfileStrings.t(lang, 'profile_downloads'), sub: '124 GB',
          color: const Color(0xFF2563EB), bg: const Color(0xFFDBEAFE), onTap: () {}),
      _QA(icon: Icons.lock_rounded,        label: ProfileStrings.t(lang, 'profile_private'),   sub: ProfileStrings.t(lang, 'profile_vault'),
          color: const Color(0xFF7C3AED), bg: const Color(0xFFEDE9FE),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VaultScreen()))),
      _QA(icon: Icons.add_circle_rounded,  label: ProfileStrings.t(lang, 'profile_add_new'),   sub: ProfileStrings.t(lang, 'profile_playlist'),
          color: _T.accent, bg: _T.accentSoft, onTap: () {}),
    ];

    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10, mainAxisSpacing: 10,
      childAspectRatio: 0.88,
      children: items.map((a) => GestureDetector(
        onTap: a.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: _T.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300, width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 42.sp, height: 42.sp,
                decoration: BoxDecoration(color: a.bg, borderRadius: BorderRadius.circular(12)),
                child: Icon(a.icon, color: a.color, size: 20.sp),
              ),
              SizedBox(height: 5.sp),
              Text(a.label, style: _T.outfit(size: 9.5, w: FontWeight.w600, color: _T.textH), textAlign: TextAlign.center),
              Text(a.sub,   style: _T.outfit(size: 8.5, color: a.color),                      textAlign: TextAlign.center),
            ],
          ),
        ),
      )).toList(),
    );
  }
}

class _QA {
  final IconData icon;
  final String label, sub;
  final Color color, bg;
  final VoidCallback onTap;
  const _QA({required this.icon, required this.label, required this.sub,
    required this.color, required this.bg, required this.onTap});
}

// ─────────────────────────────────────────────────────────────────────────────
//  SETTINGS CARD
// ─────────────────────────────────────────────────────────────────────────────
class _SettingsCard extends StatelessWidget {
  final ThemeProvider themeProvider;
  const _SettingsCard({required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LocaleProvider>().locale.languageCode;
    String t(String key) => ProfileStrings.t(lang, key);
    return Container(
      decoration: BoxDecoration(
        color: _T.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── FEATURES ─────────────────────────────────────────────────
          _Sub(t('profile_section_features')),



          // _Tile(icon: Icons.star_rounded,
          //     iColor: const Color(0xFF0EA5E9), iBg: const Color(0xFFE0F2FE),
          //     title: 'Rating App', sub: 'Play online videos & IPTV',
          //     badge: _Badge(text: 'NEW', color: _T.accent),
          //   onTap: () => RatingPopup.forceShow(context),
          //
          //
          //
          // ),

          _Div(),
          _Tile(icon: Icons.cast_rounded,
              iColor: const Color(0xFF0EA5E9), iBg: const Color(0xFFE0F2FE),
              title: t('profile_stream_title'), sub: t('profile_stream_sub'),
              badge: _Badge(text: t('profile_badge_new'), color: _T.accent),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => VideoPlayerStream()));
              }),
          _Div(),

          _Tile(icon: Icons.download_for_offline_rounded,
              iColor: const Color(0xFF16A34A), iBg: const Color(0xFFDCFCE7),
              title: t('profile_status_saver_title'), sub: t('profile_status_saver_sub'),
              badge: _Badge(text: t('profile_badge_hot'), color: const Color(0xFFEA580C)),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => StatusSaverHomePage()));
              }),
          _Div(),

          _Tile(icon: Icons.style_rounded,
              iColor: const Color(0xFF7C3AED), iBg: const Color(0xFFEDE9FE),
              title: t('profile_themes_title'), sub: t('profile_themes_sub'),
              onTap: () {}),

          // ── PREFERENCES ───────────────────────────────────────────────
          _Sub(t('profile_section_preferences')),

          _Tile(icon: Icons.notifications_none_rounded,
              iColor: const Color(0xFF8B5CF6), iBg: const Color(0xFFF3E8FF),
              title: t('profile_notifications_title'), sub: t('profile_notifications_sub'),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => NotificationScreen()))),
          _Div(),

          _Tile(icon: HeroIcons.paint_brush,
              iColor: _T.accent, iBg: _T.accentSoft,
              title: t('profile_toolbar_color_title'), sub: t('profile_toolbar_color_sub'),
              onTap: () => showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                builder: (_) => const ColorPickerBottomSheet(),
              )),
          _Div(),

          _NightTile(themeProvider: themeProvider),
          _Div(),

          _Tile(icon: Icons.language_rounded,
              iColor: const Color(0xFF0891B2), iBg: const Color(0xFFE0F7FA),
              title: t('profile_language_title'), sub: t('profile_language_sub'),
              onTap: () => showLanguagePickerSheet(context)),
          _Div(),

          _Tile(svgAsset: 'assets/privacy.svg',
              iColor: const Color(0xFF64748B), iBg: const Color(0xFFF1F5F9),
              title: t('profile_privacy_title'), sub: t('profile_privacy_sub'),
              onTap: () async {
                final uri = Uri.parse(
                    'https://www.freeprivacypolicy.com/live/3a47e749-0364-44f5-8cc3-559f2cd90336');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              }),

          // ── PREMIUM ───────────────────────────────────────────────────
          _Sub(t('profile_section_premium')),
          const _RemoveAdsTile(),

          // ── SUPPORT ───────────────────────────────────────────────────
          _Sub(t('profile_section_support')),

          _Tile(icon: Icons.help_outline_rounded,
              iColor: const Color(0xFF0284C7), iBg: const Color(0xFFE0F2FE),
              title: t('profile_help_support_title'), sub: t('profile_help_support_sub'),
              onTap: () => showHelpSupportSheet(context)),
          _Div(),

          const _RateUsTile(),
          _Div(),

          _Tile(icon: Icons.chat_bubble_outline_rounded,
              iColor: const Color(0xFF059669), iBg: const Color(0xFFD1FAE5),
              title: t('profile_feedback_title'), sub: t('profile_feedback_sub'),
              onTap: () {}),
          _Div(),

          _Tile(icon: Icons.share_rounded,
              iColor: const Color(0xFF2563EB), iBg: const Color(0xFFDBEAFE),
              title: t('profile_share_app_title'), sub: t('profile_share_app_sub'),
              isLast: true,
              onTap: () => SharePlus.instance.share(
                ShareParams(
                  text:
                      'Check out Vidnexa Video Player: https://play.google.com/store/apps/details?id=com.vidnexa.videoplayer',
                  subject: 'Download Vidnexa',
                ),
              )),
        ],
      ),
    );
  }
}

// ── Sub header ───────────────────────────────────────────────────────────────
class _Sub extends StatelessWidget {
  final String label;
  const _Sub(this.label);
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(16.sp, 14.sp, 0, 4.sp),
    child: Text(label, style: _T.outfit(size: 10.sp, w: FontWeight.w600, color: Colors.blue)),
  );
}

// ── Divider ──────────────────────────────────────────────────────────────────
class _Div extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Divider(color: _T.border, height: 1, indent: 70.sp);
}

// ── Generic Tile ─────────────────────────────────────────────────────────────
class _Tile extends StatelessWidget {
  final IconData? icon;
  final String? svgAsset;
  final Color iColor, iBg;
  final String title, sub;
  final Widget? badge;
  final VoidCallback onTap;
  final bool isLast;

  const _Tile({
    this.icon, this.svgAsset,
    required this.iColor, required this.iBg,
    required this.title, required this.sub,
    this.badge, required this.onTap, this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: _T.accent.withValues(alpha:0.04),
        highlightColor: _T.accentSoft,
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(20))
            : BorderRadius.zero,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.sp, vertical: 12.sp),
          child: Row(
            children: [
              // icon
              Container(
                width: 42.sp, height: 42.sp,
                decoration: BoxDecoration(color: iBg, borderRadius: BorderRadius.circular(12)),
                child: svgAsset != null
                    ? Padding(
                    padding: const EdgeInsets.all(10),
                    child: SvgPicture.asset(
                      svgAsset!,
                      colorFilter: ColorFilter.mode(iColor, BlendMode.srcIn),
                    ))
                    : Icon(icon, color: iColor, size: 20.sp),
              ),
              SizedBox(width: 13.sp),
              // text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(title, style: _T.outfit(size: 13, w: FontWeight.w600, color: _T.textH)),
                        if (badge != null) ...[const SizedBox(width: 7), badge!],
                      ],
                    ),
                    SizedBox(height: 1.sp),
                    Text(sub, style: _T.outfit(size: 10.5, color: _T.textS)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: _T.textS, size: 13.sp),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Badge ────────────────────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
    decoration: BoxDecoration(
      color: color.withValues(alpha:0.12),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha:0.3)),
    ),
    child: Text(text,
        style: GoogleFonts.outfit(
            fontSize: 8.sp, fontWeight: FontWeight.w700,
            color: color, letterSpacing: 0.5)),
  );
}

// ── Night Mode Tile ──────────────────────────────────────────────────────────
class _NightTile extends StatelessWidget {
  final ThemeProvider themeProvider;
  const _NightTile({required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    final isDark = themeProvider.themeDataStyle == ThemeDataStyle.dark;
    final lang = context.watch<LocaleProvider>().locale.languageCode;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.sp, vertical: 10.sp),
      child: Row(
        children: [
          Container(
            width: 42.sp, height: 42.sp,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.nightlight_round, color: const Color(0xFF475569), size: 20.sp),
          ),
          SizedBox(width: 13.sp),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ProfileStrings.t(lang, 'profile_night_mode_title'), style: _T.outfit(size: 13, w: FontWeight.w600, color: _T.textH)),
                Text(isDark ? ProfileStrings.t(lang, 'profile_night_mode_dark') : ProfileStrings.t(lang, 'profile_night_mode_light'),
                    style: _T.outfit(size: 10.5, color: _T.textS)),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: isDark,
              activeColor: _T.accent,
              activeTrackColor: _T.accent.withValues(alpha:0.35),
              inactiveThumbColor: _T.textS,
              inactiveTrackColor: _T.border,
              onChanged: (_) => themeProvider.changeTheme(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Remove Ads Tile ──────────────────────────────────────────────────────────
class _RemoveAdsTile extends StatelessWidget {
  const _RemoveAdsTile();

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LocaleProvider>().locale.languageCode;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10.sp, vertical: 6.sp),
      child: GestureDetector(
        onTap: () {},
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_T.gold.withValues(alpha:0.08), _T.accent.withValues(alpha:0.05)],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _T.gold.withValues(alpha:0.3)),
          ),
          padding: EdgeInsets.symmetric(horizontal: 12.sp, vertical: 13.sp),
          child: Row(
            children: [
              Container(
                width: 42.sp, height: 42.sp,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.workspace_premium_rounded, color: _T.gold, size: 22.sp),
              ),
              SizedBox(width: 13.sp),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(ProfileStrings.t(lang, 'profile_remove_ads_title'),
                            style: _T.outfit(size: 13, w: FontWeight.w700, color: _T.textH)),
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            gradient: _T.goldGrad,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(ProfileStrings.t(lang, 'profile_badge_pro'),
                              style: GoogleFonts.outfit(
                                  fontSize: 7.sp, fontWeight: FontWeight.w700,
                                  color: Colors.white, letterSpacing: 0.8)),
                        ),
                      ],
                    ),
                    SizedBox(height: 2.sp),
                    Text(ProfileStrings.t(lang, 'profile_remove_ads_sub'),
                        style: _T.outfit(size: 10.5, color: _T.textS)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  gradient: _T.goldGrad,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: _T.gold.withValues(alpha:0.3), blurRadius: 10)],
                ),
                child: Text(ProfileStrings.t(lang, 'profile_upgrade'),
                    style: GoogleFonts.outfit(
                        fontSize: 11.sp, fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Rate Us Tile ─────────────────────────────────────────────────────────────
class _RateUsTile extends StatefulWidget {
  const _RateUsTile();
  @override
  State<_RateUsTile> createState() => _RateUsTileState();
}

class _RateUsTileState extends State<_RateUsTile> {
  int _rating = 5;

  Future<void> _openPlayStore() async {
    final Uri url = Uri.parse(
      'https://play.google.com/store/apps/details?id=com.vidnexa.videoplayer',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LocaleProvider>().locale.languageCode;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openPlayStore,
        splashColor: _T.accent.withValues(alpha:0.04),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.sp, vertical: 12.sp),
          child: Row(
            children: [
              Container(
                width: 42.sp, height: 42.sp,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF9C3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.star_rounded, color: const Color(0xFFCA8A04), size: 22.sp),
              ),
              SizedBox(width: 13.sp),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ProfileStrings.t(lang, 'profile_rate_us_title'), style: _T.outfit(size: 13, w: FontWeight.w600, color: _T.textH)),
                    SizedBox(height: 4.sp),
                    Row(
                      children: List.generate(5, (i) => GestureDetector(
                        onTap: () {
                          setState(() => _rating = i + 1);
                          _openPlayStore();
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(right: 3),
                          child: Icon(
                            i < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: i < _rating ? const Color(0xFFFBBF24) : _T.border,
                            size: 17.sp,
                          ),
                        ),
                      )),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: _T.textS, size: 13.sp),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SOURCE CHIP
// ─────────────────────────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Chip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: _T.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _T.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _T.accent, size: 15),
          const SizedBox(width: 6),
          Text(label, style: _T.outfit(size: 12, w: FontWeight.w500, color: _T.textH)),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  HELP & SUPPORT SHEET
// ─────────────────────────────────────────────────────────────────────────────
void showHelpSupportSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _HelpSupportSheet(),
  );
}

class _HelpSupportSheet extends StatelessWidget {
  const _HelpSupportSheet();

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LocaleProvider>().locale.languageCode;
    String t(String key) => ProfileStrings.t(lang, key);
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.help_outline_rounded, color: Color(0xFF0284C7), size: 26),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t('profile_help_support_title'),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                        Text(t('profile_help_support_sub'),
                            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 14),
                      const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
                      const SizedBox(width: 10),
                      Text(t('profile_search_help'),
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    Text(t('profile_quick_actions'),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B), letterSpacing: 0.5)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _QuickActionCard(icon: Icons.chat_bubble_outline_rounded, label: t('profile_live_chat'),
                            color: const Color(0xFF0284C7), bg: const Color(0xFFE0F2FE), onTap: () {}),
                        const SizedBox(width: 12),
                        _QuickActionCard(icon: Icons.phone_outlined, label: t('profile_call_us'),
                            color: const Color(0xFF16A34A), bg: const Color(0xFFDCFCE7), onTap: () {}),
                        const SizedBox(width: 12),
                        _QuickActionCard(icon: Icons.email_outlined, label: t('profile_email'),
                            color: const Color(0xFF9333EA), bg: const Color(0xFFF3E8FF), onTap: () {}),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(t('profile_frequently_asked'),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B), letterSpacing: 0.5)),
                    const SizedBox(height: 12),
                    _FaqTile(
                      question: t('profile_faq_q1'),
                      answer: t('profile_faq_a1'),
                    ),
                    _FaqTile(
                      question: t('profile_faq_q2'),
                      answer: t('profile_faq_a2'),
                    ),
                    _FaqTile(
                      question: t('profile_faq_q3'),
                      answer: t('profile_faq_a3'),
                    ),
                    _FaqTile(
                      question: t('profile_faq_q4'),
                      answer: t('profile_faq_a4'),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0284C7), Color(0xFF0EA5E9)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t('profile_still_need_help'),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                                const SizedBox(height: 4),
                                Text(t('profile_support_247'),
                                    style: const TextStyle(color: Color(0xFFBAE6FD), fontSize: 13)),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF0284C7),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            ),
                            child: Text(t('profile_contact'), style: const TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Quick Action Card ──────────────────────────────────────────────────────────
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color, bg;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon, required this.label,
    required this.color, required this.bg, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 8),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── FAQ Expandable Tile ────────────────────────────────────────────────────────
class _FaqTile extends StatefulWidget {
  final String question, answer;
  const _FaqTile({required this.question, required this.answer});
  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _expanded ? const Color(0xFFF0F9FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _expanded ? const Color(0xFFBAE6FD) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(widget.question,
                      style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: _expanded ? const Color(0xFF0284C7) : const Color(0xFF1E293B),
                      )),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: Icon(Icons.keyboard_arrow_down_rounded,
                      color: _expanded ? const Color(0xFF0284C7) : const Color(0xFF94A3B8)),
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 10),
              Text(widget.answer,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.5)),
            ],
          ],
        ),
      ),
    );
  }
}