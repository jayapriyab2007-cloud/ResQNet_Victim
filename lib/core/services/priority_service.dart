import '../constants/app_constants.dart';

class PriorityResult {
  final int level;
  final String label;
  final String description;

  const PriorityResult({
    required this.level,
    required this.label,
    required this.description,
  });

  String get badgeText => 'P$level • $label';
}

class PriorityService {
  static PriorityResult calculate({
    required String type,
    required String severity,
    required int peopleAffected,
  }) {
    final sev = severity.toUpperCase();
    final typ = type.toUpperCase();

    int p;

    // Rule 1: Explicit Critical severity or high casualty count is P1
    if (sev == Severity.critical || peopleAffected >= 5) {
      p = 1;
    }
    // Rule 2: Life-threatening incident types with serious severity escalate to P1
    else if (sev == Severity.serious &&
        (typ == EmergencyType.medical ||
            typ == EmergencyType.fire ||
            typ == EmergencyType.forestFire ||
            typ == EmergencyType.earthquake ||
            typ == EmergencyType.accident)) {
      p = 1;
    }
    // Rule 3: Serious severity or moderate mass-casualty is P2
    else if (sev == Severity.serious || peopleAffected >= 3) {
      p = 2;
    }
    // Rule 4: Disaster types with urgent severity escalate to P2
    else if (sev == Severity.urgent &&
        (typ == EmergencyType.flood ||
            typ == EmergencyType.cyclone ||
            typ == EmergencyType.fire ||
            typ == EmergencyType.forestFire ||
            typ == EmergencyType.earthquake)) {
      p = 2;
    }
    // Rule 5: Urgent severity is P3
    else if (sev == Severity.urgent) {
      p = 3;
    }
    // Rule 6: General assistance or other is P4
    else {
      p = 4;
    }

    final (label, desc) = switch (p) {
      1 => ('CRITICAL', 'Life-threatening emergency requiring immediate rescue'),
      2 => ('SERIOUS', 'Serious emergency with imminent hazard'),
      3 => ('URGENT', 'Urgent medical or evacuation assistance required'),
      _ => ('GENERAL', 'General assistance or reporting'),
    };

    return PriorityResult(level: p, label: label, description: desc);
  }
}
