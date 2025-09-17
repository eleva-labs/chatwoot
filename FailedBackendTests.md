IMPORTANT:
There is a `develop` branch where a copy was made. This branch `develop` has been continuously worked on and has changed and diverged from the original copy (which also was worked on and diverged). A merge was made between both.
The branch `develop` is the branch that I want to keep as guidance without loosing the functionality on both development  journeys.

# Failed Backend Tests Analysis

## Overview
This document analyzes the currently failing backend tests from the Chatwoot test suite. The test suite now runs completely with all major architectural issues resolved.

# EXTREMELY VITAL: ALWAYS CHECK THE CURRENT ARCHITECTURE AND METHODS/SOLUTIONS THAT THE CODEBASE HAS REGARDING THE TESTS. SOLVE THE TESTS USING THE CURRENT ARCHITECTURE AND SOLUTIONS!!!

## Current Test Status

**GOOD NEWS**: The test suite is now fully functional with all critical blocking issues resolved. The remaining 13 failures are specific integration issues that can be fixed systematically.

**CURRENT STATUS**: 
- Test suite runs completely: ✅
- Major architectural issues resolved: ✅  
- WhatsApp validation issues fixed: ✅
- Feature flag issues resolved: ✅
- Only specific API integration issues remain: 13 failures to fix

## Currently Failing Tests (13 failures)

### Test Results Summary
- **Total Examples**: 4,296
- **Failures**: **13** 
- **Pending**: 4
- **Duration**: 26 minutes 55 seconds

### 1. Instagram API Integration Failures (10 failures)

**Files Affected**: 
- `spec/jobs/webhooks/instagram_events_job_spec.rb` (9 failures)
- `spec/models/channel/instagram_spec.rb` (1 failure)

**Root Causes**:
1. **Missing WebMock stubs for Instagram Graph API**: Tests are making real HTTP requests to `https://graph.instagram.com/v22.0/` endpoints
2. **Service signature mismatch**: `Instagram::ReadStatusService` expects `Channel::FacebookPage` but receives `Channel::Instagram`
3. **Test data issues**: Undefined variable `return_object` in test
4. **Logic errors**: Expected message content not matching actual content
5. **Factory/model inconsistencies**: Different inbox instances being compared

### 2. WhatsApp Provider Cleanup Issues (2 failures)

**File**: `spec/models/channel/whatsapp_spec.rb`

**Root Cause**: 
- `NoMethodError: private method 'cleanup_on_destroy' called` 
- The cleanup method is private but being called as public

**Error Pattern**:
```ruby
NoMethodError: private method 'cleanup_on_destroy' called for an instance of Whatsapp::ProviderConfig::WhatsappCloud
```

### 3. Model Factory Issues (1 failure)

**File**: `spec/models/channel/instagram_spec.rb`
**Test**: `creates contact inbox with identifier`
**Error**: Different inbox instances being compared (ID mismatch)
**Root Cause**: Factory creating different instances than expected

## Priority Order for Current Fixes

1. **HIGH**: Fix Instagram WebMock stubs (8 failures) - Add comprehensive API stubs
2. **MEDIUM**: Fix WhatsApp provider cleanup method visibility (2 failures) - Make method public or adjust call
3. **MEDIUM**: Fix Instagram service signature mismatch (1 failure) - Update service to handle both channel types  
4. **LOW**: Fix test data and logic issues (2 failures) - Clean up test variables and expectations

## Detailed Analysis of Current Failures

### 1. Instagram WebMock Stub Missing (8 failures)
**Pattern**: `WebMock::NetConnectNotAllowedError: Real HTTP connections are disabled`
**URL**: `https://graph.instagram.com/v22.0/Sender-id-{random}?access_token={token}&fields=name,username,profile_pic,follower_count,is_user_follow_business,is_business_follow_user,is_verified_user`

**Affected Tests**:
- `creates incoming message in the instagram inbox`
- `creates standby message in the instagram inbox` 
- `creates incoming message with attachments in the instagram inbox`
- `creates incoming message with attachments in the instagram inbox for story mention`
- `handles unsupported message`
- `sets fallback identifier when username is not available`
- `creates incoming message with attachments in the instagram direct inbox`

**Solution**: Add WebMock stubs for Instagram Graph API user profile endpoints

### 2. Instagram Service Signature Mismatch (1 failure)
**Error**: `Instagram::ReadStatusService` expects `Channel::FacebookPage` but receives `Channel::Instagram`
**Test**: `handle messaging_seen callback`
**Root Cause**: Service was designed for Facebook pages but now needs to handle Instagram channels

### 3. Test Data Issues (1 failure)  
**Error**: `undefined local variable or method 'return_object'`
**Test**: `creates incoming message with share attachments`
**Root Cause**: Missing variable definition in test

### 4. Instagram Logic/Content Mismatch (1 failure)
**Test**: `handle instagram unsend message event`
**Expected**: `"This message was deleted"`
**Got**: `"Incoming Message"`
**Root Cause**: Unsend message logic not working as expected

### 5. WhatsApp Provider Method Visibility (2 failures)
**Error**: `NoMethodError: private method 'cleanup_on_destroy' called for an instance of Whatsapp::ProviderConfig::WhatsappCloud`
**File**: `spec/models/channel/whatsapp_spec.rb`
**Tests**:
- `calls WebhookTeardownService on destroy`
- `does not call WebhookTeardownService on destroy`

**Root Cause**: The `cleanup_on_destroy` method in `Whatsapp::ProviderConfig::WhatsappCloud` is private but being called as public

### 6. Instagram Factory Instance Mismatch (1 failure)
**File**: `spec/models/channel/instagram_spec.rb`
**Test**: `creates contact inbox with identifier`
**Error**: Different inbox instances being compared (ID mismatch)
**Root Cause**: Factory creating different instances than expected

## Next Steps

1. **Add Instagram Graph API WebMock stubs** - Most critical current issue (8 failures)
2. **Fix WhatsApp provider method visibility** - Quick fix needed (2 failures)
3. **Address Instagram service signatures** - Update to handle both Facebook and Instagram channels
4. **Clean up test data issues** - Fix undefined variables and content expectations
