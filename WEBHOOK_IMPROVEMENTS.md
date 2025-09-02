# Webhook Test Data Handling Improvements

## Overview

The webhook processing system has been enhanced to better handle test data and provide clearer feedback during development and testing scenarios.

## Problem Addressed

When testing webhooks with test visit IDs like `test_visit_123`, the system would:
1. Make a GraphQL API call to Jobber with the test ID
2. Receive a GraphQL error: "not a valid EncodedId"
3. Fall back to enhanced fallback data (which worked correctly)
4. Successfully send email (which worked correctly)

While the system functioned correctly and delivered the email, the GraphQL error was confusing and unnecessary.

## Improvements Made

### 1. Test Visit ID Detection

**File:** `app/services/jobber_api_service.rb`

Added `test_visit_id?` method that detects common test patterns:
- `test_*` (e.g., `test_visit_123`)
- `mock_*` (e.g., `mock_visit_456`) 
- `dev_*` (e.g., `dev_test_abc`)
- `demo_*` (e.g., `demo_visit`)
- `*test123*` (contains "test" + numbers)
- `*fake*` (contains "fake")

When a test ID is detected, the API call is skipped and a clear message is returned.

### 2. Enhanced GraphQL Error Classification

**File:** `app/services/jobber_api_service.rb`

Improved error handling to distinguish between:
- Invalid ID format errors (likely test data)
- Other GraphQL errors (real API issues)

This provides better context for debugging.

### 3. Improved Webhook Controller Handling

**File:** `app/controllers/webhooks_controller.rb`

Added:
- Early test webhook detection with clear logging
- Better handling of test data API responses
- More informative console output for development

### 4. Test Webhook Detection

**File:** `app/controllers/webhooks_controller.rb`

Added `test_webhook?` method that detects test webhooks based on:
- Visit ID patterns
- Account ID patterns  
- Environment (development)
- Webhook content patterns

## Benefits

1. **Cleaner Logs**: No more confusing GraphQL errors for test data
2. **Better Developer Experience**: Clear indication when test data is being processed
3. **Same Functionality**: All existing behavior preserved - emails still send successfully
4. **Production Safety**: Real production data continues to work exactly as before
5. **Debugging Clarity**: Easier to distinguish between test scenarios and real issues

## Example Output

### Before (Confusing)
```
❌ GraphQL errors: [{"message"=>"Variable $visitId of type EncodedId! was provided invalid value", ...}]
❌ Failed to fetch Jobber data, using enhanced fallback
```

### After (Clear)
```
🧪 TEST WEBHOOK DETECTED - Processing with test-friendly handling
🧪 Test visit ID detected - skipping API call to avoid GraphQL error
🧪 Test visit ID detected - using enhanced fallback data for testing
```

## Testing

The improvements have been tested with various scenarios:
- Original failing webhook (`test_visit_123`) ✅
- Production webhook with real Jobber IDs ✅  
- Various test patterns (`mock_`, `dev_`, `fake`, etc.) ✅

All test scenarios now provide clear, appropriate feedback without unnecessary error messages.