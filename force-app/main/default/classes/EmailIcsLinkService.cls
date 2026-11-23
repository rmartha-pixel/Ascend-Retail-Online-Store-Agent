public with sharing class EmailIcsLinkService {
    public class IcsLinkResult {
        @AuraEnabled
        public String url;
        @AuraEnabled
        public String subject;
        @AuraEnabled
        public String linkHtml;
    }

    /**
     * Generates a public ICS download URL from either datetime-picker values or pasted field values.
     * Prefer startFieldValue/endFieldValue when they are populated.
     */
    @AuraEnabled
    public static IcsLinkResult generateIcsDownloadUrl(
        String subject,
        String description,
        String startDateTime,
        String endDateTime,
        String startFieldValue,
        String endFieldValue
    ) {
        String startRaw = String.isNotBlank(startFieldValue) ? startFieldValue : startDateTime;
        String endRaw = String.isNotBlank(endFieldValue) ? endFieldValue : endDateTime;
        Datetime startDt = EventIcsGeneratorService.toDateTime(startRaw);
        if (startDt == null) {
            throw catalogError('Enter a start date, or paste a field value Salesforce can parse.');
        }
        Datetime endDt = EventIcsGeneratorService.toDateTime(endRaw);

        String safeSubject = String.isBlank(subject) ? 'Event' : subject.trim();
        String url = IcsGeneratorService.createAndDistributeIcs(safeSubject, startDt, endDt, description);

        IcsLinkResult result = new IcsLinkResult();
        result.url = url;
        result.subject = safeSubject;
        result.linkHtml =
            '<a href="' +
            url.replace('&', '&amp;').replace('"', '&quot;') +
            '">Add to calendar</a>';
        return result;
    }

    private static AuraHandledException catalogError(String message) {
        AuraHandledException error = new AuraHandledException(message);
        error.setMessage(message);
        return error;
    }
}
