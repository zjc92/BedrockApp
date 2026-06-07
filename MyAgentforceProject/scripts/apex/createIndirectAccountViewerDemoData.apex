// =============================================================================
// Demo Data: Bedrock Indirect Account Viewer
// Creates 3 business Accounts, 5 Contacts, and AccountContactRelation records
// that demonstrate indirect account relationships via shared contacts.
//
// Relationship model:
//   Great Wall Corporation      -> John Smith, Sarah Johnson, Michael Lee
//   Global Wealth Corporation   -> John Smith, Sarah Johnson, Emma Wilson
//   Horizon Financial Corp      -> Sarah Johnson, Michael Lee, David Brown
//
// Run via: SFDX: Execute Anonymous Apex with Editor Contents
// =============================================================================

// --- Accounts ----------------------------------------------------------------

// Upsert by Name to prevent duplicates on re-run
Map<String, Account> existingAccountsByName = new Map<String, Account>();
for (Account acc : [
    SELECT Id, Name
    FROM Account
    WHERE Name IN ('Great Wall Corporation', 'Global Wealth Corporation', 'Horizon Financial Corporation')
    AND IsPersonAccount = FALSE
]) {
    existingAccountsByName.put(acc.Name, acc);
}

List<Account> accountsToUpsert = new List<Account>{
    new Account(
        Name = 'Great Wall Corporation',
        Industry = 'Technology',
        AnnualRevenue = 5000000
    ),
    new Account(
        Name = 'Global Wealth Corporation',
        Industry = 'Finance',
        AnnualRevenue = 8500000
    ),
    new Account(
        Name = 'Horizon Financial Corporation',
        Industry = 'Finance',
        AnnualRevenue = 6200000
    )
};

List<Account> accountsToInsert = new List<Account>();
List<Account> accountsToUpdate = new List<Account>();

for (Account acc : accountsToUpsert) {
    if (existingAccountsByName.containsKey(acc.Name)) {
        acc.Id = existingAccountsByName.get(acc.Name).Id;
        accountsToUpdate.add(acc);
    } else {
        accountsToInsert.add(acc);
    }
}

if (!accountsToInsert.isEmpty()) {
    insert accountsToInsert;
}
if (!accountsToUpdate.isEmpty()) {
    update accountsToUpdate;
}

// Rebuild master map after DML
Map<String, Id> accountIdByName = new Map<String, Id>();
for (Account acc : [
    SELECT Id, Name
    FROM Account
    WHERE Name IN ('Great Wall Corporation', 'Global Wealth Corporation', 'Horizon Financial Corporation')
    AND IsPersonAccount = FALSE
]) {
    accountIdByName.put(acc.Name, acc.Id);
}

Id greatWallId   = accountIdByName.get('Great Wall Corporation');
Id globalWealthId = accountIdByName.get('Global Wealth Corporation');
Id horizonId     = accountIdByName.get('Horizon Financial Corporation');

System.debug('Account Id - Great Wall Corporation:    ' + greatWallId);
System.debug('Account Id - Global Wealth Corporation: ' + globalWealthId);
System.debug('Account Id - Horizon Financial Corporation: ' + horizonId);

// --- Contacts ----------------------------------------------------------------

List<String> contactLastNames = new List<String>{
    'Smith', 'Johnson', 'Lee', 'Wilson', 'Brown'
};
Map<String, String> firstNameByLastName = new Map<String, String>{
    'Smith'   => 'John',
    'Johnson' => 'Sarah',
    'Lee'     => 'Michael',
    'Wilson'  => 'Emma',
    'Brown'   => 'David'
};

// Check for existing contacts by LastName to prevent duplicates
Map<String, Contact> existingContactsByLastName = new Map<String, Contact>();
for (Contact c : [
    SELECT Id, LastName
    FROM Contact
    WHERE LastName IN :contactLastNames
    AND Account.Name IN ('Great Wall Corporation', 'Global Wealth Corporation', 'Horizon Financial Corporation')
]) {
    existingContactsByLastName.put(c.LastName, c);
}

// Contacts are created under Great Wall as the primary account;
// AccountContactRelation records handle the indirect links to the other accounts.
List<Contact> contactsToInsert = new List<Contact>();
for (String lastName : contactLastNames) {
    if (!existingContactsByLastName.containsKey(lastName)) {
        contactsToInsert.add(new Contact(
            FirstName = firstNameByLastName.get(lastName),
            LastName = lastName,
            AccountId = greatWallId
        ));
    }
}

if (!contactsToInsert.isEmpty()) {
    insert contactsToInsert;
}

// Rebuild contact Id map
Map<String, Id> contactIdByLastName = new Map<String, Id>();
for (Contact c : [
    SELECT Id, LastName
    FROM Contact
    WHERE LastName IN :contactLastNames
    AND AccountId = :greatWallId
]) {
    contactIdByLastName.put(c.LastName, c.Id);
}

Id johnSmithId    = contactIdByLastName.get('Smith');
Id sarahJohnsonId = contactIdByLastName.get('Johnson');
Id michaelLeeId   = contactIdByLastName.get('Lee');
Id emmaWilsonId   = contactIdByLastName.get('Wilson');
Id davidBrownId   = contactIdByLastName.get('Brown');

System.debug('Contact Id - John Smith:    ' + johnSmithId);
System.debug('Contact Id - Sarah Johnson: ' + sarahJohnsonId);
System.debug('Contact Id - Michael Lee:   ' + michaelLeeId);
System.debug('Contact Id - Emma Wilson:   ' + emmaWilsonId);
System.debug('Contact Id - David Brown:   ' + davidBrownId);

// --- AccountContactRelation records -----------------------------------------
// Great Wall:  John Smith, Sarah Johnson, Michael Lee  (direct link auto-created)
// Global Wealth: John Smith, Sarah Johnson, Emma Wilson
// Horizon:     Sarah Johnson, Michael Lee, David Brown

List<AccountContactRelation> acrToCreate = new List<AccountContactRelation>{
    // Global Wealth Corporation
    new AccountContactRelation(AccountId = globalWealthId, ContactId = johnSmithId,    IsActive = true),
    new AccountContactRelation(AccountId = globalWealthId, ContactId = sarahJohnsonId, IsActive = true),
    new AccountContactRelation(AccountId = globalWealthId, ContactId = emmaWilsonId,   IsActive = true),
    // Horizon Financial Corporation
    new AccountContactRelation(AccountId = horizonId, ContactId = sarahJohnsonId, IsActive = true),
    new AccountContactRelation(AccountId = horizonId, ContactId = michaelLeeId,   IsActive = true),
    new AccountContactRelation(AccountId = horizonId, ContactId = davidBrownId,   IsActive = true)
};

// Deduplicate: skip any ACR combination that already exists
Set<String> existingAcrKeys = new Set<String>();
for (AccountContactRelation existingAcr : [
    SELECT AccountId, ContactId
    FROM AccountContactRelation
    WHERE AccountId IN (:globalWealthId, :horizonId)
    AND ContactId IN (:johnSmithId, :sarahJohnsonId, :michaelLeeId, :emmaWilsonId, :davidBrownId)
]) {
    existingAcrKeys.add(existingAcr.AccountId + '_' + existingAcr.ContactId);
}

List<AccountContactRelation> acrToInsert = new List<AccountContactRelation>();
for (AccountContactRelation acr : acrToCreate) {
    String key = acr.AccountId + '_' + acr.ContactId;
    if (!existingAcrKeys.contains(key)) {
        acrToInsert.add(acr);
    }
}

if (!acrToInsert.isEmpty()) {
    insert acrToInsert;
}

System.debug('AccountContactRelation records inserted: ' + acrToInsert.size());

// --- Summary -----------------------------------------------------------------
System.debug('=== Demo data setup complete ===');
System.debug('Expected shared contacts:');
System.debug('  Great Wall <-> Global Wealth:  2 (John Smith, Sarah Johnson)');
System.debug('  Great Wall <-> Horizon:        2 (Sarah Johnson, Michael Lee)');
System.debug('  Global Wealth <-> Horizon:     1 (Sarah Johnson)');
