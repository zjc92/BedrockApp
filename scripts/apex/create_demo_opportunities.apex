// Delete any existing demo Opportunities from a previous run
List<Opportunity> existing = [
    SELECT Id FROM Opportunity
    WHERE Name IN ('Demo - APAC Strategic Deal', 'Demo - East Standard Deal')
];
if (!existing.isEmpty()) {
    delete existing;
}

insert new List<Opportunity>{
    new Opportunity(
        Name               = 'Demo - APAC Strategic Deal',
        StageName          = 'Prospecting',
        CloseDate          = Date.today().addDays(60),
        Amount             = 1500000,
        Bedrock_Region__c  = 'APAC',
        Customer_Rating__c = 'Strategic'
    ),
    new Opportunity(
        Name               = 'Demo - East Standard Deal',
        StageName          = 'Prospecting',
        CloseDate          = Date.today().addDays(60),
        Amount             = 50000,
        Bedrock_Region__c  = 'East',
        Customer_Rating__c = 'Standard'
    )
};

List<Opportunity> created = [
    SELECT Id, Name, Bedrock_Region__c, Customer_Rating__c, Amount
    FROM Opportunity
    WHERE Name IN ('Demo - APAC Strategic Deal', 'Demo - East Standard Deal')
    ORDER BY Name
];
for (Opportunity o : created) {
    System.debug(o.Name + ' | Id=' + o.Id + ' | Region=' + o.Bedrock_Region__c
        + ' | Rating=' + o.Customer_Rating__c + ' | Amount=' + o.Amount);
}
