class PetAssets {
  const PetAssets._();

  static String emotion(String petKey, String emotion) {
    return 'assets/pets/$petKey/emotions/$emotion.png';
  }

  static String growth(String petKey, String stage) {
    return 'assets/pets/$petKey/growth/$stage.png';
  }

  static String action(String petKey, String action) {
    return 'assets/pets/$petKey/actions/$action.png';
  }

  static String animation(String petKey, String action, int frame) {
    final frameName = frame.toString().padLeft(2, '0');
    return 'assets/pets/$petKey/animations/${action}_$frameName.png';
  }
}
