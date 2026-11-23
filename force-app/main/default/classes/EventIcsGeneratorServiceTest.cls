@IsTest
private class EventIcsGeneratorServiceTest {
    @IsTest
    static void toDateTime_parsesIsoAndBlank() {
        System.assertEquals(null, EventIcsGeneratorService.toDateTime(null));
        System.assertEquals(null, EventIcsGeneratorService.toDateTime('  '));
        Datetime parsed = EventIcsGeneratorService.toDateTime('2026-09-22T15:00:00Z');
        System.assertNotEquals(null, parsed);
    }

    @IsTest
    static void generateEventIcsUrls_skipsBlankSessions() {
        EventIcsGeneratorService.FlowInput inputRow = new EventIcsGeneratorService.FlowInput();
        inputRow.subject = 'Only session 1';
        inputRow.webinarSession1StartDate = '2026-09-22 15:00:00';
        inputRow.webinarSession1EndDate = '2026-09-22 16:00:00';
        Test.startTest();
        List<EventIcsGeneratorService.FlowOutput> outputs = EventIcsGeneratorService.generateEventIcsUrls(
            new List<EventIcsGeneratorService.FlowInput>{ inputRow }
        );
        Test.stopTest();
        System.assertEquals(1, outputs.size());
        System.assertNotEquals(null, outputs[0].ICSFileDownloadURL1);
        System.assertEquals(null, outputs[0].ICSFileDownloadURL2);
    }
}
