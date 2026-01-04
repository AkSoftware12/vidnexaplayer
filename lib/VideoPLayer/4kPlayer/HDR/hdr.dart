import 'dart:ui';
import 'package:flutter/material.dart';

class FilterPopup {
  static void show(
      BuildContext context, {
        required String selectedKey,
        required Function(String key) onSelected,
      }) {
    final media = MediaQuery.of(context);
    final bool isLandscape =
        media.orientation == Orientation.landscape;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "filter",
      barrierColor: Colors.black.withOpacity(.6),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) {
        return Material(
          type: MaterialType.transparency,
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  width: isLandscape
                      ? media.size.width * .45  // 🌐 landscape fix
                      : media.size.width * .92,
                  constraints: BoxConstraints(
                    maxHeight: media.size.height * .55,
                  ),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(.1),
                        Colors.white.withOpacity(.05),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(.25),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      /// 🔥 TITLE + CLOSE
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              "HDR",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: .5,
                              ),
                            ),
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => Navigator.pop(context),
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(
                                Icons.close,
                                size: 20,
                                color: Colors.red,
                              ),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 0),

                      /// 📻 FILTER LIST (scroll safe)
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              _radioTile(
                                context,
                                title: "Normal",
                                color: Colors.white,
                                value: "normal",
                                groupValue: selectedKey,
                                onSelected: onSelected,
                              ),
                              _radioTile(
                                context,
                                title: "Dark",
                                color: Colors.black87,
                                value: "dark",
                                groupValue: selectedKey,
                                onSelected: onSelected,
                              ),
                              _radioTile(
                                context,
                                title: "Blue",
                                color: Color(0xFF3F51FF),
                                value: "blue",
                                groupValue: selectedKey,
                                onSelected: onSelected,
                              ),
                              _radioTile(
                                context,
                                title: "Warm HDR",
                                color: Colors.orangeAccent,
                                value: "warm",
                                groupValue: selectedKey,
                                onSelected: onSelected,
                              ),
                              _radioTile(
                                context,
                                title: "Sepia",
                                color: Colors.redAccent,
                                value: "sepia",
                                groupValue: selectedKey,
                                onSelected: onSelected,
                              ),
                              _radioTile(
                                context,
                                title: "Neon",
                                color: Colors.purpleAccent,
                                value: "neon",
                                groupValue: selectedKey,
                                onSelected: onSelected,
                              ),
                              _radioTile(
                                context,
                                title: "Green",
                                color: Colors.green,
                                value: "green",
                                groupValue: selectedKey,
                                onSelected: onSelected,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (_, anim, __, child) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: anim,
            curve: Curves.easeOutBack,
          ),
          child: child,
        );
      },
    );
  }

  /// 🎯 RADIO TILE
  static Widget _radioTile(
      BuildContext context, {
        required String title,
        required Color color,
        required String value,
        required String groupValue,
        required Function(String) onSelected,
      }) {
    final bool selected = value == groupValue;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          onSelected(value);
          Navigator.pop(context);
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: selected
                ? color.withOpacity(.25)
                : Colors.white.withOpacity(.08),
            border: Border.all(
              color: selected ? color : Colors.white24,
            ),
          ),
          child: Row(
            children: [
              /// RADIO DOT
              Container(
                height: 18,
                width: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: selected
                    ? Center(
                  child: Container(
                    height: 8,
                    width: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                    ),
                  ),
                )
                    : null,
              ),
              const SizedBox(width: 12),

              /// TEXT
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight:
                    selected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
