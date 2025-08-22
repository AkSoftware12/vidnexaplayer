import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_bar_color.dart';

class ColorPickerBottomSheet extends StatelessWidget {
  const ColorPickerBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      height: MediaQuery.of(context).size.height * 0.4,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Prevent unnecessary stretching
        children: [
          // Title and close button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Select ToolBar Color',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Color grid
          Expanded(
            child: Consumer<AppBarColorProvider>(
              builder: (context, provider, child) {
                return GridView.builder(

                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1, // Square items
                  ),
                  itemCount: provider.colors.length,
                  itemBuilder: (context, index) {
                    final color = provider.colors[index];
                    return GestureDetector(
                      onTap: () {
                        provider.changeColor(color); // Update and save color
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: provider.selectedColor == color
                                    ? Colors.black
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                          if (provider.selectedColor == color)
                            Positioned(
                              right: 4, // Position check icon on the right
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.black, // Background for visibility
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 16, // Smaller icon for better fit
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 5),
          // Reset button
          ElevatedButton(
            onPressed: () {
              Provider.of<AppBarColorProvider>(context, listen: false).resetColor();
              Navigator.pop(context); // Close bottom sheet
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: const Text(
              'Reset',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}