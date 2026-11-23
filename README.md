# Ascend Retail Online Store Agent

A Salesforce solution for **Ascend Retail**, an online home and lifestyle store. It combines an Agentforce returns assistant, Data Cloud data streams, an Experience Cloud storefront, and Marketing Cloud email helpers. The project is a Salesforce DX source repo.

## What's included

| Area | What it does | Where it lives |
| --- | --- | --- |
| **Returns agent** | `Ascend_Retail_Returns` Agentforce agent. Verifies the shopper, shows shipments, creates return requests, answers policy questions, and escalates to a human. | `force-app/main/default/aiAgents`, `aiAuthoringBundles/Ascend_Retail_Returns` |
| **Agent Apex actions** | Backs each agent action (verify, shipments, returns, policy, escalation). | `classes/RetailVerifyShopper`, `RetailGetShipments`, `RetailCreateReturn`, `RetailPolicyKnowledge`, `RetailEscalateCase`, `RetailReturnService` |
| **Returns data** | Custom `Shop_Order__c` object, `Case` fields, and the `Retail_Return_Setting__mdt` custom metadata (return window, default 30 days). | `objects/`, `customMetadata/` |
| **Flows** | Routes chats to the agent or to a team, and sends notifications from Data Cloud data streams. | `flows/Ascend_Retail_Route_to_Agent`, `Ascend_Retail_Escalate_to_Team`, `DataStream_RecordTriggered_Notification` |
| **Storefront** | Ascend Retail home page with a returns help area and a launcher for the assistant. Includes a demo page. | `lwc/ascendStorefront`, `lwc/ascendBobDemo`, `digitalExperiences/site/Ascend_Retail1`, `site/Ascend_Retail_Demo1` |
| **Messaging** | Embedded web chat for the storefront, connected to the agent. | `EmbeddedServiceConfig/`, `networks/`, `sites/` |
| **Data Cloud** | Data kit, data stream, and data model objects for behavioral events and individuals (`ssot__*`). | `dataPackageKitDefinitions/`, `dataStreamDefinitions/`, `dataKitObjectTemplates/`, `objects/ssot__*` |
| **Email helpers** | Lightning components for Marketing Cloud emails: AI assistant for published images, and an "Add to calendar" ICS link generator. | `lwc/emailAIAssistant`, `lwc/emailIcsGenerator`, `classes/CmsInline*`, `classes/*Ics*` |
| **Demo data and tests** | Seed data for demo shoppers, scripted agent conversations, and a Testing Center test set. | `scripts/apex/ascend_retail_seed.apex`, `scripts/agent_conversation.py`, `scripts/testing/` |
| **Docs** | Solution overview, data space deployment runbook, and feature notes. | `docs/` |

## How the returns agent works

1. **Verify.** The shopper gives an order number and the email on the order. Nothing is shown until verification succeeds.
2. **Status and returns.** The agent lists shipments for that shopper and checks each one against the return window. It can create a return request Case for an eligible shipment.
3. **Policy questions.** Answers come from published Returns policy articles. If the articles don't cover a question, the agent says so and offers the team.
4. **Escalate.** Damage, payment issues, and requests for a person go to the support team through the escalation flow.

Guardrails in the agent instructions: the agent never reveals other shoppers' orders, never issues refunds, never shows internal IDs or the full email address, and ignores text that claims to be a system message or a manager override.

## Prerequisites

- Salesforce CLI (`sf`) installed and authenticated to a target org with Agentforce, Data Cloud, Experience Cloud, and Marketing Cloud Next enabled.
- Node.js 18 or later, for the lint and test tooling.
- Your org must have the `Ascend_Retail1` Experience Cloud site (in `force-app/main/default/digitalExperiences/site/`) and Agentforce features licensed.

## Setup

```bash
# 1. Clone the repo
git clone https://github.com/rmartha-pixel/Ascend-Retail-Online-Store-Agent.git
cd Ascend-Retail-Online-Store-Agent

# 2. Install dev tooling (lint, Prettier, LWC Jest)
npm install

# 3. Log in to your org and set it as the default
sf org login web --alias ascend-dev --set-default
```

## Deploy

```bash
# Deploy the whole source tree to the default org
sf project deploy start --source-dir force-app --target-org ascend-dev
```

To deploy only the returns agent, add its metadata with `--metadata`, or deploy the `force-app` folder and then publish the agent from Agentforce Builder.

After deploying, load the demo data:

```bash
sf apex run --file scripts/apex/ascend_retail_seed.apex --target-org ascend-dev
```

The seed script is safe to re-run. It rebuilds the demo shoppers' shipments and return Cases, and sets delivery dates relative to today.

## Test the agent

Run the scripted conversations against the published agent. Each scenario starts a fresh session.

```bash
# All scenarios
python3 scripts/agent_conversation.py

# One scenario: demo, guardrails, rules, or another named scenario
python3 scripts/agent_conversation.py guardrails
```

The `scripts/testing/Ascend_Retail_Returns_TestingCenter.csv` file holds the expected utterances, subagents, actions, and responses for Agentforce Testing Center.

Run the Apex tests and LWC unit tests:

```bash
sf apex run test --test-level RunLocalTests --target-org ascend-dev
npm run test:unit
```

## Development

```bash
npm run lint              # ESLint for LWC and Aura
npm run prettier:verify   # Check formatting
npm run prettier          # Format files
```

Husky and lint-staged run Prettier and the LWC tests on commit.

## Repo layout

```
force-app/main/default/   Salesforce metadata (Apex, LWC, flows, objects, sites, agents, Data Cloud)
scripts/                  Seed data, agent test runner, Testing Center CSV
manifest/                 package.xml and destructive change manifests
config/                   Scratch org definition
docs/                     Solution docs, presentations, and feature notes
```

## Security notes

- Do not commit org credentials, access tokens, or the `.sf/` and `.sfdx/` local caches. They are in `.gitignore`.
- The org-specific IDs and the demo email addresses in the metadata come from a demo org. Replace them before using this repo in another org.
