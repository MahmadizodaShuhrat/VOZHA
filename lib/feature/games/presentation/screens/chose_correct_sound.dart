import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class WordSliderPage extends StatefulWidget {
  @override
  _WordSliderPageState createState() => _WordSliderPageState();
}

class _WordSliderPageState extends State<WordSliderPage> {
  PageController _pageController = PageController(initialPage: 0);

  // Калимаҳо (мисол)
  List<String> words = ['apple', 'banana', 'carrot', 'date', 'eggplant'];
  int currentIndex = 0;

  void _goToNext() {
    if (currentIndex < words.length - 1) {
      currentIndex++;
      _pageController.animateToPage(
        currentIndex,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToPrevious() {
    if (currentIndex > 0) {
      currentIndex--;
      _pageController.animateToPage(
        currentIndex,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Learn Words')),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: NeverScrollableScrollPhysics(), // манъ кардани scroll
              itemCount: words.length,
              itemBuilder: (context, index) {
                return Center(
                  child: Card(
                    margin: EdgeInsets.symmetric(horizontal: 20, vertical: 100),
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Container(
                      padding: EdgeInsets.all(30),
                      child: Text(
                        words[index],
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _goToPrevious,
                  icon: Icon(Icons.arrow_back),
                  label: Text('Аз ёд кардан'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _goToNext,
                  icon: Icon(Icons.arrow_forward),
                  label: Text('I_already_know'.tr()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
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
