# Add to Calendar ICS extension

CMS editor extension for Marketing Cloud Next emails. Architects enter an event title and start/end dates (date pickers or pasted field values). Apex builds an `.ics` file, publishes it with **Content Distribution**, and returns a public URL for **Add to calendar**.

## Classes

| Class | Role |
| --- | --- |
| `IcsGeneratorService` | Writes RFC 5545 ICS text, inserts `ContentVersion`, creates `ContentDistribution`, returns `ContentDownloadUrl`. |
| `EventIcsGeneratorService` | Invocable **Generate Event ICS URLs** used by on-demand Flow (up to 5 sessions). |
| `EmailIcsLinkService` | `@AuraEnabled` entry for the editor LWC. Pasted field values override the datetime pickers. |

The large `eventRegistrationConfirmation` payload mapper is not part of this extension. Keep using it in the original Flow/API project.

## LWC

`emailIcsGenerator` — target `lightning__CmsEditorExtension`, label **Add to Calendar**.

- **Generate ICS URL** — creates the file and shows the public link.
- **Copy URL** — clipboard.
- **Insert link** — writes `<a href="...">Add to calendar</a>` into the selected HTML/text block, or sets a button `href`. If nothing is selected, appends an HTML block on the canvas.

## How to use

1. Open an email in Content Builder and open the **Add to Calendar** extension.
2. Enter title (and optional description).
3. Set **Start** and **End**, or paste values from a record/field (`2026-09-22T15:00:00Z`).
4. Generate, then Copy URL into an existing button or Insert link.
5. In a received email, **Add to calendar** downloads the ICS and the mail/calendar client adds the event.

`eventRegistrationConfirmation` is not deployed here; the Flow can keep calling `EventIcsGeneratorService` the same way as before.
