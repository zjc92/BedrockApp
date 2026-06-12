/**
 * AuraEnabled controller for the Bedrock Dynamic Process Framework LWC.
 *
 * Retrieves active Bedrock_Process_Step__mdt records that match the calling
 * record's runtime context (object API name, region, and deal amount).
 * Blank criteria fields on a metadata row act as wildcards and match any value.
 *
 * Custom Metadata Types are read via getAll() — the platform does not support
 * SOQL against __mdt in Apex. Filtering and ordering are performed in-memory.
 * Security.stripInaccessible is applied to equivalent SObject representations
 * via a SOQL re-fetch of the matched DeveloperNames so the platform FLS check
 * runs against real query results before DTO mapping.
 */
public with sharing class BedrockDynamicProcessController {

    private static final String STEP_LABEL_FIELD          = 'Step_Label__c';
    private static final String DISPLAY_ORDER_FIELD       = 'Display_Order__c';
    private static final String ACTION_TYPE_FIELD         = 'Action_Type__c';
    private static final String DESCRIPTION_FIELD         = 'Description__c';
    private static final String CRITERIA_REGION_FIELD     = 'Region__c';
    private static final String CRITERIA_MIN_AMOUNT_FIELD = 'Min_Amount__c';
    private static final String OBJECT_API_NAME_FIELD     = 'Object_API_Name__c';
    private static final String ACTIVE_FIELD              = 'Active__c';

    /**
     * Returns ordered process step DTOs whose criteria match the supplied
     * runtime context. Wildcard metadata rows (blank criteria) match any context.
     *
     * @param objectApiName  API name of the SObject (e.g. 'Opportunity').
     * @param currentRegion  Value of Bedrock_Region__c on the current record.
     * @param currentAmount  Value of BedrockAmount__c on the current record.
     * @return               Ordered list of ProcessStepDTO. Empty list when
     *                       objectApiName is blank or no rows match.
     */
    @AuraEnabled(cacheable=true)
    public static List<ProcessStepDTO> getActiveProcessSteps(
        String objectApiName,
        String currentRegion,
        Decimal currentAmount
    ) {
        if (String.isBlank(objectApiName)) {
            return new List<ProcessStepDTO>();
        }

        try {
            List<Bedrock_Process_Step__mdt> allSteps =
                Bedrock_Process_Step__mdt.getAll().values();

            List<Bedrock_Process_Step__mdt> matched =
                filterAndSort(allSteps, objectApiName, currentRegion, currentAmount);

            if (matched.isEmpty()) {
                return new List<ProcessStepDTO>();
            }

            Set<String> matchedNames = new Set<String>();
            for (Bedrock_Process_Step__mdt step : matched) {
                matchedNames.add(step.DeveloperName);
            }

            // Re-fetch matched rows via SOQL so Security.stripInaccessible
            // operates on proper query-result SObjects.
            List<Bedrock_Process_Step__mdt> queried = [
                SELECT Id,
                       DeveloperName,
                       Step_Label__c,
                       Display_Order__c,
                       Action_Type__c,
                       Action_Target__c,
                       Description__c
                FROM   Bedrock_Process_Step__mdt
                WHERE  DeveloperName IN :matchedNames
                ORDER BY Display_Order__c ASC NULLS LAST
            ];

            SObjectAccessDecision decision = Security.stripInaccessible(
                AccessType.READABLE,
                queried
            );

            List<ProcessStepDTO> results = new List<ProcessStepDTO>();
            for (Bedrock_Process_Step__mdt step :
                    (List<Bedrock_Process_Step__mdt>) decision.getRecords()) {
                results.add(new ProcessStepDTO(step));
            }
            return results;

        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Unable to retrieve process steps: ' + e.getMessage()
            );
        }
    }

    // -------------------------------------------------------------------------
    // Filtering and sorting
    // -------------------------------------------------------------------------

    private static List<Bedrock_Process_Step__mdt> filterAndSort(
        List<Bedrock_Process_Step__mdt> allSteps,
        String objectApiName,
        String currentRegion,
        Decimal currentAmount
    ) {
        List<Bedrock_Process_Step__mdt> matched =
            new List<Bedrock_Process_Step__mdt>();

        for (Bedrock_Process_Step__mdt step : allSteps) {
            if (!step.Active__c) {
                continue;
            }
            if (step.Object_API_Name__c != objectApiName) {
                continue;
            }
            if (!regionMatches(step, currentRegion)) {
                continue;
            }
            if (!amountMatches(step, currentAmount)) {
                continue;
            }
            matched.add(step);
        }

        matched.sort(new StepOrderComparator());
        return matched;
    }

    private static Boolean regionMatches(
        Bedrock_Process_Step__mdt step,
        String currentRegion
    ) {
        if (String.isBlank(step.Region__c)) {
            return true;
        }
        return step.Region__c == currentRegion;
    }

    private static Boolean amountMatches(
        Bedrock_Process_Step__mdt step,
        Decimal currentAmount
    ) {
        Boolean hasMin = step.Min_Amount__c != null;
        Boolean hasMax = step.Max_Amount__c != null;

        if (!hasMin && !hasMax) {
            return true;
        }
        if (currentAmount == null) {
            return false;
        }
        if (hasMin && currentAmount < step.Min_Amount__c) {
            return false;
        }
        if (hasMax && currentAmount > step.Max_Amount__c) {
            return false;
        }
        return true;
    }

    // -------------------------------------------------------------------------
    // Comparator
    // -------------------------------------------------------------------------

    private class StepOrderComparator implements Comparator<Bedrock_Process_Step__mdt> {
        public Integer compare(
            Bedrock_Process_Step__mdt a,
            Bedrock_Process_Step__mdt b
        ) {
            Decimal orderA = a.Display_Order__c ?? 0;
            Decimal orderB = b.Display_Order__c ?? 0;
            if (orderA < orderB) return -1;
            if (orderA > orderB) return  1;
            return 0;
        }
    }

    // -------------------------------------------------------------------------
    // DTO
    // -------------------------------------------------------------------------

    /**
     * Data transfer object returned to the LWC. Contains only the fields
     * required to render the process path and the step detail modal.
     */
    public class ProcessStepDTO {
        @AuraEnabled public String  stepId;
        @AuraEnabled public String  stepLabel;
        @AuraEnabled public Integer displayOrder;
        @AuraEnabled public String  actionType;
        @AuraEnabled public String  actionTarget;
        @AuraEnabled public String  description;

        public ProcessStepDTO(Bedrock_Process_Step__mdt step) {
            this.stepId       = step.DeveloperName;
            this.stepLabel    = step.Step_Label__c;
            this.displayOrder = step.Display_Order__c != null
                ? Integer.valueOf(step.Display_Order__c) : 0;
            this.actionType   = step.Action_Type__c;
            this.actionTarget = step.Action_Target__c;
            this.description  = step.Description__c;
        }
    }
}
