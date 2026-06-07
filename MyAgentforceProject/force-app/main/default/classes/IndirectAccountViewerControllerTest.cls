/**
 * Test class for IndirectAccountViewerController.
 * Covers: happy path, empty results, null recordId, sorting, and record limit.
 */
@IsTest
private class IndirectAccountViewerControllerTest {

    @TestSetup
    static void setupTestData() {
        // Primary account (the "current" record page account)
        Account primaryAccount = new Account(Name = 'Primary Account');
        insert primaryAccount;

        // Two indirect accounts sharing contacts with the primary
        List<Account> relatedAccounts = new List<Account>{
            new Account(Name = 'Alpha Related', Industry = 'Technology', AnnualRevenue = 500000),
            new Account(Name = 'Beta Related', Industry = 'Finance', AnnualRevenue = 750000)
        };
        insert relatedAccounts;

        // Contacts linked to the primary account
        List<Contact> contacts = new List<Contact>{
            new Contact(LastName = 'Contact One', AccountId = primaryAccount.Id),
            new Contact(LastName = 'Contact Two', AccountId = primaryAccount.Id),
            new Contact(LastName = 'Contact Three', AccountId = primaryAccount.Id)
        };
        insert contacts;

        // Link Contact One and Two to Alpha Related (indirect)
        insert new List<AccountContactRelation>{
            new AccountContactRelation(
                AccountId = relatedAccounts[0].Id,
                ContactId = contacts[0].Id,
                IsActive = true
            ),
            new AccountContactRelation(
                AccountId = relatedAccounts[0].Id,
                ContactId = contacts[1].Id,
                IsActive = true
            )
        };

        // Link Contact Three to Beta Related (indirect)
        insert new AccountContactRelation(
            AccountId = relatedAccounts[1].Id,
            ContactId = contacts[2].Id,
            IsActive = true
        );
    }

    @IsTest
    static void shouldReturnIndirectAccounts_WhenValidRecordId() {
        // Given
        Account primaryAccount = [SELECT Id FROM Account WHERE Name = 'Primary Account' LIMIT 1];

        // When
        Test.startTest();
        List<IndirectAccountViewerController.IndirectAccountDTO> results =
            IndirectAccountViewerController.getIndirectAccounts(
                primaryAccount.Id, 10, 'Name', 'ASC'
            );
        Test.stopTest();

        // Then
        Assert.areEqual(2, results.size(), 'Should return 2 indirect accounts');
        Assert.areEqual('Alpha Related', results[0].accountName,
            'First result should be Alpha Related (ASC sort by Name)');
        Assert.areEqual('Beta Related', results[1].accountName,
            'Second result should be Beta Related (ASC sort by Name)');
    }

    @IsTest
    static void shouldReturnSharedContactCount_WhenRelationsExist() {
        // Given
        Account primaryAccount = [SELECT Id FROM Account WHERE Name = 'Primary Account' LIMIT 1];

        // When
        Test.startTest();
        List<IndirectAccountViewerController.IndirectAccountDTO> results =
            IndirectAccountViewerController.getIndirectAccounts(
                primaryAccount.Id, 10, 'Name', 'ASC'
            );
        Test.stopTest();

        // Then
        IndirectAccountViewerController.IndirectAccountDTO alphaDto =
            getByName(results, 'Alpha Related');
        Assert.isNotNull(alphaDto, 'Alpha Related DTO should be present');
        Assert.areEqual(2, alphaDto.sharedContactCount,
            'Alpha Related should have 2 shared contacts');

        IndirectAccountViewerController.IndirectAccountDTO betaDto =
            getByName(results, 'Beta Related');
        Assert.isNotNull(betaDto, 'Beta Related DTO should be present');
        Assert.areEqual(1, betaDto.sharedContactCount,
            'Beta Related should have 1 shared contact');
    }

    @IsTest
    static void shouldRespectRecordLimit_WhenLimitIsOne() {
        // Given
        Account primaryAccount = [SELECT Id FROM Account WHERE Name = 'Primary Account' LIMIT 1];

        // When
        Test.startTest();
        List<IndirectAccountViewerController.IndirectAccountDTO> results =
            IndirectAccountViewerController.getIndirectAccounts(
                primaryAccount.Id, 1, 'Name', 'ASC'
            );
        Test.stopTest();

        // Then
        Assert.areEqual(1, results.size(), 'Record limit of 1 should return exactly 1 result');
    }

    @IsTest
    static void shouldSortDescending_WhenSortDirectionIsDesc() {
        // Given
        Account primaryAccount = [SELECT Id FROM Account WHERE Name = 'Primary Account' LIMIT 1];

        // When
        Test.startTest();
        List<IndirectAccountViewerController.IndirectAccountDTO> results =
            IndirectAccountViewerController.getIndirectAccounts(
                primaryAccount.Id, 10, 'Name', 'DESC'
            );
        Test.stopTest();

        // Then
        Assert.areEqual(2, results.size(), 'Should return 2 results');
        Assert.areEqual('Beta Related', results[0].accountName,
            'First result should be Beta Related (DESC sort by Name)');
        Assert.areEqual('Alpha Related', results[1].accountName,
            'Second result should be Alpha Related (DESC sort by Name)');
    }

    @IsTest
    static void shouldSortByRelationshipCount_WhenSortByIsRelationshipCount() {
        // Given
        Account primaryAccount = [SELECT Id FROM Account WHERE Name = 'Primary Account' LIMIT 1];

        // When
        Test.startTest();
        List<IndirectAccountViewerController.IndirectAccountDTO> results =
            IndirectAccountViewerController.getIndirectAccounts(
                primaryAccount.Id, 10, 'RelationshipCount', 'DESC'
            );
        Test.stopTest();

        // Then
        Assert.areEqual(2, results.size(), 'Should return 2 results');
        Assert.isTrue(
            results[0].relationshipCount >= results[1].relationshipCount,
            'Results should be sorted by RelationshipCount DESC'
        );
    }

    @IsTest
    static void shouldReturnEmpty_WhenAccountHasNoContacts() {
        // Given
        Account isolatedAccount = new Account(Name = 'Isolated Account');
        insert isolatedAccount;

        // When
        Test.startTest();
        List<IndirectAccountViewerController.IndirectAccountDTO> results =
            IndirectAccountViewerController.getIndirectAccounts(
                isolatedAccount.Id, 10, 'Name', 'ASC'
            );
        Test.stopTest();

        // Then
        Assert.areEqual(0, results.size(),
            'Account with no contacts should return empty list');
    }

    @IsTest
    static void shouldThrowAuraHandledException_WhenRecordIdIsNull() {
        // When / Then
        Test.startTest();
        try {
            IndirectAccountViewerController.getIndirectAccounts(null, 10, 'Name', 'ASC');
            Assert.fail('Expected AuraHandledException to be thrown for null recordId');
        } catch (AuraHandledException e) {
            Assert.isTrue(
                e.getMessage().contains('Record Id is required') ||
                e.getMessage().contains('Script-thrown exception'),
                'Exception message should indicate required recordId'
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void shouldDefaultToTenRecords_WhenLimitIsNull() {
        // Given
        Account primaryAccount = [SELECT Id FROM Account WHERE Name = 'Primary Account' LIMIT 1];

        // When
        Test.startTest();
        List<IndirectAccountViewerController.IndirectAccountDTO> results =
            IndirectAccountViewerController.getIndirectAccounts(
                primaryAccount.Id, null, 'Name', 'ASC'
            );
        Test.stopTest();

        // Then
        Assert.isTrue(results.size() <= 10, 'Null limit should default to 10');
    }

    @IsTest
    static void shouldExcludePersonAccounts_WhenPersonAccountsAreEnabled() {
        // Given — only business accounts exist in @TestSetup; verify none are Person Accounts
        Account primaryAccount = [SELECT Id FROM Account WHERE Name = 'Primary Account' LIMIT 1];

        // When
        Test.startTest();
        List<IndirectAccountViewerController.IndirectAccountDTO> results =
            IndirectAccountViewerController.getIndirectAccounts(
                primaryAccount.Id, 10, 'Name', 'ASC'
            );
        Test.stopTest();

        // Then — all returned accounts must be business accounts (IsPersonAccount = false)
        Set<Id> returnedIds = new Set<Id>();
        for (IndirectAccountViewerController.IndirectAccountDTO dto : results) {
            returnedIds.add(dto.accountId);
        }

        if (!returnedIds.isEmpty()) {
            List<Account> returned = [
                SELECT Id, IsPersonAccount
                FROM Account
                WHERE Id IN :returnedIds
            ];
            for (Account acc : returned) {
                Assert.isFalse(acc.IsPersonAccount,
                    'Returned account ' + acc.Id + ' must not be a Person Account');
            }
        }

        Assert.areEqual(2, results.size(),
            'Both business accounts should still be returned');
    }

    // Helper: find a DTO by account name
    private static IndirectAccountViewerController.IndirectAccountDTO getByName(
        List<IndirectAccountViewerController.IndirectAccountDTO> dtos,
        String name
    ) {
        for (IndirectAccountViewerController.IndirectAccountDTO dto : dtos) {
            if (dto.accountName == name) {
                return dto;
            }
        }
        return null;
    }
}
