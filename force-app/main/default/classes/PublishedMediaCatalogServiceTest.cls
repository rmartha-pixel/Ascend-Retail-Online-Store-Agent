@IsTest
private class PublishedMediaCatalogServiceTest {
    @IsTest
    static void formatAssetsForPrompt_handlesEmptyAndPopulatedLists() {
        System.assertEquals(
            true,
            PublishedMediaCatalogService.formatAssetsForPrompt(new List<PublishedMediaCatalogService.PublishedAsset>())
                .contains('No published CMS asset URLs')
        );

        PublishedMediaCatalogService.PublishedAsset asset = new PublishedMediaCatalogService.PublishedAsset();
        asset.title = 'Hero';
        asset.contentType = 'sfdc_cms__image';
        asset.url = 'https://example.com/cms/delivery/media/abc';

        String prompt = PublishedMediaCatalogService.formatAssetsForPrompt(
            new List<PublishedMediaCatalogService.PublishedAsset>{ asset }
        );
        System.assert(prompt.contains(asset.url));
        System.assert(prompt.contains('Hero'));
    }

    @IsTest
    static void buildPublicMediaUrl_usesCdnHostWithoutFileExtension() {
        String channelId = '0apfI000000G4hhQAC';
        String contentKey = 'MCL3UQA5X2WVGXNKVOALZQHZRKLE';
        String url = PublishedMediaCatalogService.buildPublicMediaUrl(
            contentKey,
            channelId,
            'storm-fcf826ff7f9f84.cdn.salesforce-experience.com'
        );

        System.assert(url.startsWith('https://storm-fcf826ff7f9f84.cdn.salesforce-experience.com/cms/delivery/media/' + contentKey + '?'));
        System.assert(!url.contains('.png?'));
        System.assert(!url.contains('.jpg?'));
        System.assert(url.contains('channelId=0apfI000000G4hh'));
        System.assert(!url.contains('channelId=0apfI000000G4hhQAC'));
        System.assert(url.contains('oid=' + PublishedMediaCatalogService.toFifteenCharId(UserInfo.getOrganizationId())));
    }

    @IsTest
    static void resolveEmailImageReference_returnsTestStub() {
        PublishedMediaCatalogService.PublishedAsset resolved = PublishedMediaCatalogService.resolveEmailImageReference(
            'asset-test',
            'Hero',
            'https://example.com/hero.png'
        );
        System.assertEquals('Hero', resolved.title);
        System.assertEquals('MCTESTCONTENTKEY000000000000', resolved.contentKey);
        System.assertEquals(true, resolved.useCmsReference);
    }

    @IsTest
    static void buildAssetFilePublicUrl_usesFileForceHost() {
        String url = PublishedMediaCatalogService.buildAssetFilePublicUrl('SilverSpecialPackage');
        System.assert(url.contains('/file-asset-public/SilverSpecialPackage?oid='));
        System.assert(url.contains('.file.force.com'));
    }
}
