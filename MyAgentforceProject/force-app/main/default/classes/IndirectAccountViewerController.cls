/**
 * AuraEnabled controller for the IndirectAccountViewer LWC.
 * Retrieves indirect Account relationships via AccountContactRelation,
 * aggregates shared contact counts, and returns lightweight DTOs.
 */
public with sharing class IndirectAccountViewerController {

    /**
     * Returns indirect account relationships for a given Account record.
     *
     * @param recordId  The Id of the current Account record page.
     * @param recordLimit  Maximum number of related accounts to return.
     * @param sortBy  Field to sort by: 'Name' or 'RelationshipCount'.
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
            // Step 1: find all ContactIds linked to the current Account (direct or indirect)
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

            // Step 2: find all other Accounts those contacts are also linked to
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

            // Step 3: fetch Account details with FLS enforcement
            List<Account> relatedAccounts = [
                SELECT Id, Name, Industry, AnnualRevenue
                FROM Account
                WHERE Id IN :relatedAccountIds
                WITH USER_MODE
            ];

            // Step 4: also count total ACR entries per related account for RelationshipCount
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

            // Step 5: strip inaccessible fields and build DTOs
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

    // Returns a validated sort field name
    private static String resolveSortField(String sortBy) {
        if ('RelationshipCount'.equalsIgnoreCase(sortBy)) {
            return 'RelationshipCount';
        }
        return 'Name';
    }

    // In-memory sort of DTO list
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
                        ? results[i].relationshipCount > results[j].relationshipCount
                        : results[i].relationshipCount < results[j].relationshipCount;
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

    /**
     * Data transfer object returned to the LWC.
     */
    public class IndirectAccountDTO {
        @AuraEnabled public Id accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public String industry;
        @AuraEnabled public Decimal lifetimeValue;
        @AuraEnabled public Integer sharedContactCount;
        @AuraEnabled public Integer relationshipCount;
    }
}
