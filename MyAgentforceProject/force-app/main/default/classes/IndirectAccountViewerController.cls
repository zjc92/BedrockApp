/**
 * AuraEnabled controller for the IndirectAccountViewer LWC.
 * Provides both a flat list (getIndirectAccounts) and a hierarchical tree
 * (getRelationshipTree) of indirect Account relationships via AccountContactRelation.
 */
public with sharing class IndirectAccountViewerController {

    // -------------------------------------------------------------------------
    // Hierarchical tree method (used by the branch-style UI)
    // -------------------------------------------------------------------------

    /**
     * Returns a full relationship tree for the current Account record:
     * root account name, direct contacts with roles, and indirect accounts
     * with shared contact details.
     *
     * @param recordId       The Id of the current Account record page.
     * @param recordLimit    Maximum indirect accounts to return.
     * @param sortBy         Sort indirect accounts by: 'Name' or 'RelationshipCount'.
     * @param sortDirection  'ASC' or 'DESC'.
     * @return RelationshipTreeDTO containing the full hierarchy.
     * @throws AuraHandledException on invalid input or query failure.
     */
    @AuraEnabled(cacheable=true)
    public static RelationshipTreeDTO getRelationshipTree(
        Id recordId,
        Integer recordLimit,
        String sortBy,
        String sortDirection
    ) {
        if (recordId == null) {
            throw new AuraHandledException('Record Id is required.');
        }

        Integer safeLimit = (recordLimit != null && recordLimit > 0) ? recordLimit : 10;
        String safeSortBy = resolveSortField(sortBy);
        String safeSortDirection = ('DESC'.equalsIgnoreCase(sortDirection)) ? 'DESC' : 'ASC';

        try {
            // --- Root account name ---
            List<Account> rootAccounts = [
                SELECT Id, Name
                FROM Account
                WHERE Id = :recordId
                WITH USER_MODE
                LIMIT 1
            ];
            if (rootAccounts.isEmpty()) {
                throw new AuraHandledException('Account record not found.');
            }
            String rootAccountName = rootAccounts[0].Name;

            // --- Step 1: direct contacts on the current account ---
            List<AccountContactRelation> directAcrs = [
                SELECT ContactId, Roles,
                       Contact.FirstName, Contact.LastName
                FROM AccountContactRelation
                WHERE AccountId = :recordId
                AND IsActive = TRUE
                WITH USER_MODE
            ];

            if (directAcrs.isEmpty()) {
                RelationshipTreeDTO emptyTree = new RelationshipTreeDTO();
                emptyTree.rootAccountName = rootAccountName;
                emptyTree.directContacts = new List<ContactNodeDTO>();
                emptyTree.indirectAccounts = new List<IndirectAccountNodeDTO>();
                return emptyTree;
            }

            // Build direct contact list and track shared contact Ids
            Set<Id> sharedContactIds = new Set<Id>();
            Map<Id, ContactNodeDTO> directContactByContactId = new Map<Id, ContactNodeDTO>();
            List<ContactNodeDTO> directContacts = new List<ContactNodeDTO>();

            for (AccountContactRelation acr : directAcrs) {
                ContactNodeDTO node = new ContactNodeDTO();
                node.contactId = acr.ContactId;
                node.contactName = (acr.Contact.FirstName ?? '') + ' ' + acr.Contact.LastName;
                node.contactName = node.contactName.trim();
                node.role = String.isNotBlank(acr.Roles) ? acr.Roles : '';
                directContacts.add(node);
                sharedContactIds.add(acr.ContactId);
                directContactByContactId.put(acr.ContactId, node);
            }

            // --- Step 2: ACRs for those contacts on OTHER accounts ---
            List<AggregateResult> indirectAggregates = [
                SELECT AccountId, COUNT(ContactId) contactCount
                FROM AccountContactRelation
                WHERE ContactId IN :sharedContactIds
                AND AccountId != :recordId
                AND IsActive = TRUE
                WITH USER_MODE
                GROUP BY AccountId
            ];

            if (indirectAggregates.isEmpty()) {
                RelationshipTreeDTO treeNoIndirect = new RelationshipTreeDTO();
                treeNoIndirect.rootAccountName = rootAccountName;
                treeNoIndirect.directContacts = directContacts;
                treeNoIndirect.indirectAccounts = new List<IndirectAccountNodeDTO>();
                return treeNoIndirect;
            }

            Set<Id> indirectAccountIds = new Set<Id>();
            Map<Id, Integer> sharedCountByAccountId = new Map<Id, Integer>();
            for (AggregateResult ar : indirectAggregates) {
                Id accId = (Id) ar.get('AccountId');
                indirectAccountIds.add(accId);
                sharedCountByAccountId.put(accId, (Integer) ar.get('contactCount'));
            }

            // --- Step 3: fetch indirect account details, exclude Person Accounts ---
            List<Account> indirectAccounts;
            if (isPersonAccountEnabled()) {
                indirectAccounts = [
                    SELECT Id, Name, Industry, AnnualRevenue
                    FROM Account
                    WHERE Id IN :indirectAccountIds
                    AND IsPersonAccount = FALSE
                    WITH USER_MODE
                ];
            } else {
                indirectAccounts = [
                    SELECT Id, Name, Industry, AnnualRevenue
                    FROM Account
                    WHERE Id IN :indirectAccountIds
                    WITH USER_MODE
                ];
            }

            // Strip inaccessible fields
            indirectAccounts = (List<Account>)
                Security.stripInaccessible(AccessType.READABLE, indirectAccounts).getRecords();

            // Rebuild set after Person Account / FLS filter
            Set<Id> accessibleAccountIds = new Set<Id>();
            for (Account acc : indirectAccounts) {
                accessibleAccountIds.add(acc.Id);
            }

            // --- Step 4: resolve shared contact details per indirect account ---
            List<AccountContactRelation> sharedAcrs = [
                SELECT AccountId, ContactId, Roles,
                       Contact.FirstName, Contact.LastName
                FROM AccountContactRelation
                WHERE AccountId IN :accessibleAccountIds
                AND ContactId IN :sharedContactIds
                AND IsActive = TRUE
                WITH USER_MODE
            ];

            Map<Id, List<ContactNodeDTO>> sharedContactsByAccountId =
                new Map<Id, List<ContactNodeDTO>>();
            for (AccountContactRelation acr : sharedAcrs) {
                if (!sharedContactsByAccountId.containsKey(acr.AccountId)) {
                    sharedContactsByAccountId.put(acr.AccountId, new List<ContactNodeDTO>());
                }
                ContactNodeDTO node = new ContactNodeDTO();
                node.contactId = acr.ContactId;
                node.contactName = (acr.Contact.FirstName ?? '') + ' ' + acr.Contact.LastName;
                node.contactName = node.contactName.trim();
                node.role = String.isNotBlank(acr.Roles) ? acr.Roles : '';
                sharedContactsByAccountId.get(acr.AccountId).add(node);
            }

            // --- Step 5: total relationship counts per indirect account ---
            List<AggregateResult> relationshipCounts = [
                SELECT AccountId, COUNT(Id) totalRelationships
                FROM AccountContactRelation
                WHERE AccountId IN :accessibleAccountIds
                AND IsActive = TRUE
                WITH USER_MODE
                GROUP BY AccountId
            ];
            Map<Id, Integer> relCountByAccountId = new Map<Id, Integer>();
            for (AggregateResult ar : relationshipCounts) {
                relCountByAccountId.put((Id) ar.get('AccountId'), (Integer) ar.get('totalRelationships'));
            }

            // --- Step 6: build IndirectAccountNodeDTO list ---
            List<IndirectAccountNodeDTO> indirectNodes = new List<IndirectAccountNodeDTO>();
            for (Account acc : indirectAccounts) {
                IndirectAccountNodeDTO node = new IndirectAccountNodeDTO();
                node.accountId = acc.Id;
                node.accountName = acc.Name;
                node.industry = acc.Industry;
                node.lifetimeValue = acc.AnnualRevenue;
                node.sharedContactCount = sharedCountByAccountId.containsKey(acc.Id)
                    ? sharedCountByAccountId.get(acc.Id) : 0;
                node.relationshipCount = relCountByAccountId.containsKey(acc.Id)
                    ? relCountByAccountId.get(acc.Id) : 0;
                node.sharedContacts = sharedContactsByAccountId.containsKey(acc.Id)
                    ? sharedContactsByAccountId.get(acc.Id) : new List<ContactNodeDTO>();
                indirectNodes.add(node);
            }

            sortIndirectAccounts(indirectNodes, safeSortBy, safeSortDirection);

            // Apply record limit
            List<IndirectAccountNodeDTO> limited = new List<IndirectAccountNodeDTO>();
            Integer cap = Math.min(safeLimit, indirectNodes.size());
            for (Integer i = 0; i < cap; i++) {
                limited.add(indirectNodes[i]);
            }

            RelationshipTreeDTO tree = new RelationshipTreeDTO();
            tree.rootAccountName = rootAccountName;
            tree.directContacts = directContacts;
            tree.indirectAccounts = limited;
            return tree;

        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Unable to retrieve relationship tree: ' + e.getMessage()
            );
        }
    }

    // -------------------------------------------------------------------------
    // Flat list method (kept for backwards compatibility)
    // -------------------------------------------------------------------------

    /**
     * Returns indirect account relationships for a given Account record.
     *
     * @param recordId       The Id of the current Account record page.
     * @param recordLimit    Maximum number of related accounts to return.
     * @param sortBy         Field to sort by: 'Name' or 'RelationshipCount'.
     * @param sortDirection  Sort direction: 'ASC' or 'DESC'.
     * @return List of IndirectAccountDTO representing related accounts.
     * @throws AuraHandledException on invalid input or query failure.
     */
    @AuraEnabled(cacheable=true)
    public static List<IndirectAccountDTO> getIndirectAccounts(
        Id recordId,
        Integer recordLimit,
        String sortBy,
        String sortDirection
    ) {
        if (recordId == null) {
            throw new AuraHandledException('Record Id is required.');
        }

        Integer safeLimit = (recordLimit != null && recordLimit > 0) ? recordLimit : 10;
        String safeSortBy = resolveSortField(sortBy);
        String safeSortDirection = ('DESC'.equalsIgnoreCase(sortDirection)) ? 'DESC' : 'ASC';

        try {
            List<AccountContactRelation> currentAccountRelations = [
                SELECT ContactId
                FROM AccountContactRelation
                WHERE AccountId = :recordId
                AND IsActive = TRUE
                WITH USER_MODE
            ];

            if (currentAccountRelations.isEmpty()) {
                return new List<IndirectAccountDTO>();
            }

            Set<Id> sharedContactIds = new Set<Id>();
            for (AccountContactRelation acr : currentAccountRelations) {
                sharedContactIds.add(acr.ContactId);
            }

            List<AggregateResult> aggregates = [
                SELECT AccountId, COUNT(ContactId) contactCount
                FROM AccountContactRelation
                WHERE ContactId IN :sharedContactIds
                AND AccountId != :recordId
                AND IsActive = TRUE
                WITH USER_MODE
                GROUP BY AccountId
            ];

            if (aggregates.isEmpty()) {
                return new List<IndirectAccountDTO>();
            }

            Set<Id> relatedAccountIds = new Set<Id>();
            Map<Id, Integer> contactCountByAccountId = new Map<Id, Integer>();
            for (AggregateResult ar : aggregates) {
                Id accountId = (Id) ar.get('AccountId');
                relatedAccountIds.add(accountId);
                contactCountByAccountId.put(accountId, (Integer) ar.get('contactCount'));
            }

            List<Account> relatedAccounts;
            if (isPersonAccountEnabled()) {
                relatedAccounts = [
                    SELECT Id, Name, Industry, AnnualRevenue
                    FROM Account
                    WHERE Id IN :relatedAccountIds
                    AND IsPersonAccount = FALSE
                    WITH USER_MODE
                ];
            } else {
                relatedAccounts = [
                    SELECT Id, Name, Industry, AnnualRevenue
                    FROM Account
                    WHERE Id IN :relatedAccountIds
                    WITH USER_MODE
                ];
            }

            List<AggregateResult> relationshipCounts = [
                SELECT AccountId, COUNT(Id) totalRelationships
                FROM AccountContactRelation
                WHERE AccountId IN :relatedAccountIds
                AND IsActive = TRUE
                WITH USER_MODE
                GROUP BY AccountId
            ];

            Map<Id, Integer> relationshipCountByAccountId = new Map<Id, Integer>();
            for (AggregateResult ar : relationshipCounts) {
                Id accountId = (Id) ar.get('AccountId');
                relationshipCountByAccountId.put(accountId, (Integer) ar.get('totalRelationships'));
            }

            List<Account> accessibleAccounts = (List<Account>)
                Security.stripInaccessible(AccessType.READABLE, relatedAccounts).getRecords();

            List<IndirectAccountDTO> results = new List<IndirectAccountDTO>();
            for (Account acc : accessibleAccounts) {
                IndirectAccountDTO dto = new IndirectAccountDTO();
                dto.accountId = acc.Id;
                dto.accountName = acc.Name;
                dto.industry = acc.Industry;
                dto.lifetimeValue = acc.AnnualRevenue;
                dto.sharedContactCount = contactCountByAccountId.containsKey(acc.Id)
                    ? contactCountByAccountId.get(acc.Id) : 0;
                dto.relationshipCount = relationshipCountByAccountId.containsKey(acc.Id)
                    ? relationshipCountByAccountId.get(acc.Id) : 0;
                results.add(dto);
            }

            sortResults(results, safeSortBy, safeSortDirection);

            List<IndirectAccountDTO> limited = new List<IndirectAccountDTO>();
            Integer resultSize = Math.min(safeLimit, results.size());
            for (Integer i = 0; i < resultSize; i++) {
                limited.add(results[i]);
            }
            return limited;

        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Unable to retrieve indirect account relationships: ' + e.getMessage()
            );
        }
    }

    // -------------------------------------------------------------------------
    // Private helpers
    // -------------------------------------------------------------------------

    private static Boolean isPersonAccountEnabled() {
        return Schema.SObjectType.Account.fields.getMap().containsKey('IsPersonAccount');
    }

    private static String resolveSortField(String sortBy) {
        if ('RelationshipCount'.equalsIgnoreCase(sortBy)) {
            return 'RelationshipCount';
        }
        return 'Name';
    }

    private static void sortIndirectAccounts(
        List<IndirectAccountNodeDTO> nodes,
        String sortBy,
        String sortDirection
    ) {
        Boolean ascending = 'ASC'.equals(sortDirection);
        for (Integer i = 0; i < nodes.size() - 1; i++) {
            for (Integer j = i + 1; j < nodes.size(); j++) {
                Boolean shouldSwap;
                if (sortBy == 'RelationshipCount') {
                    shouldSwap = ascending
                        ? nodes[i].sharedContactCount > nodes[j].sharedContactCount
                        : nodes[i].sharedContactCount < nodes[j].sharedContactCount;
                } else {
                    String nameI = nodes[i].accountName ?? '';
                    String nameJ = nodes[j].accountName ?? '';
                    shouldSwap = ascending
                        ? nameI.compareTo(nameJ) > 0
                        : nameI.compareTo(nameJ) < 0;
                }
                if (shouldSwap) {
                    IndirectAccountNodeDTO temp = nodes[i];
                    nodes[i] = nodes[j];
                    nodes[j] = temp;
                }
            }
        }
    }

    private static void sortResults(
        List<IndirectAccountDTO> results,
        String sortBy,
        String sortDirection
    ) {
        Boolean ascending = 'ASC'.equals(sortDirection);
        for (Integer i = 0; i < results.size() - 1; i++) {
            for (Integer j = i + 1; j < results.size(); j++) {
                Boolean shouldSwap;
                if (sortBy == 'RelationshipCount') {
                    shouldSwap = ascending
                        ? results[i].sharedContactCount > results[j].sharedContactCount
                        : results[i].sharedContactCount < results[j].sharedContactCount;
                } else {
                    String nameI = results[i].accountName ?? '';
                    String nameJ = results[j].accountName ?? '';
                    shouldSwap = ascending
                        ? nameI.compareTo(nameJ) > 0
                        : nameI.compareTo(nameJ) < 0;
                }
                if (shouldSwap) {
                    IndirectAccountDTO temp = results[i];
                    results[i] = results[j];
                    results[j] = temp;
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // DTOs
    // -------------------------------------------------------------------------

    /** Root DTO returned by getRelationshipTree. */
    public class RelationshipTreeDTO {
        @AuraEnabled public String rootAccountName;
        @AuraEnabled public List<ContactNodeDTO> directContacts;
        @AuraEnabled public List<IndirectAccountNodeDTO> indirectAccounts;
    }

    /** A contact node with name and role. */
    public class ContactNodeDTO {
        @AuraEnabled public Id contactId;
        @AuraEnabled public String contactName;
        @AuraEnabled public String role;
    }

    /** An indirect account node with shared contact details. */
    public class IndirectAccountNodeDTO {
        @AuraEnabled public Id accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public String industry;
        @AuraEnabled public Decimal lifetimeValue;
        @AuraEnabled public Integer sharedContactCount;
        @AuraEnabled public Integer relationshipCount;
        @AuraEnabled public List<ContactNodeDTO> sharedContacts;
    }

    /** Flat DTO kept for backwards compatibility. */
    public class IndirectAccountDTO {
        @AuraEnabled public Id accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public String industry;
        @AuraEnabled public Decimal lifetimeValue;
        @AuraEnabled public Integer sharedContactCount;
        @AuraEnabled public Integer relationshipCount;
    }
}
