# KYC SBT Contract Test Cases

## Base Test Setup (KycSBTTest.sol)
- Sets up the basic test environment with ENS Registry, KYC Resolver, and KYC SBT contracts
- Configures initial state with owner and user addresses
- Defines common events and helper functions

## Core Functionality Tests (KycSBTCore.t.sol)

### KYC Request Tests
- `testRequestKycNormalName`: Tests requesting KYC with a normal length name (>= 5 chars)
  - Verifies ENS name registration
  - Checks KYC status is APPROVED
  - Validates basic KYC level assignment

### KYC Status Management Tests
- `testRevokeKyc`: Tests self-revocation of KYC status
  - Verifies status change to REVOKED
  - Checks event emissions
  - Validates resolver status update

- `testRestoreKyc`: Tests restoration of revoked KYC status
  - Verifies status change back to APPROVED
  - Validates event emissions
  - Checks resolver status update

- `testOwnerRevokeKyc`: Tests owner's ability to revoke KYC status
  - Verifies owner's revocation rights
  - Checks proper event emissions
  - Validates status changes

## Fee Management Tests (KycSBTFee.t.sol)

### Fee Configuration Tests
- `testInitialFees`: Verifies initial fee settings
  - Registration fee = 2 HSK
  - ENS fee = 2 HSK

### Total Fee Tests
- `testGetTotalFee`: Tests total fee calculation
  - Verifies correct sum of registration and ENS fees
  - Validates initial total fee amount

- `testGetTotalFeeAfterUpdate`: Tests total fee updates
  - Updates individual fees
  - Verifies total fee reflects changes
  - Validates calculation after fee updates

- `testGetTotalFeeConsistency`: Tests fee calculation consistency
  - Compares direct sum with getTotalFee()
  - Validates against helper method
  - Ensures all calculation methods match

### Fee Processing Tests
- `testExcessFeeRefund`: Tests refund of excess fees
  - Verifies correct fee deduction
  - Validates excess amount refund
  - Checks contract balance

- `testInsufficientTotalFee`: Tests insufficient fee handling
  - Verifies transaction reversion
  - Validates error message

### Fee Administration Tests
- `testWithdrawFees`: Tests fee withdrawal by owner
  - Verifies balance transfer
  - Validates contract balance clearing

- `testWithdrawFeesNotOwner`: Tests unauthorized withdrawal attempts
  - Verifies access control
  - Validates error message

## ENS Name Management Tests (KycSBTEns.t.sol)

### Name Validation and Approval Tests
- `testRequestKycNameTooShort`: Tests short name handling
  - Verifies short names are rejected without approval
  - Validates error message

### Other Validation Tests
- `testInvalidSuffix`: Tests invalid ENS suffix handling
  - Verifies suffix validation
  - Validates error message

- `testDuplicateRequest`: Tests duplicate registration prevention
  - Verifies unique name requirement
  - Validates error message

## Access Control Tests
- `testSetFeeNotOwner`: Tests unauthorized fee updates
  - Verifies access control for fee settings
  - Validates error messages

- `testWithdrawFeesNotOwner`: Tests unauthorized withdrawals
  - Verifies access control for withdrawals
  - Validates error messages

## Event Emission Tests
- `testSetEnsFeeEvent`: Tests fee update event emissions
  - Verifies event signature
  - Validates event data
  - Checks event parameters

## ENS Name Management Tests

### Short Name Approval Tests
- `testApproveShortName`: Tests short name approval process
  - Verifies owner can approve short names for specific users
  - Validates event emission
  - Checks approval status

- `testRequestShortNameWithoutApproval`: Tests unauthorized short name usage
  - Verifies unapproved short names are rejected
  - Validates error message

- `testRequestApprovedShortName`: Tests approved short name registration
  - Verifies approved short names can be registered by approved user
  - Validates KYC status after registration
  - Checks event emissions

### Access Control Tests
- `testApproveShortNameNotOwner`: Tests approval restrictions
  - Verifies only owner can approve short names
  - Validates error message

- `testApproveShortNameToAnotherUser`: Tests user-specific approvals
  - Verifies approvals are user-specific
  - Validates other users cannot use approved names

### Input Validation Tests
- `testApproveEmptyName`: Tests empty name validation
  - Verifies empty names are rejected
  - Validates error message

- `testApproveToZeroAddress`: Tests zero address validation
  - Verifies zero address approvals are rejected
  - Validates error message

- `testApproveAlreadyRegisteredName`: Tests duplicate registration prevention
  - Verifies registered names cannot be approved again
  - Validates error message

## Notes
- All tests use the `_getTotalFee()` helper function to calculate total required fees
- Tests verify both state changes and event emissions where applicable
- Error messages are checked for proper user feedback
- Access control is verified for all privileged operations