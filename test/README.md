# Testing Guide

Тестҳо барои гирифтани буг-ҳо пеш аз production.

## Run tests

```bash
flutter test                          # Ҳамаи тестҳо
flutter test test/file_name.dart      # Як файл
flutter test --name "test name"       # Як тест алоҳида
```

## Test files

| File | What it tests |
|------|---------------|
| `word_repetition_service_test.dart` | Game mapping logic for repeat sessions |
| `word_repetition_state_test.dart` | State transitions (1→2→3→4), timeout intervals, isWordWithRepeat |
| `progress_merge_helper_test.dart` | Merge logic between local pending and backend data |
| `pending_sync_hold_test.dart` | 7-day hold window for optimistic updates |
| `widget_test.dart` | Basic widget smoke test |

## When to write a test

1. **Before fixing a bug** — write a failing test that reproduces the bug, then fix it
2. **After adding logic** — if the function has branches (if/else/switch), test each branch
3. **Edge cases** — empty lists, null values, boundary numbers (0, max)

## Pattern: unit test for pure function

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:vozhaomuz/path/to/your_service.dart';

void main() {
  group('YourService.yourMethod', () {
    test('describes the scenario', () {
      // Arrange
      final input = ...;
      
      // Act
      final result = YourService.yourMethod(input);
      
      // Assert
      expect(result, expectedValue);
    });
  });
}
```

## What's easy to test (pure logic)

- `WordRepetitionService` — state transitions, timeouts
- `ProgressMergeHelper` — merge rules
- Any `static` method with no I/O
- Model `fromJson` / `toJson`

## What's hard to test (needs mocks)

- Providers that depend on `SharedPreferences`, `Dio`, Firebase
- Widget tests (need `ProviderScope`, navigation)
- Anything that touches the filesystem or network

For these, focus on extracting **pure logic** into testable services.

## Example: added a new feature, now add a test

Say you added a function `calculatePremiumDiscount(int basePrice, String promoCode)`.

1. Create `test/premium_discount_test.dart`
2. Write tests:

```dart
test('no discount for empty promo code', () {
  expect(calculatePremiumDiscount(100, ''), 100);
});

test('20% discount for valid code', () {
  expect(calculatePremiumDiscount(100, 'SAVE20'), 80);
});

test('invalid code returns base price', () {
  expect(calculatePremiumDiscount(100, 'INVALID'), 100);
});
```

3. Run: `flutter test test/premium_discount_test.dart`
4. Green? Commit. Red? Fix the code.

## CI tip

Before building release APK:
```bash
flutter test && flutter build apk --release
```

If tests fail, the APK won't build — you catch bugs before users do.
