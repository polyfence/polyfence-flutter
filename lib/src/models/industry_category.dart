/// Industry categories for PolyFence plugin configuration and optimization
/// Helps provide industry-specific geofencing configurations
enum IndustryCategory {
  delivery(
      'delivery', 'Food & Package Delivery', 'UberEats, DoorDash, FedEx apps'),
  rideshare('rideshare', 'Transportation & Rideshare', 'Uber, Lyft, taxi apps'),
  retail('retail', 'Retail & E-commerce', 'Shopping apps, store locators'),
  logistics('logistics', 'Fleet & Logistics',
      'Trucking, supply chain, fleet management'),
  healthcare('healthcare', 'Healthcare & Medical',
      'Hospital apps, pharmacy, medical services'),
  fitness(
      'fitness', 'Fitness & Sports', 'Running, cycling, workout tracking apps'),
  social('social', 'Social & Dating', 'Social networks, dating apps, meetups'),
  gaming('gaming', 'Location-based Gaming', 'Pokemon Go style, AR games'),
  travel('travel', 'Travel & Tourism', 'Navigation, tourism, hotel apps'),
  fieldService(
      'field_service', 'Field Service', 'Maintenance, repairs, home services'),
  security(
      'security', 'Security & Safety', 'Security monitoring, emergency apps'),
  education('education', 'Education', 'School apps, campus navigation'),
  realestate('real_estate', 'Real Estate', 'Property apps, home viewing'),
  agriculture('agriculture', 'Agriculture & Farming',
      'Farm management, livestock tracking'),
  construction('construction', 'Construction',
      'Job site management, equipment tracking'),
  events('events', 'Events & Entertainment', 'Event check-ins, venue apps'),
  financial(
      'financial', 'Financial Services', 'Banking, ATM locators, payments'),
  utilities(
      'utilities', 'Utilities & Energy', 'Smart meters, utility management'),
  government(
      'government', 'Government & Public', 'City services, public safety'),
  other('other', 'Other/General', 'General purpose or not listed above');

  const IndustryCategory(this.value, this.displayName, this.description);

  final String value;
  final String displayName;
  final String description;

  static IndustryCategory fromString(String value) {
    return IndustryCategory.values.firstWhere(
      (category) => category.value == value,
      orElse: () => IndustryCategory.other,
    );
  }

  /// Helper for CLI integration
  static void printAllCategories() {
    // Available Industry Categories
    for (final category in IndustryCategory.values) {
      print('Category: ${category.value} - ${category.displayName}');
    }
  }
}
