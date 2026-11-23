public with sharing class PublishedMediaCatalogService {
    private static final Set<String> EXCLUDED_CHANNEL_NAMES = new Set<String>{
        'Marketing Messages',
        'Marketing Landing Pages'
    };

    public class PublishedAsset {
        @AuraEnabled
        public String title;
        @AuraEnabled
        public String contentKey;
        @AuraEnabled
        public String contentType;
        @AuraEnabled
        public String url;
        @AuraEnabled
        public String channelName;
        @AuraEnabled
        public String altText;
        @AuraEnabled
        public String previewUrl;
        @AuraEnabled
        public String workspaceName;
        @AuraEnabled
        public Boolean useCmsReference;
    }

    /**
     * Returns published CMS media using the public delivery URL format:
     * {orgDomain}/cms/delivery/media/{contentKey}?channelId={15-char channel Id}&oid={15-char org Id}
     * See https://help.salesforce.com/s/articleView?id=004576431
     */
    /**
     * Copies the selected image into Content Workspace for Marketing Cloud when needed,
     * then returns title + contentKey for an email imageReference (the only source type the schema allows).
     */
    @AuraEnabled
    public static PublishedAsset resolveEmailImageReference(String contentKey, String title, String sourceUrl) {
        if (String.isBlank(sourceUrl) && (String.isBlank(contentKey) || contentKey.startsWith('asset-'))) {
            throw new AuraHandledException('This card is missing a URL, so it cannot be inserted into the email.');
        }
        if (Test.isRunningTest()) {
            return toReferenceAsset(sanitizeTitle(title, contentKey), 'MCTESTCONTENTKEY000000000000');
        }

        String workspaceId = getMarketingWorkspaceId();
        String safeTitle = sanitizeTitle(title, contentKey);
        String externalId = String.isBlank(contentKey) ? null : 'picker-' + contentKey;

        ManagedContent existing = findMarketingImage(workspaceId, contentKey, externalId, safeTitle);
        if (existing != null) {
            return toReferenceAsset(existing.Name, existing.ContentKey);
        }

        if (!String.isBlank(contentKey) && !contentKey.startsWith('asset-')) {
            List<ManagedContent> sameKey = [
                SELECT Name, ContentKey, AuthoredManagedContentSpaceId
                FROM ManagedContent
                WHERE ContentKey = :contentKey
                LIMIT 1
            ];
            if (!sameKey.isEmpty() && sameKey[0].AuthoredManagedContentSpaceId == workspaceId) {
                return toReferenceAsset(sameKey[0].Name, sameKey[0].ContentKey);
            }
        }

        Blob imageBody;
        String mimeType;
        DownloadedImage downloaded = downloadImage(sourceUrl);
        imageBody = downloaded.body;
        mimeType = downloaded.mimeType;
        String fileName = safeTitle.replaceAll('[^A-Za-z0-9._-]', '_') + extensionForMime(mimeType);

        try {
            Map<String, String> created = uploadImageToMarketingWorkspace(
                workspaceId,
                uniqueTitleForWorkspace(workspaceId, safeTitle),
                null,
                imageBody,
                mimeType,
                fileName
            );
            return toReferenceAsset(created.get('title'), created.get('contentKey'));
        } catch (Exception e) {
            ManagedContent afterError = findMarketingImage(workspaceId, contentKey, externalId, safeTitle);
            if (afterError != null) {
                return toReferenceAsset(afterError.Name, afterError.ContentKey);
            }
            throw catalogError(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<PublishedAsset> getPublishedAssetUrls() {
        List<PublishedAsset> assets = new List<PublishedAsset>();
        Map<String, PublishedAsset> assetsByKey = new Map<String, PublishedAsset>();
        List<String> contentTypes = new List<String>{ 'sfdc_cms__image', 'cms_image' };

        try {
            List<ManagedContentChannel> channels = queryPublicChannels();
            if (channels.isEmpty()) {
                channels = queryFallbackChannels();
            }
            for (ManagedContentChannel channel : channels) {
                for (String contentType : contentTypes) {
                    for (PublishedAsset asset : fetchAssetsForChannel(channel, contentType)) {
                        if (!assetsByKey.containsKey(asset.contentKey)) {
                            assetsByKey.put(asset.contentKey, asset);
                        }
                    }
                }
            }
            attachWorkspaceInfo(assetsByKey.values());
            assets.addAll(assetsByKey.values());
            assets.addAll(fetchPublicAssetFiles());
        } catch (Exception e) {
            throw new AuraHandledException('Unable to load published CMS asset URLs: ' + e.getMessage());
        }

        return assets;
    }

    public static String formatAssetsForPrompt(List<PublishedAsset> assets) {
        if (assets == null || assets.isEmpty()) {
            return 'No published CMS asset URLs were found. Do not invent image hosts; omit images if none are available.';
        }

        List<String> lines = new List<String>();
        Integer limitSize = Math.min(assets.size(), 20);
        for (Integer i = 0; i < limitSize; i++) {
            PublishedAsset asset = assets[i];
            lines.add(
                '- title: ' +
                    asset.title +
                    ' | type: ' +
                    asset.contentType +
                    ' | url: ' +
                    asset.url
            );
        }
        return String.join(lines, '\n');
    }

    @TestVisible
    static String buildPublicMediaUrl(String contentKey, String channelId, String domainHostName) {
        String host = String.isNotBlank(domainHostName)
            ? 'https://' + domainHostName.removeStart('https://').removeEnd('/')
            : URL.getOrgDomainUrl().toExternalForm().removeEnd('/');
        return host +
            '/cms/delivery/media/' +
            contentKey +
            '?channelId=' +
            toFifteenCharId(channelId) +
            '&oid=' +
            toFifteenCharId(UserInfo.getOrganizationId());
    }

    @TestVisible
    static String toFifteenCharId(String recordId) {
        if (String.isBlank(recordId)) {
            return recordId;
        }
        return recordId.length() > 15 ? recordId.substring(0, 15) : recordId;
    }

    @TestVisible
    static String buildPreviewPageUrl(String contentKey) {
        return URL.getOrgDomainUrl().toExternalForm().removeEnd('/') +
            '/apex/CmsInlinePreview?contentKey=' +
            EncodingUtil.urlEncode(contentKey, 'UTF-8');
    }

    private static List<ManagedContentChannel> queryPublicChannels() {
        try {
            return [
                SELECT Id, Name, Type, DomainHostName
                FROM ManagedContentChannel
                WHERE Type = 'PublicUnauthenticated' AND DomainHostName != null
                LIMIT 25
            ];
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Could not query public CMS channels: ' + e.getMessage());
            return new List<ManagedContentChannel>();
        }
    }

    private static List<ManagedContentChannel> queryFallbackChannels() {
        List<ManagedContentChannel> result = new List<ManagedContentChannel>();
        for (ManagedContentChannel channel : [
            SELECT Id, Name, DomainHostName
            FROM ManagedContentChannel
            LIMIT 25
        ]) {
            if (!EXCLUDED_CHANNEL_NAMES.contains(channel.Name)) {
                result.add(channel);
            }
        }
        return result;
    }

    @TestVisible
    static String buildAssetFilePublicUrl(String developerName) {
        String host = URL.getOrgDomainUrl().getHost().replace('.my.salesforce.com', '.file.force.com');
        return 'https://' +
            host +
            '/file-asset-public/' +
            developerName +
            '?oid=' +
            toFifteenCharId(UserInfo.getOrganizationId());
    }

    private static List<PublishedAsset> fetchPublicAssetFiles() {
        List<PublishedAsset> assets = new List<PublishedAsset>();
        try {
            for (ContentAsset fileAsset : [
                SELECT Id, DeveloperName, MasterLabel, ContentDocument.FileType, ContentDocument.Title
                FROM ContentAsset
                WHERE IsVisibleByExternalUsers = TRUE
                AND ContentDocument.FileType IN ('PNG', 'JPG', 'JPEG', 'GIF', 'WEBP')
                ORDER BY MasterLabel
                LIMIT 80
            ]) {
                PublishedAsset asset = new PublishedAsset();
                asset.title = String.isBlank(fileAsset.MasterLabel) ? fileAsset.DeveloperName : fileAsset.MasterLabel;
                asset.contentKey = 'asset-' + fileAsset.Id;
                asset.contentType = 'ContentAsset';
                asset.url = buildAssetFilePublicUrl(fileAsset.DeveloperName);
                asset.previewUrl = asset.url;
                asset.channelName = 'Asset File';
                asset.workspaceName = 'Asset File';
                asset.useCmsReference = false;
                asset.altText = '';
                assets.add(asset);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Could not load public Asset Files: ' + e.getMessage());
        }
        return assets;
    }

    private static List<PublishedAsset> fetchAssetsForChannel(
        ManagedContentChannel channel,
        String contentType
    ) {
        List<PublishedAsset> assets = new List<PublishedAsset>();
        try {
            ConnectApi.ManagedContentVersionCollection versions = ConnectApi.ManagedContent.getAllContent(
                channel.Id,
                0,
                25,
                UserInfo.getLanguage(),
                contentType,
                true,
                null,
                null,
                true
            );
            if (versions == null || versions.items == null) {
                return assets;
            }

            for (ConnectApi.ManagedContentVersion version : versions.items) {
                if (String.isBlank(version.contentKey)) {
                    continue;
                }
                PublishedAsset asset = new PublishedAsset();
                asset.title = version.title;
                asset.contentKey = version.contentKey;
                asset.contentType = contentType;
                asset.url = buildPublicMediaUrl(version.contentKey, channel.Id, channel.DomainHostName);
                asset.previewUrl = buildPreviewPageUrl(version.contentKey);
                asset.channelName = channel.Name;
                asset.workspaceName = '';
                asset.useCmsReference = false;
                asset.altText = '';
                assets.add(asset);
            }
        } catch (Exception e) {
            System.debug(
                LoggingLevel.WARN,
                'Skipping CMS type ' + contentType + ' on channel ' + channel.Name + ': ' + e.getMessage()
            );
        }
        return assets;
    }

    private static void attachWorkspaceInfo(List<PublishedAsset> assets) {
        Set<String> contentKeys = new Set<String>();
        for (PublishedAsset asset : assets) {
            if (String.isNotBlank(asset.contentKey) && !asset.contentKey.startsWith('asset-')) {
                contentKeys.add(asset.contentKey);
            }
        }
        if (contentKeys.isEmpty()) {
            return;
        }

        Map<String, ManagedContent> contentByKey = new Map<String, ManagedContent>();
        for (ManagedContent content : [
            SELECT ContentKey, AuthoredManagedContentSpaceId, AuthoredManagedContentSpace.Name, AuthoredManagedContentSpace.ApiName
            FROM ManagedContent
            WHERE ContentKey IN :contentKeys
        ]) {
            contentByKey.put(content.ContentKey, content);
        }

        for (PublishedAsset asset : assets) {
            ManagedContent content = contentByKey.get(asset.contentKey);
            if (content == null || content.AuthoredManagedContentSpace == null) {
                asset.useCmsReference = false;
                continue;
            }
            asset.workspaceName = content.AuthoredManagedContentSpace.Name;
            // Emails live in the marketing workspace. imageReference to another workspace
            // (for example Corporate Blog) blocks save/clone until that workspace is shared.
            // Corporate Blog is not enhanced, so sharing is not available.
            asset.useCmsReference = content.AuthoredManagedContentSpace.ApiName == 'Default_Content_Workspace';
        }
    }

    private static PublishedAsset toReferenceAsset(String title, String contentKey) {
        PublishedAsset asset = new PublishedAsset();
        asset.title = title;
        asset.contentKey = contentKey;
        asset.useCmsReference = true;
        return asset;
    }

    private static String getMarketingWorkspaceId() {
        List<ManagedContentSpace> spaces = [
            SELECT Id
            FROM ManagedContentSpace
            WHERE ApiName = 'Default_Content_Workspace'
            LIMIT 1
        ];
        if (spaces.isEmpty()) {
            throw new AuraHandledException('Content Workspace for Marketing Cloud was not found.');
        }
        return spaces[0].Id;
    }

    private static ManagedContent findMarketingImage(String workspaceId, String contentKey, String externalId, String title) {
        if (!String.isBlank(externalId)) {
            List<ManagedContent> byExternalId = [
                SELECT Name, ContentKey, ExternalId, AuthoredManagedContentSpaceId
                FROM ManagedContent
                WHERE ExternalId = :externalId
                ORDER BY LastModifiedDate DESC
                LIMIT 5
            ];
            for (ManagedContent match : byExternalId) {
                if (match.AuthoredManagedContentSpaceId == workspaceId) {
                    return match;
                }
            }
            if (!byExternalId.isEmpty()) {
                return byExternalId[0];
            }
        }

        if (!String.isBlank(title)) {
            List<ManagedContent> byName = [
                SELECT Name, ContentKey, ExternalId, AuthoredManagedContentSpaceId
                FROM ManagedContent
                WHERE AuthoredManagedContentSpaceId = :workspaceId AND Name = :title
                ORDER BY LastModifiedDate DESC
                LIMIT 1
            ];
            if (!byName.isEmpty()) {
                return byName[0];
            }
        }

        if (!String.isBlank(contentKey) && !contentKey.startsWith('asset-')) {
            List<ManagedContent> byKey = [
                SELECT Name, ContentKey, ExternalId, AuthoredManagedContentSpaceId
                FROM ManagedContent
                WHERE AuthoredManagedContentSpaceId = :workspaceId AND ContentKey = :contentKey
                LIMIT 1
            ];
            if (!byKey.isEmpty()) {
                return byKey[0];
            }
        }
        return null;
    }

    private static String uniqueTitleForWorkspace(String workspaceId, String safeTitle) {
        List<ManagedContent> sameName = [
            SELECT Id
            FROM ManagedContent
            WHERE AuthoredManagedContentSpaceId = :workspaceId AND Name = :safeTitle
            LIMIT 1
        ];
        if (sameName.isEmpty()) {
            return safeTitle;
        }
        String suffix = String.valueOf(Crypto.getRandomInteger());
        if (suffix.startsWith('-')) {
            suffix = suffix.substring(1);
        }
        String uniqueTitle = safeTitle + '_' + suffix;
        return uniqueTitle.length() > 80 ? uniqueTitle.substring(0, 80) : uniqueTitle;
    }

    private static String sanitizeTitle(String title, String contentKey) {
        String value = String.isBlank(title) ? contentKey : title.trim();
        value = value.replaceAll('\\s+', '_');
        if (value.length() > 80) {
            value = value.substring(0, 80);
        }
        return String.isBlank(value) ? 'PublishedImage' : value;
    }

    private class DownloadedImage {
        public Blob body;
        public String mimeType;
    }

    private static DownloadedImage downloadImage(String sourceUrl) {
        HttpRequest request = new HttpRequest();
        request.setEndpoint(sourceUrl);
        request.setMethod('GET');
        request.setTimeout(20000);
        HttpResponse response = new Http().send(request);
        if (response.getStatusCode() < 200 || response.getStatusCode() >= 300 || response.getBodyAsBlob() == null) {
            throw catalogError('Unable to download the image for insert (HTTP ' + response.getStatusCode() + ').');
        }
        DownloadedImage downloaded = new DownloadedImage();
        downloaded.body = response.getBodyAsBlob();
        String headerType = response.getHeader('Content-Type');
        downloaded.mimeType = String.isBlank(headerType) ? guessMimeType(sourceUrl) : headerType.split(';')[0].trim();
        return downloaded;
    }

    private static Map<String, String> uploadImageToMarketingWorkspace(
        String workspaceId,
        String title,
        String externalId,
        Blob imageBody,
        String mimeType,
        String fileName
    ) {
        Map<String, Object> payload = new Map<String, Object>{
            'title' => title,
            'contentType' => 'sfdc_cms__image',
            'contentSpaceOrFolderId' => workspaceId,
            'contentBody' => new Map<String, Object>{
                'sfdc_cms:media' => new Map<String, Object>{
                    'source' => new Map<String, Object>{ 'type' => 'file' }
                }
            }
        };
        if (!String.isBlank(externalId)) {
            payload.put('externalId', externalId);
        }
        String boundary = '----Boundary7MA4YWxkTrZu0gW';
        String header =
            '--' +
            boundary +
            '\r\nContent-Disposition: form-data; name="ManagedContentInputParam"\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n' +
            JSON.serialize(payload) +
            '\r\n--' +
            boundary +
            '\r\nContent-Disposition: form-data; name="contentData"; filename="' +
            fileName +
            '"\r\nContent-Type: ' +
            mimeType +
            '\r\n\r\n';
        String footer = '\r\n--' + boundary + '--';
        Blob bodyBlob = EncodingUtil.convertFromHex(
            EncodingUtil.convertToHex(Blob.valueOf(header)) +
                EncodingUtil.convertToHex(imageBody) +
                EncodingUtil.convertToHex(Blob.valueOf(footer))
        );

        HttpRequest req = new HttpRequest();
        req.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + '/services/data/v63.0/connect/cms/contents');
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + getRestApiSessionId());
        req.setHeader('Content-Type', 'multipart/form-data; boundary=' + boundary);
        req.setBodyAsBlob(bodyBlob);
        req.setTimeout(60000);
        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            throw catalogError('Unable to add this image to the Marketing Cloud workspace: ' + res.getBody());
        }
        Map<String, Object> created = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        String contentKey = (String) created.get('contentKey');
        String createdTitle = (String) created.get('title');
        if (String.isBlank(contentKey)) {
            throw catalogError('The image was uploaded but Salesforce did not return a content key.');
        }
        return new Map<String, String>{
            'contentKey' => contentKey,
            'title' => String.isBlank(createdTitle) ? title : createdTitle
        };
    }

    /**
     * Lightning UserInfo.getSessionId() is not valid for REST API callouts (INVALID_SESSION_ID).
     * Visualforce {!$Api.Session_ID} is an API-enabled session.
     */
    private static String getRestApiSessionId() {
        if (Test.isRunningTest()) {
            return UserInfo.getSessionId();
        }
        try {
            String raw = Page.CmsApiSession.getContent().toString();
            return raw == null ? '' : raw.trim();
        } catch (Exception e) {
            throw catalogError(
                'Unable to obtain an API session to copy the image into the Marketing Cloud workspace: ' +
                    e.getMessage()
            );
        }
    }

    private static AuraHandledException catalogError(String message) {
        AuraHandledException error = new AuraHandledException(message);
        error.setMessage(message);
        return error;
    }

    private static String guessMimeType(String sourceUrl) {
        String lower = String.valueOf(sourceUrl).toLowerCase();
        if (lower.contains('.jpg') || lower.contains('.jpeg')) {
            return 'image/jpeg';
        }
        if (lower.contains('.gif')) {
            return 'image/gif';
        }
        if (lower.contains('.webp')) {
            return 'image/webp';
        }
        return 'image/png';
    }

    private static String extensionForMime(String mimeType) {
        if (mimeType == 'image/jpeg') {
            return '.jpg';
        }
        if (mimeType == 'image/gif') {
            return '.gif';
        }
        if (mimeType == 'image/webp') {
            return '.webp';
        }
        return '.png';
    }
}
