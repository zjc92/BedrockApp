/**
 * AuraEnabled controller for the Bedrock Dynamic Process Framework LWC.
 * Queries active Bedrock_Process_Step__mdt records for a given object,
 * sorts by Display_Order__c, and returns a list of ProcessStepDTO wrappers.
 */
public with sharing class BedrockDynamicProcessController {

    /**
     * Returns active process step definitions for the specified object.
     *
     * @param objectApiName  The API name of the SObject (e.g. 'Opportunity').
     * @return               Ordered list of ProcessStepDTO, empty if none found.
     * @throws AuraHandledException on blank input or unexpected failure.
     */
    @AuraEnabled(cacheable=true)
    public static List<ProcessStepDTO> getProcessSteps(String objectApiName) {
        if (String.isBlank(objectApiName)) {
            throw new AuraHandledException('Object API Name is required.');
        }

        try {
            List<Bedrock_Process_Step__mdt> steps = [
                SELECT Id, DeveloperName, MasterLabel,
                       Step_Label__c, Display_Order__c,
                       Action_Type__c, Description__c, Active__c
                FROM Bedrock_Process_Step__mdt
                WHERE Object_API_Name__c = :objectApiName
                AND Active__c = TRUE
                ORDER BY Display_Order__c ASC NULLS LAST
            ];

            List<ProcessStepDTO> results = new List<ProcessStepDTO>();
            for (Bedrock_Process_Step__mdt step : steps) {
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

    /**
     * DTO wrapper returned to the LWC. Maps Custom Metadata fields to
     * serialisable @AuraEnabled properties.
     */
    public class ProcessStepDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String stepLabel;
        @AuraEnabled public Integer displayOrder;
        @AuraEnabled public String actionType;
        @AuraEnabled public String description;

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
