# Spaced Repetition Schedule Customization Guide

## Current Schedule Configuration
**File:** `lib/services/spaced_repetition_service.dart`

### Default Schedule (Line 7):
```dart
static const List<int> _scheduleDays = [1, 2, 4, 8, 16, 30, 60, 150];
```

This means:
- **Step 0:** Review in 1 day
- **Step 1:** Review in 2 days  
- **Step 2:** Review in 4 days
- **Step 3:** Review in 8 days
- **Step 4:** Review in 16 days
- **Step 5:** Review in 30 days
- **Step 6:** Review in 60 days
- **Step 7:** Review in 150 days (final step)

## How to Customize

### 1. **Change Review Intervals**
Replace the array with your preferred schedule:

**Example A - Shorter, More Frequent Reviews:**
```dart
static const List<int> _scheduleDays = [1, 2, 3, 7, 14, 30, 90];
```

**Example B - Longer, More Spaced Reviews:**
```dart
static const List<int> _scheduleDays = [1, 3, 7, 14, 30, 90, 180, 365];
```

**Example C - More Steps for Gradual Learning:**
```dart
static const List<int> _scheduleDays = [1, 2, 3, 5, 8, 13, 21, 34, 55, 89];
```

### 2. **Change Hard Word Threshold** (Line 39)
```dart
// Current: Word becomes "hard" after 3 wrong attempts
if (schedule.incorrectCount >= 3) {

// Make it more forgiving (5 wrong attempts):
if (schedule.incorrectCount >= 5) {

// Make it less forgiving (2 wrong attempts):
if (schedule.incorrectCount >= 2) {
```

### 3. **Modify Progression Logic**
The current logic (Lines 28-44):
- ✅ **Correct:** Move to next step
- ❌ **Incorrect:** Reset to day 1, increment error count

You could modify this to:
- Reset to previous step instead of step 0
- Add bonus steps for consecutive correct answers
- Implement different schedules for hard vs normal words

## Implementation Steps

1. **Edit the schedule array** in `spaced_repetition_service.dart`
2. **Run code generation** to update Hive adapters:
   ```bash
   flutter packages pub run build_runner build
   ```
3. **Test with the demo screen** (Progress → 📅 button)
4. **Clear existing data** if needed for testing:
   - The app will automatically apply new schedule to new words
   - Existing words will continue with their current step but use new intervals

## Testing Your Changes

Use the **Spaced Repetition Demo Screen** to verify your changes:
1. Go to **Progress tab**
2. Tap the **📅 Schedule** button
3. View the **Schedule Steps** section to see your new intervals
4. Check **Today's Words** to see how filtering works
5. Use **"Generate Sample Data"** to test with realistic data

## Important Notes

- **Array length determines maximum steps** - words complete the schedule when they reach the last step
- **Day counting starts from current date** - schedule calculates next review date from today
- **Hard words continue the same schedule** - but are marked for special attention
- **Changes apply immediately** to new words, existing words use new intervals for future reviews
