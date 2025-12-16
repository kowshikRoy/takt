import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            _buildHeader(context),
            const SizedBox(height: 32),
            Text(
              'Your Growth',
              style: GoogleFonts.splineSans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textMainLight,
              ),
            ),
            const SizedBox(height: 16),
            _buildGrowthCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.1),
                blurRadius: 8,
                offset: Offset(0, 4),
              )
            ],
            image: const DecorationImage(
              image: AssetImage('assets/images/profile.jpg'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Matrix Code',
              style: GoogleFonts.splineSans(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textMainLight,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Joined December 2025',
              style: GoogleFonts.splineSans(
                fontSize: 14,
                color: AppTheme.textSubLight,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGrowthCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: const [
          BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), blurRadius: 2, offset: Offset(0, 1))
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 96,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildBar(context, 'M', 0.3),
                _buildBar(context, 'T', 0.5),
                _buildBar(context, 'W', 0.4),
                _buildBar(context, 'T', 0.75, isFaint: true),
                _buildBar(context, 'F', 0.9, isToday: true),
                _buildBar(context, 'S', 0.1),
                _buildBar(context, 'S', 0.1),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: AppTheme.borderLight),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Weekly Words', style: GoogleFonts.splineSans(color: AppTheme.textSubLight, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text('124', style: GoogleFonts.splineSans(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textMainLight)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Total XP', style: GoogleFonts.splineSans(color: AppTheme.textSubLight, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text('3,450', style: GoogleFonts.splineSans(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textMainLight)),
                ],
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildBar(BuildContext context, String day, double heightPct, {bool isFaint = false, bool isToday = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (isToday)
          Text(day, style: GoogleFonts.splineSans(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 10))
        else
          Text(day, style: GoogleFonts.splineSans(color: AppTheme.textSubLight.withValues(alpha: 0.0), fontSize: 10)),
        
        const SizedBox(height: 4),
        
        Container(
          width: 36,
          height: 80 * heightPct,
          decoration: BoxDecoration(
            color: isToday 
                ? AppTheme.primary 
                : (isFaint ? AppTheme.primary.withValues(alpha: 0.4) : AppTheme.borderLight),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
            boxShadow: isToday ? [
              BoxShadow(
                 color: const Color(0xFFEA2A33).withValues(alpha: 0.4),
                 blurRadius: 15,
                 spreadRadius: 0,
              )
            ] : null,
          ),
          child: isToday ? Stack(
            clipBehavior: Clip.none,
            children: [
               Positioned(
                 top: -3,
                 left: 0, right: 0,
                 child: Center(child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))),
               )
            ],
          ) : null,
        ),
      ],
    );
  }
}
