try {
    List<Opportunity> opps = [
        SELECT Bedrock_Region__c, Amount, Customer_Rating__c
        FROM Opportunity
        WITH USER_MODE
        LIMIT 1
    ];
    System.debug('Query ok, rows: ' + opps.size());
    if (!opps.isEmpty()) {
        System.debug('Region: ' + opps[0].Bedrock_Region__c);
        System.debug('Rating: ' + opps[0].Customer_Rating__c);
    }
} catch (Exception e) {
    System.debug('ERROR: ' + e.getTypeName() + ' - ' + e.getMessage());
}
