public with sharing class ComplaintService {
    public static void applyBusinessRules(List<Customer_Complaint__c> complaints) {
        for (Customer_Complaint__c complaint : complaints) {
            if (complaint.Priority__c == 'Critical') {
                complaint.SLA_Expiration__c = System.now().addHours(1);
                complaint.Resolution_Notes__c = 'CRITICAL: 1-hour response required.';
            } else if (complaint.Priority__c == 'High') {
                complaint.SLA_Expiration__c = System.now().addHours(4);
                complaint.Resolution_Notes__c = 'High Priority: 4-hour response required.';
            } else if (complaint.Priority__c == 'Medium') {
                complaint.SLA_Expiration__c = System.now().addHours(24);
                complaint.Resolution_Notes__c = 'Medium Priority: 24-hour response.';
            } else {
                complaint.SLA_Expiration__c = System.now().addHours(48);
                complaint.Resolution_Notes__c = 'Standard Priority: 48-hour response.';
            }
        }
    }
}