# New Spaced Repetition Logic Implementation

## Overview
The spaced repetition system has been completely rewritten to implement the specific logic you requested:

## Key Features

### 1. **Fixed Planned Review Dates**
- Each word gets assigned **fixed planned review dates** on first practice: `d1, d2, d4, d8, d15, d31, d60, d120, d180, d240, d360` (relative to first practice day)
- These planned dates **never change**, regardless of mistakes or hard word status
- Calculated once when word is first practiced, stored permanently

### 2. **Attempt Tracking**
- **Total attempts counter**: Tracks all attempts across word's lifetime
- **Current practice attempt counter**: Tracks attempts for current review session
- **Consecutive mistakes counter**: Tracks consecutive incorrect attempts

### 3. **Review Logic**

#### **Correct Attempt:**
- Reset consecutive mistakes counter
- Move to **next planned date** from fixed schedule
- Reset current practice attempt counter to 0

#### **Incorrect Attempt:**
- **First attempt** for current review (`currentPracticeAttempt === 1`):
  - Schedule for **immediate next day**
  - Keep current practice attempt counter
- **Not first attempt**:
  - Move to **next planned date** from fixed schedule
  - Reset current practice attempt counter to 0

### 4. **Hard Word Management**
- **3 consecutive mistakes** triggers hard word status
- **d5 and d6** dates are added to revision schedule
- Word marked as 'hard' but **planned dates remain unchanged**
- Hard dates inserted chronologically into existing schedule

### 5. **Data Structure**

#### **WordSchedule Model:**
```dart
@HiveType(typeId: 4)
class WordSchedule extends HiveObject {
  @HiveField(0) String word;
  @HiveField(1) int repetitionStep;           // Current step in planned sequence
  @HiveField(2) String lastReviewDate;       // YYYY-MM-DD
  @HiveField(3) String nextReviewDate;       // YYYY-MM-DD
  @HiveField(4) int incorrectCount;          // Total incorrect attempts
  @HiveField(5) bool isHard;                 // Hard word status
  @HiveField(6) String firstPracticeDate;   // Base date for calculations
  @HiveField(7) List<String> plannedDates;  // Fixed planned review dates
  @HiveField(8) int currentPracticeAttempt; // Current session attempt counter
  @HiveField(9) int totalAttempts;          // Total lifetime attempts
  @HiveField(10) int consecutiveMistakes;   // Consecutive mistake counter
  @HiveField(11) bool hasHardDates;         // Whether d5,d6 added
}
```

### 6. **WordAttempt Logging**
All attempts are logged with:
- `word`: The word being practiced
- `date`: Practice date (YYYY-MM-DD)
- `result`: 'correct', 'incorrect', or 'missed'
- `type`: 'auditory' or 'visual'
- `repetition_step`: Current step in schedule
- `is_hard`: Hard word status at time of attempt
- `hard_list_name`: Subject/list name

## Implementation Files

### **Modified Files:**
1. **`lib/services/spaced_repetition_service.dart`**
   - Complete rewrite of scheduling logic
   - New WordSchedule model with additional fields
   - Fixed planned dates system
   - Hard word management with d5/d6 insertion

2. **`lib/screens/todays_practice_screen.dart`**
   - New practice screen for today's scheduled words
   - Visual and Auditory practice options
   - Sample data generation for testing

3. **`lib/screens/main_screen.dart`**
   - Updated Practice tab to show new practice screen

### **Key Methods:**
- `updateWordSchedule(String word, bool isCorrect)`: Main logic implementation
- `_createNewWordSchedule()`: Creates initial schedule with fixed dates
- `_addHardWordDates()`: Inserts d5/d6 for hard words
- `generateSampleScheduleData()`: Creates test data with new logic

## Usage

### **Testing the New System:**
1. Go to **Practice tab** in the app
2. Click **"Add Sample Data"** to generate test schedules
3. Practice words using **Visual** or **Auditory** modes
4. Check **Progress → 📅 Schedule** to see the scheduling in action

### **Key Behaviors:**
- Words due today appear in Practice tab automatically
- First wrong attempt → retry tomorrow
- Subsequent wrong attempts → move to next planned date
- 3 consecutive mistakes → hard word with d5/d6 added
- All planned dates remain fixed regardless of performance

## Migration Notes

- **Existing data**: Old schedules will be automatically migrated when accessed
- **Backward compatibility**: Old calculation methods preserved for transition
- **Sample data**: Use "Add Sample Data" button to test new logic immediately

This implementation provides exactly the spaced repetition logic you specified with fixed planned dates, proper attempt tracking, and intelligent hard word management.
