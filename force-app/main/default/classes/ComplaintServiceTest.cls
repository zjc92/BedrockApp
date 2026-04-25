@isTest
public class ComplaintServiceTest {

    @isTest
    static void testComplaintCreation() {

        // Create test account
        Account acc = new Account(
            Name = 'Test Customer'
        );
        insert acc;

        Test.startTest();

        // Create complaint
        Customer_Complaint__c complaint = new Customer_Complaint__c(
            Customer_Account__c = acc.Id,
            Priority__c = 'High',
            Status__c = 'New'
        );

        insert complaint;

        Test.stopTest();

        // Verify result
        Customer_Complaint__c createdComplaint = [
            SELECT OwnerId, SLA_Expiration__c
            FROM Customer_Complaint__c
            WHERE Id = :complaint.Id
        ];

        System.assertNotEquals(null, createdComplaint.OwnerId);
        System.assertNotEquals(null, createdComplaint.SLA_Expiration__c);
    }
}