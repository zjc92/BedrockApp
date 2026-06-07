/**
 * Test class for BedrockDynamicProcessController.
 * Custom Metadata records cannot be inserted in tests; tests validate
 * the controller's public contract, input validation, and DTO structure
 * using the records already deployed in the org.
 */
@IsTest
private class BedrockDynamicProcessControllerTest {

    @IsTest
    static void shouldReturnList_WhenObjectApiNameIsValid() {
        Test.startTest();
        List<BedrockDynamicProcessController.ProcessStepDTO> results =
            BedrockDynamicProcessController.getProcessSteps('Opportunity');
        Test.stopTest();

        Assert.isNotNull(results, 'Result list must not be null');
    }

    @IsTest
    static void shouldReturnEmptyList_WhenNoStepsExistForObject() {
        Test.startTest();
        List<BedrockDynamicProcessController.ProcessStepDTO> results =
            BedrockDynamicProcessController.getProcessSteps('Contact__Unknown__XYZ');
        Test.stopTest();

        Assert.isNotNull(results, 'Result list must not be null for unknown object');
        Assert.areEqual(0, results.size(),
            'Unknown object should return empty list');
    }

    @IsTest
    static void shouldThrowAuraHandledException_WhenObjectApiNameIsNull() {
        Test.startTest();
        try {
            BedrockDynamicProcessController.getProcessSteps(null);
            Assert.fail('Expected AuraHandledException for null objectApiName');
        } catch (AuraHandledException e) {
            Assert.isTrue(
                e.getMessage().contains('Object API Name is required') ||
                e.getMessage().contains('Script-thrown exception'),
                'Exception should indicate required objectApiName'
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void shouldThrowAuraHandledException_WhenObjectApiNameIsBlank() {
        Test.startTest();
        try {
            BedrockDynamicProcessController.getProcessSteps('   ');
            Assert.fail('Expected AuraHandledException for blank objectApiName');
        } catch (AuraHandledException e) {
            Assert.isTrue(
                e.getMessage().contains('Object API Name is required') ||
                e.getMessage().contains('Script-thrown exception'),
                'Exception should indicate required objectApiName'
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void shouldReturnDTOWithRequiredFields_WhenStepsExist() {
        List<BedrockDynamicProcessController.ProcessStepDTO> results =
            BedrockDynamicProcessController.getProcessSteps('Opportunity');

        if (results.isEmpty()) {
            return;
        }

        Test.startTest();
        BedrockDynamicProcessController.ProcessStepDTO first = results[0];
        Test.stopTest();

        Assert.isNotNull(first.id,         'id must not be null');
        Assert.isNotNull(first.stepLabel, 'stepLabel must not be null');
        Assert.isNotNull(first.displayOrder, 'displayOrder must not be null');
    }

    @IsTest
    static void shouldReturnStepsInAscendingDisplayOrder() {
        List<BedrockDynamicProcessController.ProcessStepDTO> results =
            BedrockDynamicProcessController.getProcessSteps('Opportunity');

        if (results.size() < 2) {
            return;
        }

        Test.startTest();
        Boolean ordered = true;
        for (Integer i = 1; i < results.size(); i++) {
            if (results[i].displayOrder < results[i - 1].displayOrder) {
                ordered = false;
                break;
            }
        }
        Test.stopTest();

        Assert.isTrue(ordered, 'Steps must be returned in ascending Display Order');
    }
}
