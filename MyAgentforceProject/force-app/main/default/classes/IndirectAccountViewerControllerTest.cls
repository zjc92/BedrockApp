/**
 * Test class for IndirectAccountViewerController.
 * Covers getIndirectAccounts (flat list) and getRelationshipTree (hierarchical).
 */
@IsTest
private class IndirectAccountViewerControllerTest {

    @TestSetup
    static void setupTestData() {
        Account primaryAccount = new Account(Name = 'Primary Account');
        insert primaryAccount;

        List<Account> relatedAccounts = new List<Account>{
            new Account(Name = 'Alpha Related', Industry = 'Technology', AnnualRevenue = 500000),
            new Account(Name = 'Beta Related', Industry = 'Finance', AnnualRevenue = 750000)
        };
        insert relatedAccounts;

        List<Contact> contacts = new List<Contact>{
            new Contact(LastName = 'Contact One',   AccountId = primaryAccount.Id),
            new Contact(LastName = 'Contact Two',   AccountId = primaryAccount.Id),
            new Contact(LastName = 'Contact Three', AccountId = primaryAccount.Id)
        };
        insert contacts;

        // Contact One and Two are shared with Alpha Related
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

        // Contact Three is shared with Beta Related
        insert new AccountContactRelation(
            AccountId = relatedAccounts[1].Id,
            ContactId = contacts[2].Id,
            IsActive = true
        );
    }

    // =========================================================================
    // getIndirectAccounts — flat list tests (backwards compatibility)
    // =========================================================================

    @IsTest
    static void shouldReturnIndirectAccounts_WhenValidRecordId() {
        Account primaryAccount = [SELECT Id FROM Account WHERE Name = 'Primary Account' LIMIT 1];

        Test.startTest();
        List<IndirectAccountViewerController.IndirectAccountDTO> results =
            IndirectAccountViewerController.getIndirectAccounts(
                primaryAccount.Id, 10, 'Name', 'ASC'
            );
        Test.stopTest();

        Assert.areEqual(2, results.size(), 'Should return 2 indirect accounts');
        Assert.areEqual('Alpha Related', results[0].accountName,
            'First result should be Alpha Related (ASC sort by Name)');
        Assert.areEqual('Beta Related', results[1].accountName,
            'Second result should be Beta Related (ASC sort by Name)');
    }

    @IsTest
    static void shouldReturnSharedContactCount_WhenRelationsExist() {
        Account primaryAccount = [SELECT Id FROM Account WHERE Name = 'Primary Account' LIMIT 1];

        Test.startTest();
        List<IndirectAccountViewerController.IndirectAccountDTO> results =
            IndirectAccountViewerController.getIndirectAccounts(
                primaryAccount.Id, 10, 'Name', 'ASC'
            );
        Test.stopTest();

        IndirectAccountViewerController.IndirectAccountDTO alphaDto =
            getFlatByName(results, 'Alpha Related');
        Assert.isNotNull(alphaDto, 'Alpha Related DTO should be present');
        Assert.areEqual(2, alphaDto.sharedContactCount,
            'Alpha Related should have 2 shared contacts');

        IndirectAccountViewerController.IndirectAccountDTO betaDto =
            getFlatByName(results, 'Beta Related');
        Assert.isNotNull(betaDto, 'Beta Related DTO should be present');
        Assert.areEqual(1, betaDto.sharedContactCount,
            'Beta Related should have 1 shared contact');
    }

    @IsTest
    static void shouldRespectRecordLimit_WhenLimitIsOne() {
        Account primaryAccount = [SELECT Id FROM Account WHERE Name = 'Primary Account' LIMIT 1];

        Test.startTest();
        List<IndirectAccountViewerController.IndirectAccountDTO> results =
            IndirectAccountViewerController.getIndirectAccounts(
                primaryAccount.Id, 1, 'Name', 'ASC'
            );
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'Record limit of 1 should return exactly 1 result');
    }

    @IsTest
    static void shouldSortDescending_WhenSortDirectionIsDesc() {
        Account primaryAccount = [SELECT Id FROM Account WHERE Name = 'Primary Account' LIMIT 1];

        Test.startTest();
        List<IndirectAccountViewerController.IndirectAccountDTO> results =
            IndirectAccountViewerController.getIndirectAccounts(
                primaryAccount.Id, 10, 'Name', 'DESC'
            );
        Test.stopTest();

        Assert.areEqual(2, results.size(), 'Should return 2 results');
        Assert.areEqual('Beta Related', results[0].accountName,
            'First result should be Beta Related (DESC sort by Name)');
        Assert.areEqual('Alpha Related', results[1].accountName,
            'Second result should be Alpha Related (DESC sort by Name)');
    }

    @IsTest
    static void shouldSortByRelationshipCount_WhenSortByIsRelationshipCount() {
        Account primaryAccount = [SELECT Id FROM Account WHERE Name = 'Primary Account' LIMIT 1];

        Test.startTest();
        List<IndirectAccountViewerController.IndirectAccountDTO> results =
            IndirectAccountViewerController.getIndirectAccounts(
                primaryAccount.Id, 10, 'RelationshipCount', 'DESC'
            );
        Test.stopTest();

        Assert.areEqual(2, results.size(), 'Should return 2 results');
        Assert.isTrue(
            results[0].sharedContactCount >= results[1].sharedContactCount,
            'Results should be sorted by sharedContactCount DESC'
        );
        Assert.areEqual('Alpha Related', results[0].accountName,
            'Alpha Related (2 shared) should come first when sorted by sharedContactCount DESC');
    }

    @IsTest
    static void shouldReturnEmpty_WhenAccountHasNoContacts() {
        Account isolatedAccount = new Account(Name = 'Isolated Account');
        insert isolatedAccount;

        Test.startTest();
        List<IndirectAccountViewerController.IndirectAccountDTO> results =
            IndirectAccountViewerController.getIndirectAccounts(
                isolatedAccount.Id, 10, 'Name', 'ASC'
            );
        Test.stopTest();

        Assert.areEqual(0, results.size(),
            'Account with no contacts should return empty list');
    }

    @IsTest
    static void shouldThrowAuraHandledException_WhenRecordIdIsNull() {
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
        Account primaryAccount = [SELECT Id FROM Account WHERE Name = 'Primary Account' LIMIT 1];

        Test.startTest();
        List<IndirectAccountViewerController.IndirectAccountDTO> results =
            IndirectAccountViewerController.getIndirectAccounts(
                primaryAccount.Id, null, 'Name', 'ASC'
            );
        Test.stopTest();

        Assert.isTrue(results.size() <= 10, 'Null limit should default to 10');
    }

    @IsTest
    static void shouldExcludePersonAccounts_WhenPersonAccountsAreEnabled() {
        Account primaryAccount = [SELECT Id FROM Account WHERE Name = 'Primary Account' LIMIT 1];

        Test.startTest();
        List<IndirectAccountViewerController.IndirectAccountDTO> results =
            IndirectAccountViewerController.getIndirectAccounts(
                primaryAccount.Id, 10, 'Name', 'ASC'
            );
        Test.stopTest();

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

    // =========================================================================
    // getRelationshipTree — hierarchical tree tests
    // =========================================================================

    @IsTest
    static void tree_shouldReturnRootAccountName() {
        Account primaryAccount = [SELECT Id FROM Account WHERE Name = 'Primary Account' LIMIT 1];

        Test.startTest();
        IndirectAccountViewerController.RelationshipTreeDTO tree =
            IndirectAccountViewerController.getRelationshipTree(
                primaryAccount.Id, 10, 'Name', 'ASC'
            );
        Test.stopTest();

        Assert.areEqual('Primary Account', tree.rootAccountName,
            'Root account name should match the queried account');
    }

    @IsTest
    static void tree_shouldReturnDirectContacts() {
        Account primaryAccount = [SELECT Id FROM Account WHERE Name = 'Primary Account' LIMIT 1];

        Test.startTest();
        IndirectAccountViewerController.RelationshipTreeDTO tree =
            IndirectAccountViewerController.getRelationshipTree(
                primaryAccount.Id, 10, 'Name', 'ASC'
            );
        Test.stopTest();

        Assert.isNotNull(tree.directContacts, 'Direct contacts list should not be null');
        Assert.areEqual(3, tree.directContacts.size(),
            'Should return 3 direct contacts (Contact One, Two, Three)');
    }

    @IsTest
    static void tree_shouldReturnDirectContactNames() {
        Account primaryAccount = [SELECT Id FROM Account WHERE Name = 'Primary Account' LIMIT 1];

        Test.startTest();
        IndirectAccountViewerController.RelationshipTreeDTO tree =
            IndirectAccountViewerController.getRelationshipTree(
                primaryAccount.Id, 10, 'Name', 'ASC'
            );
        Test.stopTest();

        Set<String> contactNames = new Set<String>();
        for (IndirectAccountViewerController.ContactNodeDTO node : tree.directContacts) {
            contactNames.add(node.contactName);
        }
        Assert.isTrue(contactNames.contains('Contact One'),   'Contact One should be present');
        Assert.isTrue(contactNames.contains('Contact Two'),   'Contact Two should be present');
        Assert.isTrue(contactNames.contains('Contact Three'), 'Contact Three should be present');
    }

    @IsTest
    static void tree_shouldReturnIndirectAccounts() {
        Account primaryAccount = [SELECT Id FROM Account WHERE Name = 'Primary Account' LIMIT 1];

        Test.startTest();
        IndirectAccountViewerController.RelationshipTreeDTO tree =
            IndirectAccountViewerController.getRelationshipTree(
                primaryAccount.Id, 10, 'Name', 'ASC'
            );
        Test.stopTest();

        Assert.isNotNull(tree.indirectAccounts, 'Indirect accounts list should not be null');
        Assert.areEqual(2, tree.indirectAccounts.size(),
            'Should return 2 indirect accounts');
    }

    @IsTest
    static void tree_shouldReturnSharedContactsPerIndirectAccount() {
        Account primaryAccount = [SELECT Id FROM Account WHERE Name = 'Primary Account' LIMIT 1];

        Test.startTest();
        IndirectAccountViewerController.RelationshipTreeDTO tree =
            IndirectAccountViewerController.getRelationshipTree(
                primaryAccount.Id, 10, 'Name', 'ASC'
            );
        Test.stopTest();

        IndirectAccountViewerController.IndirectAccountNodeDTO alphaNode =
            getNodeByName(tree.indirectAccounts, 'Alpha Related');
        Assert.isNotNull(alphaNode, 'Alpha Related node should be present');
        Assert.areEqual(2, alphaNode.sharedContactCount,
            'Alpha Related should have 2 shared contacts');
        Assert.isNotNull(alphaNode.sharedContacts, 'Shared contacts list should not be null');
        Assert.areEqual(2, alphaNode.sharedContacts.size(),
            'Alpha Related should have 2 shared contact nodes');

        IndirectAccountViewerController.IndirectAccountNodeDTO betaNode =
            getNodeByName(tree.indirectAccounts, 'Beta Related');
        Assert.isNotNull(betaNode, 'Beta Related node should be present');
        Assert.areEqual(1, betaNode.sharedContactCount,
            'Beta Related should have 1 shared contact');
        Assert.areEqual(1, betaNode.sharedContacts.size(),
            'Beta Related should have 1 shared contact node');
    }

    @IsTest
    static void tree_shouldSortIndirectAccountsByNameAsc() {
        Account primaryAccount = [SELECT Id FROM Account WHERE Name = 'Primary Account' LIMIT 1];

        Test.startTest();
        IndirectAccountViewerController.RelationshipTreeDTO tree =
            IndirectAccountViewerController.getRelationshipTree(
                primaryAccount.Id, 10, 'Name', 'ASC'
            );
        Test.stopTest();

        Assert.areEqual('Alpha Related', tree.indirectAccounts[0].accountName,
            'Alpha Related should come first in ASC order');
        Assert.areEqual('Beta Related', tree.indirectAccounts[1].accountName,
            'Beta Related should come second in ASC order');
    }

    @IsTest
    static void tree_shouldSortIndirectAccountsByNameDesc() {
        Account primaryAccount = [SELECT Id FROM Account WHERE Name = 'Primary Account' LIMIT 1];

        Test.startTest();
        IndirectAccountViewerController.RelationshipTreeDTO tree =
            IndirectAccountViewerController.getRelationshipTree(
                primaryAccount.Id, 10, 'Name', 'DESC'
            );
        Test.stopTest();

        Assert.areEqual('Beta Related', tree.indirectAccounts[0].accountName,
            'Beta Related should come first in DESC order');
        Assert.areEqual('Alpha Related', tree.indirectAccounts[1].accountName,
            'Alpha Related should come second in DESC order');
    }

    @IsTest
    static void tree_shouldRespectRecordLimit() {
        Account primaryAccount = [SELECT Id FROM Account WHERE Name = 'Primary Account' LIMIT 1];

        Test.startTest();
        IndirectAccountViewerController.RelationshipTreeDTO tree =
            IndirectAccountViewerController.getRelationshipTree(
                primaryAccount.Id, 1, 'Name', 'ASC'
            );
        Test.stopTest();

        Assert.areEqual(1, tree.indirectAccounts.size(),
            'Record limit of 1 should return exactly 1 indirect account');
    }

    @IsTest
    static void tree_shouldReturnEmptyIndirectAccounts_WhenNoSharedContacts() {
        Account isolatedAccount = new Account(Name = 'Isolated Account');
        insert isolatedAccount;

        Test.startTest();
        IndirectAccountViewerController.RelationshipTreeDTO tree =
            IndirectAccountViewerController.getRelationshipTree(
                isolatedAccount.Id, 10, 'Name', 'ASC'
            );
        Test.stopTest();

        Assert.areEqual(0, tree.directContacts.size(),
            'Isolated account should have no direct contacts');
        Assert.areEqual(0, tree.indirectAccounts.size(),
            'Isolated account should have no indirect accounts');
    }

    @IsTest
    static void tree_shouldThrowAuraHandledException_WhenRecordIdIsNull() {
        Test.startTest();
        try {
            IndirectAccountViewerController.getRelationshipTree(null, 10, 'Name', 'ASC');
            Assert.fail('Expected AuraHandledException for null recordId');
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
    static void tree_shouldDefaultToTenRecords_WhenLimitIsNull() {
        Account primaryAccount = [SELECT Id FROM Account WHERE Name = 'Primary Account' LIMIT 1];

        Test.startTest();
        IndirectAccountViewerController.RelationshipTreeDTO tree =
            IndirectAccountViewerController.getRelationshipTree(
                primaryAccount.Id, null, 'Name', 'ASC'
            );
        Test.stopTest();

        Assert.isTrue(tree.indirectAccounts.size() <= 10,
            'Null limit should default to 10');
    }

    @IsTest
    static void tree_shouldSortBySharedContactCountDesc_WhenSortByIsRelationshipCount() {
        Account primaryAccount = [SELECT Id FROM Account WHERE Name = 'Primary Account' LIMIT 1];

        Test.startTest();
        IndirectAccountViewerController.RelationshipTreeDTO tree =
            IndirectAccountViewerController.getRelationshipTree(
                primaryAccount.Id, 10, 'RelationshipCount', 'DESC'
            );
        Test.stopTest();

        Assert.areEqual(2, tree.indirectAccounts.size(), 'Should return 2 indirect accounts');
        Assert.areEqual('Alpha Related', tree.indirectAccounts[0].accountName,
            'Alpha Related (2 shared contacts) should come first when sorted by sharedContactCount DESC');
        Assert.areEqual('Beta Related', tree.indirectAccounts[1].accountName,
            'Beta Related (1 shared contact) should come second');
        Assert.isTrue(
            tree.indirectAccounts[0].sharedContactCount >= tree.indirectAccounts[1].sharedContactCount,
            'sharedContactCount should be non-increasing in DESC order'
        );
    }

    @IsTest
    static void tree_shouldSortBySharedContactCountAsc_WhenSortByIsRelationshipCount() {
        Account primaryAccount = [SELECT Id FROM Account WHERE Name = 'Primary Account' LIMIT 1];

        Test.startTest();
        IndirectAccountViewerController.RelationshipTreeDTO tree =
            IndirectAccountViewerController.getRelationshipTree(
                primaryAccount.Id, 10, 'RelationshipCount', 'ASC'
            );
        Test.stopTest();

        Assert.areEqual(2, tree.indirectAccounts.size(), 'Should return 2 indirect accounts');
        Assert.areEqual('Beta Related', tree.indirectAccounts[0].accountName,
            'Beta Related (1 shared contact) should come first when sorted by sharedContactCount ASC');
        Assert.areEqual('Alpha Related', tree.indirectAccounts[1].accountName,
            'Alpha Related (2 shared contacts) should come second');
        Assert.isTrue(
            tree.indirectAccounts[0].sharedContactCount <= tree.indirectAccounts[1].sharedContactCount,
            'sharedContactCount should be non-decreasing in ASC order'
        );
    }

    @IsTest
    static void tree_shouldExcludePersonAccounts() {
        Account primaryAccount = [SELECT Id FROM Account WHERE Name = 'Primary Account' LIMIT 1];

        Test.startTest();
        IndirectAccountViewerController.RelationshipTreeDTO tree =
            IndirectAccountViewerController.getRelationshipTree(
                primaryAccount.Id, 10, 'Name', 'ASC'
            );
        Test.stopTest();

        Set<Id> returnedIds = new Set<Id>();
        for (IndirectAccountViewerController.IndirectAccountNodeDTO node : tree.indirectAccounts) {
            returnedIds.add(node.accountId);
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

        Assert.areEqual(2, tree.indirectAccounts.size(),
            'Both business accounts should be in the tree');
    }

    // =========================================================================
    // Helpers
    // =========================================================================

    private static IndirectAccountViewerController.IndirectAccountDTO getFlatByName(
        List<IndirectAccountViewerController.IndirectAccountDTO> dtos,
        String name
    ) {
        for (IndirectAccountViewerController.IndirectAccountDTO dto : dtos) {
            if (dto.accountName == name) return dto;
        }
        return null;
    }

    private static IndirectAccountViewerController.IndirectAccountNodeDTO getNodeByName(
        List<IndirectAccountViewerController.IndirectAccountNodeDTO> nodes,
        String name
    ) {
        for (IndirectAccountViewerController.IndirectAccountNodeDTO node : nodes) {
            if (node.accountName == name) return node;
        }
        return null;
    }
}
