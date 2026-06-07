// =============================================================================
// Add Missing AccountContactRelation Records — Bedrock Indirect Account Viewer
//
// Assumes Accounts and Contacts already exist. Does NOT create or modify
// Accounts or Contacts. Only inserts missing ACR records with Role values.
//
// Relationship model with roles:
//   Great Wall Corporation:
//     John Smith (Employee), Sarah Johnson (Customer), Michael Lee (Advisor)
//   Global Wealth Corporation:
//     John Smith (Customer), Sarah Johnson (Employee), Emma Wilson (Advisor)
//   Horizon Financial Corporation:
//     Sarah Johnson (Customer), Michael Lee (Employee), David Brown (Advisor)
//
// Run via: SFDX: Execute Anonymous Apex with Editor Contents
// =============================================================================

// --- 1. Resolve Accounts by Name ---------------------------------------------

final List<String> ACCOUNT_NAMES = new List<String>{
    'Bedrock Test - Great Wall Corporation',
    'Bedrock Test - Global Wealth Corporation',
    'Bedrock Test - Horizon Financial Corporation'
};

Map<String, Id> accountIdByName = new Map<String, Id>();
for (Account acc : [
    SELECT Id, Name
    FROM Account
    WHERE Name IN :ACCOUNT_NAMES
    AND IsPersonAccount = FALSE
    LIMIT 10
]) {
    accountIdByName.put(acc.Name, acc.Id);
}

System.debug('=== Accounts found ===');
for (String name : ACCOUNT_NAMES) {
    if (accountIdByName.containsKey(name)) {
        System.debug('  FOUND   - ' + name + ' : ' + accountIdByName.get(name));
    } else {
        System.debug('  MISSING - ' + name + ' (will be skipped)');
    }
}

Id greatWallId    = accountIdByName.get('Bedrock Test - Great Wall Corporation');
Id globalWealthId = accountIdByName.get('Bedrock Test - Global Wealth Corporation');
Id horizonId      = accountIdByName.get('Bedrock Test - Horizon Financial Corporation');

// Abort early if any account is missing
if (greatWallId == null || globalWealthId == null || horizonId == null) {
    throw new IllegalArgumentException(
        'One or more required Accounts were not found. Verify Account names and re-run.'
    );
}

// --- 2. Resolve Contacts by FirstName + LastName -----------------------------

final List<String> FIRST_NAMES = new List<String>{'John','Sarah','Michael','Emma','David'};
final List<String> LAST_NAMES  = new List<String>{'Smith','Johnson','Lee','Wilson','Brown'};

Map<String, Id> contactIdByFullName = new Map<String, Id>();
for (Contact c : [
    SELECT Id, FirstName, LastName
    FROM Contact
    WHERE LastName IN :LAST_NAMES
    AND FirstName IN :FIRST_NAMES
    LIMIT 50
]) {
    contactIdByFullName.put(c.FirstName + ' ' + c.LastName, c.Id);
}

System.debug('=== Contacts found ===');
final List<String> FULL_NAMES = new List<String>{
    'John Smith', 'Sarah Johnson', 'Michael Lee', 'Emma Wilson', 'David Brown'
};
for (String fullName : FULL_NAMES) {
    if (contactIdByFullName.containsKey(fullName)) {
        System.debug('  FOUND   - ' + fullName + ' : ' + contactIdByFullName.get(fullName));
    } else {
        System.debug('  MISSING - ' + fullName + ' (relationships for this contact will be skipped)');
    }
}

Id johnSmithId    = contactIdByFullName.get('John Smith');
Id sarahJohnsonId = contactIdByFullName.get('Sarah Johnson');
Id michaelLeeId   = contactIdByFullName.get('Michael Lee');
Id emmaWilsonId   = contactIdByFullName.get('Emma Wilson');
Id davidBrownId   = contactIdByFullName.get('David Brown');

// --- 3. Validate Role picklist values at runtime -----------------------------
// Roles on AccountContactRelation is a multi-select picklist.
// Collect the valid API values from the org's describe so the script does not
// fail if a value is missing in this org edition.

Set<String> validRoles = new Set<String>();
for (Schema.PicklistEntry entry :
        AccountContactRelation.Roles.getDescribe().getPicklistValues()) {
    if (entry.isActive()) {
        validRoles.add(entry.getValue());
    }
}
System.debug('Valid ACR Role values in this org: ' + validRoles);

// Returns the role string if valid, otherwise null (field left blank)
// Roles is a multi-select picklist — a single value is a valid entry
String safeRole(String role) {
    return validRoles.contains(role) ? role : null;
}

// --- 4. Define the desired relationships ------------------------------------

// Each entry: { AccountId, ContactId, Role }
// Declared as a list of inner wrapper objects for clarity
List<Object[]> desired = new List<Object[]>{
    // Great Wall Corporation
    new Object[]{ greatWallId,    johnSmithId,    safeRole('Employee') },
    new Object[]{ greatWallId,    sarahJohnsonId, safeRole('Customer') },
    new Object[]{ greatWallId,    michaelLeeId,   safeRole('Advisor')  },
    // Global Wealth Corporation
    new Object[]{ globalWealthId, johnSmithId,    safeRole('Customer') },
    new Object[]{ globalWealthId, sarahJohnsonId, safeRole('Employee') },
    new Object[]{ globalWealthId, emmaWilsonId,   safeRole('Advisor')  },
    // Horizon Financial Corporation
    new Object[]{ horizonId,      sarahJohnsonId, safeRole('Customer') },
    new Object[]{ horizonId,      michaelLeeId,   safeRole('Employee') },
    new Object[]{ horizonId,      davidBrownId,   safeRole('Advisor')  }
};

// Remove any entry where the ContactId resolved to null
List<Object[]> validDesired = new List<Object[]>();
for (Object[] row : desired) {
    if (row[1] != null) {
        validDesired.add(row);
    }
}

// --- 5. Query existing ACRs to detect duplicates ----------------------------

Set<Id> allAccountIds = new Set<Id>{ greatWallId, globalWealthId, horizonId };
Set<Id> allContactIds = new Set<Id>();
for (Object[] row : validDesired) {
    allContactIds.add((Id) row[1]);
}

Set<String> existingKeys = new Set<String>();
for (AccountContactRelation acr : [
    SELECT AccountId, ContactId
    FROM AccountContactRelation
    WHERE AccountId IN :allAccountIds
    AND ContactId IN :allContactIds
]) {
    existingKeys.add((String) acr.AccountId + '_' + (String) acr.ContactId);
}

// --- 6. Build insert and skip lists -----------------------------------------

List<AccountContactRelation> toInsert = new List<AccountContactRelation>();
List<String> skipped = new List<String>();

Map<Id, String> accountNameById = new Map<Id, String>{
    greatWallId    => 'Bedrock Test - Great Wall Corporation',
    globalWealthId => 'Bedrock Test - Global Wealth Corporation',
    horizonId      => 'Bedrock Test - Horizon Financial Corporation'
};
Map<Id, String> contactNameById = new Map<Id, String>();
for (String fullName : FULL_NAMES) {
    Id cId = contactIdByFullName.get(fullName);
    if (cId != null) {
        contactNameById.put(cId, fullName);
    }
}

for (Object[] row : validDesired) {
    Id   accId   = (Id)     row[0];
    Id   conId   = (Id)     row[1];
    String role  = (String) row[2];
    String key   = (String) accId + '_' + (String) conId;

    String label = accountNameById.get(accId) + ' <-> ' + contactNameById.get(conId);

    if (existingKeys.contains(key)) {
        skipped.add(label + ' (already exists)');
    } else {
        AccountContactRelation acr = new AccountContactRelation(
            AccountId = accId,
            ContactId = conId,
            IsActive  = true
        );
        if (String.isNotBlank(role)) {
            acr.Roles = role;
        }
        toInsert.add(acr);
    }
}

// --- 7. Insert missing ACRs -------------------------------------------------

Integer insertedCount = 0;
if (!toInsert.isEmpty()) {
    insert toInsert;
    insertedCount = toInsert.size();
}

// --- 8. Output summary -------------------------------------------------------

System.debug('=== AccountContactRelation records created: ' + insertedCount + ' ===');
for (AccountContactRelation acr : toInsert) {
    System.debug('  INSERTED - '
        + accountNameById.get(acr.AccountId)
        + ' <-> ' + contactNameById.get(acr.ContactId)
        + ' | Role: ' + (String.isNotBlank(acr.Roles) ? acr.Roles : '(none — role not in picklist)')
    );
}

System.debug('=== Relationships skipped (already existed): ' + skipped.size() + ' ===');
for (String s : skipped) {
    System.debug('  SKIPPED  - ' + s);
}

System.debug('=== Done ===');
