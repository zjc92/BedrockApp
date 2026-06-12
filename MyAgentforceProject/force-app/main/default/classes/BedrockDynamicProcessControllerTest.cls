/**
 * Unit tests for BedrockDynamicProcessController.
 *
 * Custom Metadata records are read-only in tests (cannot be inserted).
 * Tests validate the public contract, input guard behaviour, DTO shape,
 * and routing logic against whatever metadata rows are deployed in the org.
 */
@IsTest
private class BedrockDynamicProcessControllerTest {

    // =========================================================================
    // Input guard — blank objectApiName must return empty list
    // =========================================================================

    @IsTest
    static void shouldReturnEmptyList_WhenObjectApiNameIsNull() {
        // Given / When
        Test.startTest();
        List<BedrockDynamicProcessController.ProcessStepDTO> results =
            BedrockDynamicProcessController.getActiveProcessSteps(null, 'East', 50000);
        Test.stopTest();

        // Then — must never throw; must return a zero-size initialized list
        Assert.isNotNull(results, 'Result must not be null when objectApiName is null');
        Assert.areEqual(0, results.size(),
            'Empty list expected when objectApiName is null');
    }

    @IsTest
    static void shouldReturnEmptyList_WhenObjectApiNameIsBlank() {
        // Given / When
        Test.startTest();
        List<BedrockDynamicProcessController.ProcessStepDTO> results =
            BedrockDynamicProcessController.getActiveProcessSteps('   ', 'East', 50000);
        Test.stopTest();

        // Then
        Assert.isNotNull(results, 'Result must not be null when objectApiName is blank');
        Assert.areEqual(0, results.size(),
            'Empty list expected when objectApiName is blank');
    }

    @IsTest
    static void shouldReturnEmptyList_WhenObjectApiNameIsEmptyString() {
        // Given / When
        Test.startTest();
        List<BedrockDynamicProcessController.ProcessStepDTO> results =
            BedrockDynamicProcessController.getActiveProcessSteps('', 'East', 50000);
        Test.stopTest();

        // Then
        Assert.isNotNull(results, 'Result must not be null when objectApiName is empty string');
        Assert.areEqual(0, results.size(),
            'Empty list expected when objectApiName is empty string');
    }

    // =========================================================================
    // Unknown object — no metadata rows exist, must return empty not throw
    // =========================================================================

    @IsTest
    static void shouldReturnEmptyList_WhenNoStepsExistForObject() {
        // Given / When
        Test.startTest();
        List<BedrockDynamicProcessController.ProcessStepDTO> results =
            BedrockDynamicProcessController.getActiveProcessSteps(
                'Bedrock__Unknown__XYZ', 'East', 10000
            );
        Test.stopTest();

        // Then
        Assert.isNotNull(results, 'Result must not be null for an unknown object');
        Assert.areEqual(0, results.size(),
            'Unknown object should produce zero results');
    }

    // =========================================================================
    // Contract: non-null ordered list returned for a known object
    // =========================================================================

    @IsTest
    static void shouldReturnNonNullList_WhenObjectApiNameIsOpportunity() {
        // Given / When
        Test.startTest();
        List<BedrockDynamicProcessController.ProcessStepDTO> results =
            BedrockDynamicProcessController.getActiveProcessSteps(
                'Opportunity', null, null
            );
        Test.stopTest();

        // Then
        Assert.isNotNull(results, 'Result list must not be null for Opportunity');
    }

    @IsTest
    static void shouldReturnStepsInAscendingDisplayOrder_WhenOpportunity() {
        // Given / When
        Test.startTest();
        List<BedrockDynamicProcessController.ProcessStepDTO> results =
            BedrockDynamicProcessController.getActiveProcessSteps(
                'Opportunity', null, null
            );
        Test.stopTest();

        // Then — verify ascending order on whatever rows are deployed
        if (results.size() < 2) return;
        for (Integer i = 1; i < results.size(); i++) {
            Assert.isTrue(
                results[i].displayOrder >= results[i - 1].displayOrder,
                'Steps must be returned in ascending Display Order'
            );
        }
    }

    // =========================================================================
    // DTO shape — required fields must be present on every returned row
    // =========================================================================

    @IsTest
    static void shouldReturnDtoWithRequiredFields_WhenStepsExist() {
        // Given / When
        Test.startTest();
        List<BedrockDynamicProcessController.ProcessStepDTO> results =
            BedrockDynamicProcessController.getActiveProcessSteps(
                'Opportunity', null, null
            );
        Test.stopTest();

        // Then
        if (results.isEmpty()) return;
        BedrockDynamicProcessController.ProcessStepDTO first = results[0];
        Assert.isNotNull(first.stepId,       'stepId must not be null');
        Assert.isNotNull(first.stepLabel,    'stepLabel must not be null');
        Assert.isNotNull(first.displayOrder, 'displayOrder must not be null');
    }

    // =========================================================================
    // Regional routing — APAC + Strategic + high amount should surface
    // criteria-specific rows (or at minimum return a non-null list)
    // =========================================================================

    @IsTest
    static void shouldReturnNonNullList_WhenApacStrategicHighAmount() {
        // Given
        String  region = 'APAC';
        Decimal amount = 1500000;

        // When
        Test.startTest();
        List<BedrockDynamicProcessController.ProcessStepDTO> results =
            BedrockDynamicProcessController.getActiveProcessSteps(
                'Opportunity', region, amount
            );
        Test.stopTest();

        // Then — criteria-specific rows should match if deployed; never null
        Assert.isNotNull(results,
            'Result must not be null for APAC Strategic high-value context');
    }

    @IsTest
    static void shouldReturnOrderedSteps_WhenApacStrategicHighAmount() {
        // Given
        String  region = 'APAC';
        Decimal amount = 1500000;

        // When
        Test.startTest();
        List<BedrockDynamicProcessController.ProcessStepDTO> results =
            BedrockDynamicProcessController.getActiveProcessSteps(
                'Opportunity', region, amount
            );
        Test.stopTest();

        // Then
        if (results.size() < 2) return;
        for (Integer i = 1; i < results.size(); i++) {
            Assert.isTrue(
                results[i].displayOrder >= results[i - 1].displayOrder,
                'APAC steps must be in ascending Display Order'
            );
        }
    }

    // =========================================================================
    // Null-safe: null region and null amount must not throw
    // =========================================================================

    @IsTest
    static void shouldNotThrow_WhenRegionAndAmountAreNull() {
        // Given / When
        Test.startTest();
        List<BedrockDynamicProcessController.ProcessStepDTO> results =
            BedrockDynamicProcessController.getActiveProcessSteps(
                'Opportunity', null, null
            );
        Test.stopTest();

        // Then
        Assert.isNotNull(results,
            'Null region and amount must not throw — wildcard rows should return');
    }
}
