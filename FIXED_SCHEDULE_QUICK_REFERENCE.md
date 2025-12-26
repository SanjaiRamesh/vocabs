# Fixed Precomputed Schedule - Quick Reference Guide

## Core Concept
Words have a **fixed 18-date review schedule** precomputed on first attempt.
Each review date is **immutable** - results don't reschedule.
Only the **first attempt per review date** is recorded.

---

## Schedule Offsets (18 dates from anchor)
```
[1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 15, 16, 31, 32, 60, 120, 210, 390] days
```

---

## Main API Methods

### Initialize Review Plan
```dart
// Call on first attempt
await SpacedRepetitionService.initializeWordReviewPlan(
  'apple',      // word
  '2025-12-25', // anchor date (usually today)
);
// Creates 18 review dates in word_review_dates table
```

### Log an Attempt
```dart
final today = DateTime.now().toIso8601String().split('T')[0];

await SpacedRepetitionService.logWordAttempt(
  'apple',           // word
  today,             // review_date (which review is this for)
  'correct',         // result: 'correct' or 'incorrect'
  'apple',           // heard_or_typed: what user said/typed
);
// Only first attempt on this review_date is recorded
// Subsequent attempts on same date are ignored
```

### Get Words for Review
```dart
final today = DateTime.now().toIso8601String().split('T')[0];

// Get all words scheduled for review today
final reviewDates = await SpacedRepetitionService.getWordsForReview(today);

for (final reviewDate in reviewDates) {
  print('Word: ${reviewDate.word}, Step: ${reviewDate.stepIndex}');
  
  // Check if attempt exists for this review date
  final attempt = await SpacedRepetitionService.getAttemptForReviewDate(
    reviewDate.word,
    today,
  );
  
  if (attempt != null) {
    print('Result: ${attempt.result}'); // 'correct' or 'incorrect'
  } else {
    print('Not attempted yet');
  }
}
```

### Get All Review Dates for a Word
```dart
final reviewDates = await SpacedRepetitionService.getWordReviewDates('apple');

// Returns all 18 precomputed dates
for (final date in reviewDates) {
  print('${date.stepIndex}: ${date.reviewDate}');
}
```

### Get All Attempt Logs for a Word
```dart
final attempts = await SpacedRepetitionService.getWordAttemptLogs('apple');

for (final attempt in attempts) {
  print('${attempt.reviewDate}: ${attempt.result}');
}
```

---

## Database Tables

### word_review_plans
```sql
word TEXT PRIMARY KEY
anchor_date TEXT
created_at TEXT
```
One row per word (immutable after creation)

### word_review_dates
```sql
word TEXT
review_date TEXT
step_index INTEGER (0-17)
PRIMARY KEY (word, review_date)
```
18 rows per word (all precomputed)

### word_attempt_logs
```sql
word TEXT
review_date TEXT
result TEXT ('correct' or 'incorrect')
timestamp TEXT
heard_or_typed TEXT
PRIMARY KEY (word, review_date)
```
At most one row per word per review_date

---

## Backward Compatibility Methods
(Old code using WordSchedule still works)

```dart
// Returns synthetic WordSchedule
final schedule = await SpacedRepetitionService.getWordSchedule('apple');

// Get all schedules
final allSchedules = await SpacedRepetitionService.getAllSchedules();

// Get hard words
final hardWords = await SpacedRepetitionService.getHardWords();
```

---

## Example: Full Practice Flow

```dart
class MyPracticeScreen {
  Future<void> handleAttempt(String word, String userAnswer, bool isCorrect) async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    
    // 1. Initialize plan if first attempt
    final existingPlan = await SpacedRepetitionService.getWordReviewPlan(word);
    if (existingPlan == null) {
      await SpacedRepetitionService.initializeWordReviewPlan(word, today);
    }
    
    // 2. Log the attempt
    await SpacedRepetitionService.logWordAttempt(
      word,
      today,
      isCorrect ? 'correct' : 'incorrect',
      userAnswer,
    );
    
    // 3. Update UI (no rescheduling needed!)
    setState(() {
      _resultMessage = isCorrect ? 'Correct!' : 'Try again';
    });
  }
}
```

---

## Common Operations

### Check if word has been practiced
```dart
final plan = await SpacedRepetitionService.getWordReviewPlan('apple');
if (plan != null) {
  print('Word has been practiced since ${plan.anchorDate}');
}
```

### Get progress for a word
```dart
final attempts = await SpacedRepetitionService.getWordAttemptLogs('apple');
final correct = attempts.where((a) => a.result == 'correct').length;
final incorrect = attempts.where((a) => a.result == 'incorrect').length;
print('$correct correct, $incorrect incorrect');
```

### Get words due this week
```dart
final today = DateTime.now();
final thisWeek = <String>[];

for (int i = 0; i < 7; i++) {
  final date = today.add(Duration(days: i)).toIso8601String().split('T')[0];
  final reviewDates = await SpacedRepetitionService.getWordsForReview(date);
  thisWeek.addAll(reviewDates.map((r) => r.word));
}
```

---

## Key Principles

1. **Immutability**: Review dates never change once created
2. **No Rescheduling**: Correct/incorrect responses don't affect future dates
3. **First Only**: Multiple attempts on same date are ignored
4. **Clean Data**: One attempt per review date maximum
5. **Simple**: No complex state tracking (step, incorrect count, etc.)

---

## Files Changed
- `lib/models/word_review_plan.dart` (new)
- `lib/models/word_review_date.dart` (new)
- `lib/models/word_attempt_log.dart` (new)
- `lib/services/spaced_repetition_service.dart` (refactored)
- `lib/services/database_helper.dart` (new tables & methods)
- `lib/screens/practice_screen.dart` (one line change)

---

Generated: December 25, 2025
