public class IcsGeneratorService {
    public class IcsGeneratorException extends Exception {
    }

    /**
     * Creates an ICS file, saves it to Salesforce Files, and returns a public Content Distribution URL.
     */
    public static String createAndDistributeIcs(String subject, Datetime startDT, Datetime endDT, String description) {
        if (startDT == null) {
            throw new IcsGeneratorException('Start date is required to generate an ICS file.');
        }
        Datetime resolvedEnd = endDT == null
            ? Datetime.newInstanceGmt(startDT.dateGmt().addDays(1), Time.newInstance(0, 0, 0, 0))
            : endDT;

        String safeSubject = String.isBlank(subject) ? 'event' : subject.trim();
        String icsContent = generateIcsString(safeSubject, startDT, resolvedEnd, description);
        String fileBase = sanitizeFileName(safeSubject);

        ContentVersion cv = new ContentVersion();
        cv.Title = fileBase + '.ics';
        cv.PathOnClient = fileBase + '.ics';
        cv.VersionData = Blob.valueOf(icsContent);
        cv.IsMajorVersion = true;
        insert cv;

        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];

        ContentDistribution cd = new ContentDistribution();
        cd.Name = fileBase + ' Event Link';
        cd.ContentVersionId = cv.Id;
        cd.PreferencesAllowViewInBrowser = true;
        cd.PreferencesLinkLatestVersion = true;
        cd.PreferencesNotifyOnVisit = false;
        cd.PreferencesPasswordRequired = false;
        cd.ExpiryDate = null;
        insert cd;

        ContentDistribution generatedDist = [
            SELECT ContentDownloadUrl
            FROM ContentDistribution
            WHERE Id = :cd.Id
            LIMIT 1
        ];
        return generatedDist.ContentDownloadUrl;
    }

    @TestVisible
    static String generateIcsString(String subject, Datetime startDT, Datetime endDT, String description) {
        String startStr = startDT.formatGmt('yyyyMMdd\'T\'HHmmss\'Z\'');
        String endStr = endDT.formatGmt('yyyyMMdd\'T\'HHmmss\'Z\'');
        String safeDescription = description == null ? '' : description.replace('\n', '\\n');

        return 'BEGIN:VCALENDAR\n' +
            'VERSION:2.0\n' +
            'PRODID:-//Salesforce//NONSGML Event//EN\n' +
            'CALSCALE:GREGORIAN\n' +
            'METHOD:PUBLISH\n' +
            'BEGIN:VEVENT\n' +
            'UID:' + EncodingUtil.convertToHex(Crypto.generateAesKey(128)) + '@salesforce.com\n' +
            'DTSTAMP:' + Datetime.now().formatGmt('yyyyMMdd\'T\'HHmmss\'Z\'') + '\n' +
            'SUMMARY:' + escapeIcsText(subject) + '\n' +
            'DTSTART:' + startStr + '\n' +
            'DTEND:' + endStr + '\n' +
            'DESCRIPTION:' + escapeIcsText(safeDescription) + '\n' +
            'END:VEVENT\n' +
            'END:VCALENDAR';
    }

    private static String escapeIcsText(String value) {
        if (value == null) {
            return '';
        }
        return value.replace('\\', '\\\\').replace(';', '\\;').replace(',', '\\,');
    }

    private static String sanitizeFileName(String subject) {
        String fileBase = subject.replaceAll('[^A-Za-z0-9._-]', '_');
        if (String.isBlank(fileBase)) {
            fileBase = 'event';
        }
        return fileBase.length() > 80 ? fileBase.substring(0, 80) : fileBase;
    }
}
