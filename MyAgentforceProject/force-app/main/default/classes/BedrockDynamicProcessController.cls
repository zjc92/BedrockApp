/**
 * AuraEnabled controller for the Bedrock Dynamic Process Framework LWC.
 * Selects active Bedrock_Process_Step__mdt records whose criteria match
 * the current record's attributes (Bedrock_Region__c, Amount, Customer_Rating__c).
 * Blank criteria values act as wildcards and match any record value.
 */
public with sharing class BedrockDynamicProcessController {

    /**
     * Returns ordered process step definitions that match the current record's
     * attributes. For Opportunity records, Bedrock_Region__c, Amount, and
     * Customer_Rating__c are evaluated against each metadata row's criteria.
     * Blank criteria fields are wildcards and always pass.
     *
     * @param recordId       Id of the current record (used to fetch attributes).
     * @param objectApiName  API name of the SObject (e.g. 'Opportunity').
     * @return               Ordered list of ProcessStepDTO, empty if none match.
     * @throws AuraHandledException on blank objectApiName or query failure.
     */
    @AuraEnabled(cacheable=true)
    public static List<ProcessStepDTO> getProcessSteps(Id recordId, String objectApiName) {
        if (String.isBlank(objectApiName)) {
            throw new AuraHandledException('Object API Name is required.');
        }

        try {
            RecordAttributes attrs = fetchRecordAttributes(recordId, objectApiName);

            List<Bedrock_Process_Step__mdt> allSteps =
                Bedrock_Process_Step__mdt.getAll().values();

            List<Bedrock_Process_Step__mdt> matched = new List<Bedrock_Process_Step__mdt>();
            for (Bedrock_Process_Step__mdt step : allSteps) {
                if (step.Active__c && matches(step, objectApiName, attrs)) {
                    matched.add(step);
                }
            }

            matched.sort(new StepOrderComparator());

            List<ProcessStepDTO> results = new List<ProcessStepDTO>();
            for (Bedrock_Process_Step__mdt step : matched) {
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
    // Matching helpers
    // -------------------------------------------------------------------------

    private static Boolean matches(
        Bedrock_Process_Step__mdt step,
        String objectApiName,
        RecordAttributes attrs
    ) {
        if (step.Object_API_Name__c != objectApiName) {
            return false;
        }

        // Region — blank metadata value = wildcard
        if (String.isNotBlank(step.Region__c)) {
            if (String.isBlank(attrs.region) || step.Region__c != attrs.region) {
                return false;
            }
        }

        // Customer Rating — blank metadata value = wildcard
        if (String.isNotBlank(step.Customer_Rating__c)) {
            if (String.isBlank(attrs.customerRating) || step.Customer_Rating__c != attrs.customerRating) {
                return false;
            }
        }

        // Min Amount — blank metadata value = no lower bound
        if (step.Min_Amount__c != null) {
            if (attrs.amount == null || attrs.amount < step.Min_Amount__c) {
                return false;
            }
        }

        // Max Amount — blank metadata value = no upper bound
        if (step.Max_Amount__c != null) {
            if (attrs.amount == null || attrs.amount > step.Max_Amount__c) {
                return false;
            }
        }

        return true;
    }

    // -------------------------------------------------------------------------
    // Record attribute fetching
    // -------------------------------------------------------------------------

    private static RecordAttributes fetchRecordAttributes(Id recordId, String objectApiName) {
        RecordAttributes attrs = new RecordAttributes();
        if (recordId == null || objectApiName != 'Opportunity') {
            return attrs;
        }

        List<Opportunity> opps = [
            SELECT Bedrock_Region__c, Amount, Customer_Rating__c
            FROM Opportunity
            WHERE Id = :recordId
            WITH USER_MODE
            LIMIT 1
        ];

        if (!opps.isEmpty()) {
            attrs.region         = opps[0].Bedrock_Region__c;
            attrs.amount         = opps[0].Amount;
            attrs.customerRating = opps[0].Customer_Rating__c;
        }
        return attrs;
    }

    // -------------------------------------------------------------------------
    // Inner classes
    // -------------------------------------------------------------------------

    private class RecordAttributes {
        String  region;
        Decimal amount;
        String  customerRating;
    }

    private class StepOrderComparator implements Comparator<Bedrock_Process_Step__mdt> {
        public Integer compare(Bedrock_Process_Step__mdt a, Bedrock_Process_Step__mdt b) {
            Decimal orderA = a.Display_Order__c ?? 0;
            Decimal orderB = b.Display_Order__c ?? 0;
            if (orderA < orderB) return -1;
            if (orderA > orderB) return 1;
            return 0;
        }
    }

    /**
     * DTO returned to the LWC.
     */
    public class ProcessStepDTO {
        @AuraEnabled public String  id;
        @AuraEnabled public String  stepLabel;
        @AuraEnabled public Integer displayOrder;
        @AuraEnabled public String  actionType;
        @AuraEnabled public String  description;

        public ProcessStepDTO(Bedrock_Process_Step__mdt step) {
            this.id           = step.DeveloperName;
            this.stepLabel    = step.Step_Label__c;
            this.displayOrder = step.Display_Order__c != null
                ? Integer.valueOf(step.Display_Order__c) : 0;
            this.actionType   = step.Action_Type__c;
            this.description  = step.Description__c;
        }
    }
}
