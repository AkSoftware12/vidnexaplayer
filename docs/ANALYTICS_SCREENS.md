# Firebase screen tracking — screen names

Har screen do events bhejti hai:

| Event | Kab | Parameters |
|---|---|---|
| `screen_view` | screen khulte hi | `firebase_screen`, `firebase_screen_class` |
| `screen_time` | screen band / app background hone par | `screen_name`, `duration_seconds`, `duration_ms` |

Logic ek hi jagah hai: `lib/Analytics/screen_analytics.dart`
(`ScreenAnalyticsObserver` → `MaterialApp.navigatorObservers` me `lib/main.dart` se wired).

1 second se chhoti visit ka `screen_time` nahi bheja jaata (screen ke upar se
guzar jaana shor hai, data nahi). App background jaate hi timer flush ho jaata
hai, isliye background ka waqt kisi screen ke naam nahi chadhta — matlab ek
lambi visit do `screen_time` events me aa sakti hai (pause se pehle aur baad),
GA4 me `duration_seconds` ka SUM lena hi sahi hai.

> **`screen_time` padhte waqt hamesha hamara `screen_name` param use karein,
> GA4 ka apna "Screen name" dimension nahi.** Firebase har event par chalu
> screen chipka deta hai, aur `screen_time` tab jaata hai jab nayi screen khul
> chuki hoti hai — to uska `ga_screen` **agli** screen ka naam hota hai. Device
> par verify kiya gaya:
> `screen_time params=[screen_name=HomeScreen, duration_seconds=5, ga_screen(_sn)=OfflineMusicScreen_Songs]`
> — duration `HomeScreen` ka hai, `ga_screen` galat jawab dega.

## Naam kaise diya jaata hai

* **Route wali screens** — `Navigator.push` ke `MaterialPageRoute` me
  `settings: const RouteSettings(name: '<ScreenName>')`.
* **Tab wali screens** (bottom nav, aur andar ke TabBar / PageView) — route
  nahi banta, isliye `ScreenAnalytics.instance.setScreen('<ScreenName>')`.
  `DefaultTabController` wale tabs ke liye `TabScreenReporter` widget hai —
  `TabBarView` ko usme lapet do aur `names` de do, baaki woh sambhal lega.

Nayi screen jodte waqt yeh dono me se ek line zaroor daalein, warna woh screen
Firebase ke "Screens" report me `null` aayegi.

**Andar ke tabs parent ka naam dabaa dete hain.** Jaise gallery route ka naam
`GalleryHomeScreen` hai, lekin screen khulte hi Photos tab apna naam
(`GalleryHomeScreen_Photos`) bhej deta hai — isliye report me aksar tab wala
naam hi dikhega, parent nahi. Prefix isiliye same rakha hai: GA4 me
"screen_name contains `GalleryHomeScreen`" se poori screen ka data mil jaata
hai.

## Poori list

### Tabs (bottom navigation — `home_bottomNavigation.dart` → `_tabScreenName`)

| Screen name | Tab |
|---|---|
| `HomeScreen` | index 0 — `DemoHomeScreen` |
| `OfflineMusicScreen` | index 1 — `OfflineMusicTabScreen` (kholte hi `OfflineMusicScreen_Songs` se replace ho jaata hai) |
| `YouTubePlaylistsScreen` | index 2 — `YouTubeTopPlaylists` |
| `ProfileScreen` | index 3 — `UserProfilePage` |

### Inner tabs

`gallery_home_page.dart` — `TabScreenReporter` ke through:

| Screen name | Tab |
|---|---|
| `GalleryHomeScreen_Photos` | `PhotoGrid` |
| `GalleryHomeScreen_Albums` | `_AlbumsTab` |
| `GalleryHomeScreen_Tools` | `ToolsTab` |

`offline_music_tab.dart` — `_tabScreenNames` + `onPageChanged`:

| Screen name | Tab |
|---|---|
| `OfflineMusicScreen_Songs` | `SongsView` |
| `OfflineMusicScreen_Artists` | `ArtistsView` |
| `OfflineMusicScreen_Albums` | `AlbumsView` |
| `OfflineMusicScreen_Genres` | `GenresView` |

`whatsapp_download.dart` — `_tabScreenNames` + `TabController` listener:

| Screen name | Tab |
|---|---|
| `StatusSaverScreen_All` | sabhi status |
| `StatusSaverScreen_Images` | images |
| `StatusSaverScreen_Videos` | videos |
| `StatusSaverScreen_Downloads` | downloads |

Full player ka album art aur photo viewer ka swipe bhi `PageView` hain, lekin
woh tabs nahi — ek hi screen ka content hai, isliye alag track nahi hote.

### Boot / onboarding

| Screen name | Kahan se |
|---|---|
| `SplashScreen` | `MaterialApp.home` (`'/'` route) |
| `OnboardingScreen` | `SplashScreen/splash_screen.dart` — kholte hi `OnboardingScreen_1` se replace ho jaata hai |
| `OnboardingScreen_1` … `OnboardingScreen_3` | `onboarding_screen.dart` ki slides — abhi `contents` me 3 slides hain, naam apne aap us ginti ke hisaab se badhta hai |
| `PermissionScreen` | `OnboardScreen/onboarding_screen.dart` |
| `HomeScreen` | `Permission/permission_page.dart`, `splash_screen.dart` |

## Onboarding drop-off funnel

Slides ke `screen_view` ke upar alag funnel events bhi jaate hain, taaki pata
chale ki user aage badha, skip kiya, ya nikal gaya. Code:
`lib/Analytics/onboarding_analytics.dart`.

| Event | Kab | Parameters |
|---|---|---|
| `tutorial_begin` | onboarding khuli | — |
| `onboarding_step` | har slide par (slide 1 samet) | `step` (1-based), `total_steps`, `screen_name` |
| `onboarding_skip` | Skip dabaya | `from_step`, `screen_name` |
| `tutorial_complete` | "Get Started" dabaya | — |
| `onboarding_complete` | "Get Started" dabaya | `skipped` (0/1) |

`onboarding_skip` **jump se pehle** log hota hai, warna `onPageChanged`
`_currentPage` ko aakhri slide bana deta aur asli drop-off point kho jaata.

Slide 1 bhi `onboarding_step` bhejti hai — warna jo log pehli hi slide par nikal
jaate hain woh funnel ki ginti me hi nahi aate, aur drop-off "slide 2 se" shuru
dikhta.

GA4 me funnel banane ke liye: Explore → **Funnel exploration**, steps —
`tutorial_begin` → `onboarding_step` (step = 1) → (step = 2) → (step = 3) →
`tutorial_complete`. Iske liye `step` ko custom dimension register karna
zaroori hai (neeche dekhein).

### Video

| Screen name | Kahan se push hota hai |
|---|---|
| `VideoPlayerScreen` | `video_list.dart` (×4), `home2.dart`, `floting_video.dart`, `splash_screen.dart`, `video_intent_service.dart`, `stream_video.dart`, `directory_folder.dart`, `whatsapp_download.dart`, `voice_search_result_tile.dart` |
| `VideoFolderScreen` | `home2.dart` (×3), `bottomsheet_menu_button.dart` |
| `AllVideosScreen` | `horizontal_gridlist.dart` |
| `NetworkStreamScreen` | `home_bottomNavigation.dart`, `horizontal_gridlist.dart`, `me.dart` |

### Photo / Gallery

| Screen name | Kahan se push hota hai |
|---|---|
| `GalleryHomeScreen` | `home_bottomNavigation.dart`, `horizontal_gridlist.dart`, `me.dart` — kholte hi `GalleryHomeScreen_Photos` se replace ho jaata hai |
| `GalleryAlbumPhotosScreen` | `gallery_home_page.dart` |
| `GalleryPhotoViewerScreen` | `photo_grid.dart` |
| `GallerySmartSearchScreen` | `gallery_home_page.dart`, `tools_tab.dart` |
| `GalleryDuplicateFinderScreen` | `tools_tab.dart` |
| `GalleryJunkCleanerScreen` | `tools_tab.dart` |
| `GalleryEnhanceScreen` | `tools_tab.dart` |
| `GalleryCollageScreen` | `tools_tab.dart` |
| `GalleryTextOnPhotoScreen` | `tools_tab.dart` |
| `GalleryFiltersScreen` | `tools_tab.dart` |
| `PhotoPickerScreen_Collage` | `collage_page.dart` |
| `PhotoPickerScreen_Enhance` | `enhance_page.dart` |
| `PhotoPickerScreen_Filters` | `filters_page.dart` |
| `PhotoPickerScreen_TextOnPhoto` | `text_on_photo_page.dart` |
| `PhotosScreen` | `Photo/image_album.dart` |
| `FullScreenPhotoScreen` | `Photo/image_album.dart` |
| `FullScreenImageViewer` | `directory_folder.dart`, `voice_search_result_tile.dart` |

### Music

| Screen name | Kahan se push hota hai |
|---|---|
| `MusicFullPlayerScreen` | `mini_player.dart`, `voice_search_result_tile.dart` |
| `MusicAlbumScreen` | `albums_view.dart` |
| `MusicArtistScreen` | `artists_view.dart` |
| `MusicGenreScreen` | `genres_view.dart` |
| `EqualizerScreen` | `equalizer_sheet.dart`, `equalizer_page.dart` |

### YouTube

| Screen name | Kahan se push hota hai |
|---|---|
| `YouTubePlaylistVideosScreen` | `playlists_screen.dart` |

### Status saver

| Screen name | Kahan se push hota hai |
|---|---|
| `StatusSaverScreen` | `home_bottomNavigation.dart`, `horizontal_gridlist.dart`, `me.dart` — kholte hi `StatusSaverScreen_All` se replace ho jaata hai |
| `StatusPreviewScreen` | `whatsapp_download.dart` |
| `StatusSaverGuideScreen` | `whatsapp_download.dart` (info icon) |

### Files / storage / baaki

| Screen name | Kahan se push hota hai |
|---|---|
| `DeviceSpaceScreen` | `home_bottomNavigation.dart` (×2), `me.dart` |
| `DirectoryFolderScreen` | `device_space.dart` |
| `VaultScreen` | `me.dart` |
| `VoiceSearchScreen` | `home_bottomNavigation.dart` |
| `NotificationScreen` | `home_bottomNavigation.dart` (×2), `me.dart` |
| `NotificationDetailScreen` | `Notification/notification.dart` |

## Firebase console me kahan dekhein

* **Screens report** — Analytics → Engagement → Screens (`screen_view` se).
* **Kitni der ruka** — Analytics → Events → `screen_time`.
  Behtar report ke liye GA4 me in custom dimensions/metrics ko register karein
  (Admin → Custom definitions), warna sirf event count dikhega:
  * dimension: `screen_name` (event-scoped)
  * metric: `duration_seconds` (event-scoped, unit: seconds)
* **Onboarding funnel** — Explore → Funnel exploration. Iske liye bhi custom
  definitions chahiye:
  * dimension: `step` (event-scoped) — funnel ke steps isi se bante hain
  * dimension: `from_step` (event-scoped) — kis slide se skip hua
  * dimension: `skipped` (event-scoped) — skip karke complete kiya ya nahi

Custom definitions register karne ke baad data ~24 ghante me reports me aata hai.
Turant check karne ke liye DebugView use karein:
`adb shell setprop debug.firebase.analytics.app com.vidnexa.videoplayer`
