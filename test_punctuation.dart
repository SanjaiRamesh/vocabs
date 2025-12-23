void main() {
  // Test the sentence splitting logic to ensure punctuation is preserved
  String testText =
      "Rahul's father has to pay his bills. The credit card bill was ₹ 7085 and the electricity bill was ₹1500. What was the total amount he has to pay?";

  print('=== ORIGINAL TEXT ===');
  print(testText);

  print('\n=== OLD METHOD (REMOVES PUNCTUATION) ===');
  List<String> oldMethod = testText
      .split(RegExp(r'[.!?]+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  for (int i = 0; i < oldMethod.length; i++) {
    print('Sentence ${i + 1}: "${oldMethod[i]}"');
  }

  String oldJoined = oldMethod.join(' ');
  print('Joined old method: "$oldJoined"');

  print('\n=== NEW METHOD (PRESERVES PUNCTUATION) ===');
  List<String> newMethod = _splitSentencesWithPunctuation(testText);

  for (int i = 0; i < newMethod.length; i++) {
    print('Sentence ${i + 1}: "${newMethod[i]}"');
  }

  String newJoined = newMethod.join(' ');
  print('Joined new method: "$newJoined"');

  print('\n=== COMPARISON ===');
  print('Old method missing punctuation: ${!oldJoined.contains('.')}');
  print('New method preserves punctuation: ${newJoined.contains('.')}');
}

List<String> _splitSentencesWithPunctuation(String text) {
  // Split sentences while preserving punctuation
  List<String> sentences = [];

  // Use regex to find sentence boundaries but keep the punctuation
  RegExp sentencePattern = RegExp(r'([^.!?]*[.!?]+)');
  Iterable<RegExpMatch> matches = sentencePattern.allMatches(text);

  for (RegExpMatch match in matches) {
    String sentence = match.group(0)?.trim() ?? '';
    if (sentence.isNotEmpty) {
      sentences.add(sentence);
    }
  }

  // Handle any remaining text that doesn't end with punctuation
  int lastIndex = matches.isNotEmpty ? matches.last.end : 0;
  if (lastIndex < text.length) {
    String remaining = text.substring(lastIndex).trim();
    if (remaining.isNotEmpty) {
      sentences.add(remaining);
    }
  }

  return sentences.where((s) => s.isNotEmpty).toList();
}
