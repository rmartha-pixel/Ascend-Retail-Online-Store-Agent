# Published CMS Media Extension

This document describes how the Marketing Cloud Next content builder extension loads published images, inserts them into email blocks, and copies a URL that can preview in a browser.

## Goal

Marketers working in the email canvas need to:

1. Browse published images.
2. Insert an image into the selected block (without a CMS title/caption).
3. Copy a link that **opens the image in a new tab** for preview.

Salesforce CMS **delivery/media** URLs are public on a public channel, but when opened **standalone** they typically download because Salesforce sends `Content-Disposition: attachment`. Asset Files with guest visibility use a servlet URL that browsers can preview inline.

## Architecture

```text
Content Builder (sfdc_cms__email)
        │
        ▼
LWC emailAIAssistant  (target: lightning__CmsEditorExtension)
        │
        ├── experience/cmsEditorApi     (read/write full email)
        ├── experience/blockBuilderApi  (replace selected block)
        └── Apex PublishedMediaCatalogService.getPublishedAssetUrls()
                    │
                    ├── Public CMS channels (Type = PublicUnauthenticated + CDN host)
                    └── ContentAsset files (IsVisibleByExternalUsers = true)
```

## Apex and page names

| Metadata | Purpose |
| --- | --- |
| `PublishedMediaCatalogService` | Catalog of published CMS images and public Asset Files; builds CDN and servlet URLs |
| `PublishedMediaCatalogServiceTest` | Unit tests for URL builders |
| `CmsInlinePreviewPageController` | Visualforce controller that resolves a CMS content key to a CDN URL |
| `CmsInlinePreview` | Visualforce page that **embeds** the CMS image in an `<img>` tag (authenticated Salesforce session) |
| `CmsInlineImageProxy` | Apex REST that fetches media and returns `Content-Disposition: inline` (session/API auth) |
| `CmsInlineImageProxyTest` | REST 404 coverage |
| `GeminiEmailBlockGenerator` | Optional Gemini callout that can inject catalog URLs into generated email JSON |
| `GeminiEmailBlockGeneratorTest` | Gemini mock tests |

The LWC bundle is still `emailAIAssistant` (CMS editor extension API name). The UI label is **Published CMS Assets**.

## URL types

### 1. CMS public delivery URL (embed, not standalone preview)

Format ([Help 004576431](https://help.salesforce.com/s/articleView?id=004576431)):

`https://{cdnHost}/cms/delivery/media/{contentKey}?channelId={15-char channel Id}&oid={15-char org Id}`

This org’s public channel CDN host is `storm-fcf826ff7f9f84.cdn.salesforce-experience.com`.

**Use for:** `<img src="...">` in email HTML or a web page.

**Do not expect:** opening this URL alone in a tab to *preview*. Salesforce usually **downloads** the file.

**Login:** Not required for a true public (`PublicUnauthenticated`) channel. Required if the channel is not public.

### 2. Asset File public servlet URL (standalone preview)

Format ([Summer ’25 file.force.com](https://salesforce.stackexchange.com/questions/433623/urls-of-publicly-visible-asset-files-changed-since-summer25)):

`https://{myDomain}.file.force.com/file-asset-public/{DeveloperName}?oid={15-char org Id}`

**Use for:** **Url** on cards labeled **Asset File**. Browsers typically **display** the image.

**Login:** Not required when **Let unauthenticated guest users see this asset** is enabled (`ContentAsset.IsVisibleByExternalUsers = true`). Incognito should work.

Setup: **Files → Asset Library → Upload Asset File** and enable guest visibility.

### 3. Visualforce inline preview (logged-in users)

`/apex/CmsInlinePreview?contentKey={contentKey}`

Renders `<img src="{cdnUrl}">` so a logged-in user can view CMS media without relying on attachment headers. **Incognito requires Salesforce login.**

## Extension behavior

| Action | Behavior |
| --- | --- |
- **Insert** copies the file into **Content Workspace for Marketing Cloud** when the image lives elsewhere (for example Corporate Blog), then writes the email schema’s required `imageInfo.source`: `{ "type": "imageReference", "ref": "<image name>" }` and `url: /cms/media/<ContentKey>`. A URL source is rejected by the Image block (`source.type` must be the constant `imageReference`).
| **Url** (Asset File) | Copies the `file-asset-public` URL and opens it in a new tab (`target=_blank`, no `download` attribute). |
| **Url** (CMS) | Copies/opens the Visualforce embed preview (session required). |

## Org prerequisites

- Default org: **MySDO_Rev**.
- Public CMS channel with `DomainHostName` set (do not use Marketing Messages / Marketing Landing Pages for public media URLs).
- Images published to that channel.
- For shareable preview links: Asset Files with guest visibility.
- Named credential **GeminiNC** only if you use `GeminiEmailBlockGenerator`.
- Remote site `CmsPublicCdn` for REST proxy callouts to the Experience CDN.
- Visualforce page `CmsApiSession` so Lightning can obtain an API-enabled session for CMS image upload (Lightning `UserInfo.getSessionId()` is rejected by the REST API).

## How to use

1. Open an email in Content Builder.
2. Open **Extensions → Published CMS Assets**.
3. Select an **Image** block on the canvas.
4. **Insert** a CMS or Asset File image (no title under the picture).
5. For a link that previews without login, click **Url** on an **Asset File** card and test it in incognito.

## References

- [Get a Public URL for Media in an Enhanced CMS Workspace](https://help.salesforce.com/s/articleView?id=004576431)
- [CMS editor extensions for Marketing Cloud Next](https://developer.salesforce.com/docs/platform/cms/guide/cms-extensions-build-marketing.html)
- [`experience/blockBuilderApi`](https://developer.salesforce.com/docs/platform/lwc/guide/reference-experience-block-builder-api.html)
