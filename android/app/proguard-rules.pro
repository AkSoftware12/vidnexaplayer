# Referenced by android/app/build.gradle's release proguardFiles but never
# checked into the repo, so release builds ran with zero custom R8 rules.
# Flutter plugins ship their own consumer-rules.txt inside their AARs (Play
# Core, Firebase, media_kit, etc.), so this stays empty unless a future crash
# points at a specific reflection-based lookup that needs an explicit -keep.
