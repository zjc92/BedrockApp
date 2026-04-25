trigger CustomerComplaintTrigger on Customer_Complaint__c (before insert, before update) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert || Trigger.isUpdate) {
            // This calls the logic you defined in the Service Class
            ComplaintService.applyBusinessRules(Trigger.new);
        }
    }
} // <--- Ensure there is only ONE closing brace here and nothing after it