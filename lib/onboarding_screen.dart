import 'package:flutter/material.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(Icons.language, color: Colors.red, size: 30),
                  const Text('DeutschApp', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Container(width: 48), // For spacing
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // Hero Section
                      const Text(
                        'German grammar,\nfinally demystified.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      RichText(
                        textAlign: TextAlign.center,
                        text: const TextSpan(
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                          children: [
                            TextSpan(text: 'Learn with our unique color-coded method for genders: '),
                            TextSpan(text: 'Masculine', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                            TextSpan(text: ', '),
                            TextSpan(text: 'Feminine', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            TextSpan(text: ', and '),
                            TextSpan(text: 'Neutral', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            TextSpan(text: '.'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Hero Visual
                      Container(
                        height: 320,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          image: const DecorationImage(
                            image: AssetImage('assets/images/hero_visual.png'),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: Center(
                          child: Transform.rotate(
                            angle: -0.05,
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GenderCard(gender: 'Der', color: Colors.blue),
                                SizedBox(height: 12),
                                Padding(
                                  padding: EdgeInsets.only(left: 32.0),
                                  child: GenderCard(gender: 'Die', color: Colors.red),
                                ),
                                SizedBox(height: 12),
                                GenderCard(gender: 'Das', color: Colors.green),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Carousel
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Why DeutschApp?',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 220,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: const [
                            CarouselCard(
                              imageUrl: 'assets/images/card1.png',
                              title: 'Master Der, Die, Das',
                              subtitle: 'Visualize genders with colors immediately.',
                            ),
                            SizedBox(width: 16),
                            CarouselCard(
                              imageUrl: 'assets/images/card2.png',
                              title: 'Conquer Cases',
                              subtitle: 'Learn nominative to genitive naturally.',
                            ),
                            SizedBox(width: 16),
                            CarouselCard(
                              imageUrl: 'assets/images/card3.png',
                              title: 'Compound Words',
                              subtitle: 'Break down complex vocabulary.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Actions Footer
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Los geht’s (Get Started)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {},
                    child: const Text('I already have an account', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black)),
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

class GenderCard extends StatelessWidget {
  final String gender;
  final Color color;

  const GenderCard({super.key, required this.gender, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: color, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.2),
              child: Text(gender, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const SizedBox(width: 12),
            Container(
              height: 8,
              width: 100,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CarouselCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String subtitle;

  const CarouselCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 135,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: DecorationImage(
                  image: AssetImage(imageUrl),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
