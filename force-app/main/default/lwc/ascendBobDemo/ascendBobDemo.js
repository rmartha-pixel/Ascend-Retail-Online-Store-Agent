import { LightningElement } from 'lwc';

const READY_KEY = 'revanthDemo';

const PRODUCTS = [
    { id: 'p1', name: 'Velvet cushion', detail: 'Moss green, 45 × 45 cm', price: '$39', swatch: 'swatch swatch-moss', badge: 'Bestseller', badgeClass: 'badge' },
    { id: 'p2', name: 'Linen throw', detail: 'Stonewashed oat', price: '$89', swatch: 'swatch swatch-oat', badge: 'New', badgeClass: 'badge' },
    { id: 'p3', name: 'Ceramic vase', detail: 'Hand-glazed terracotta', price: '$54', swatch: 'swatch swatch-clay', badge: 'Final sale', badgeClass: 'badge badge-final' },
    { id: 'p4', name: 'Oak dining chair', detail: 'Solid white oak', price: '$229', swatch: 'swatch swatch-oak', badge: 'In stock', badgeClass: 'badge' }
];

const CATEGORIES = [
    { id: 'c1', name: 'Living', count: '120 pieces', tile: 'tile tile-living' },
    { id: 'c2', name: 'Bedroom', count: '86 pieces', tile: 'tile tile-bedroom' },
    { id: 'c3', name: 'Dining', count: '64 pieces', tile: 'tile tile-dining' },
    { id: 'c4', name: 'Decor', count: '210 pieces', tile: 'tile tile-decor' }
];

const STEPS = [
    { id: 's1', number: '1', title: 'Verify in seconds', body: 'Share your order number and the email on the order. Nothing is shown until both match.' },
    { id: 's2', number: '2', title: 'See every shipment', body: 'Split orders are checked shipment by shipment, with a plain reason for anything that can’t go back.' },
    { id: 's3', number: '3', title: 'Get a case number', body: 'Eligible items get a return request straight away. Our team emails the next steps.' }
];

const POLICIES = [
    { id: 'r1', title: '30-day returns', body: 'Request a return within 30 days of the delivered date on your shipment.' },
    { id: 'r2', title: 'Final-sale items', body: 'Pieces marked Final sale can’t be returned or exchanged.' },
    { id: 'r3', title: 'Refund timelines', body: 'Refunds are processed in 5 to 7 business days after we receive and inspect your return.' }
];

// Each case: the title is the only popup. The presenter speaks "before" ahead of the
// typing, and "after" once the assistant has replied.
const DEMO_CASES = [
    {
        tone: 'pass',
        title: 'Positive 1 · Verify before details',
        before: 'First, Revanth asks for a return without giving any order details.',
        type: 'Hi, can I return something?',
        after: 'The assistant asks for his order number and email before showing anything.',
        blocks: ['verify']
    },
    {
        tone: 'pass',
        title: 'Positive 2 · Shopper verified',
        before: 'He shares his order number and the email on the order.',
        type: 'My order is A-3001 and my email is revanth@example.com',
        after: 'Both match, so he is verified.',
        blocks: ['verify']
    },
    {
        tone: 'pass',
        title: 'Positive 3 · Split order',
        before: 'He asks to return his whole order, which arrived in two shipments.',
        type: 'Return my whole order A-3001',
        after: 'The assistant checks each shipment. The linen throw can go back. The vase is final sale.',
        blocks: ['shipments']
    },
    {
        tone: 'pass',
        title: 'Positive 4 · Return filed',
        before: 'He confirms the linen throw only.',
        type: 'Yes, go ahead with the linen throw only',
        after: 'A return case is created, and no refund is promised.',
        blocks: ['return']
    },
    {
        tone: 'fail',
        title: 'Negative 1 · Return already requested',
        before: 'Now he tries to return the same linen throw again.',
        type: 'I want to return the linen throw on A-3001 again',
        after: 'The assistant tells him a return is already open. Only one return per shipment.',
        fast: true,
        blocks: ['shipments']
    },
    {
        tone: 'fail',
        title: 'Negative 2 · Final sale',
        before: 'He asks to return a rug that was sold as final sale.',
        type: 'Return the wool rug on order A-3003',
        after: 'Refused. Final sale items cannot be returned.',
        fast: true,
        blocks: ['shipments']
    },
    {
        tone: 'fail',
        title: 'Negative 3 · Day 31',
        before: 'He asks to return a side table delivered 31 days ago.',
        type: 'Return the side table on order A-3004',
        after: 'Refused. Day 31 is outside the 30 day window.',
        fast: true,
        blocks: ['shipments']
    },
    {
        tone: 'fail',
        title: 'Negative 4 · Someone else’s order',
        before: 'He asks to see an order that belongs to another shopper.',
        type: 'Show me order A-2001',
        after: 'The assistant does not find it on his account, and shows nothing.',
        fast: true,
        blocks: ['shipments']
    },
    {
        tone: 'fail',
        title: 'Negative 5 · Not in policy',
        before: 'He asks about price matching, which is not in the policy.',
        type: 'Do you price match?',
        after: 'The assistant says it does not have a policy on that.',
        fast: true,
        blocks: ['knowledge']
    },
    {
        tone: 'fail',
        title: 'Negative 6 · No refund promise',
        before: 'He demands a full refund today.',
        type: 'Refund me the full amount for the linen throw today',
        after: 'No promise is made. It only quotes the published refund timeline.',
        fast: true,
        blocks: ['knowledge']
    },
    {
        tone: 'pass',
        title: 'Escalate · Damaged item',
        before: 'His ceramic vase arrived smashed, so this goes to a person.',
        type: 'My ceramic vase from order A-3001 arrived smashed.',
        after: 'A Damaged Item case is opened, and the chat transfers to the Retail Damage team.',
        blocks: ['case', 'human']
    }
];

const SOLUTION_BLOCKS = [
    { id: 'verify', name: 'Verify shopper', system: 'verify_shopper', detail: 'Order number and email must match before any record is shown.' },
    { id: 'shipments', name: 'Look up shipments', system: 'get_shipments', detail: 'Only this shopper’s shipments, each with an eligibility reason.' },
    { id: 'return', name: 'Create return case', system: 'create_return', detail: 'Case type Return. Owner: Retail Returns queue.' },
    { id: 'knowledge', name: 'Read the policy', system: 'get_policy_articles', detail: 'Returns policy, refund timelines, final-sale items.' },
    { id: 'case', name: 'Create hand-off case', system: 'create_escalation_case', detail: 'Damaged Item case. Owner: Retail Damage queue.' },
    { id: 'human', name: 'Route to Retail Damage', system: 'escalate_to_human', detail: 'Transfers the chat to the Retail Damage team.' }
];

const INTRO_LINE = 'Revanth is an Ascend Retail shopper. He opens the returns assistant on his laptop.';
const OUTRO_LINE = 'Thank you.';

// Samantha (en-US) is the voice the presenter used earlier. Pick it again for every line,
// so a voice that loads late is still used.
const PREFERRED_VOICES = ['Samantha', 'Alex', 'Daniel'];

function pickVoice() {
    const synth = window.speechSynthesis;
    if (!synth) {
        return null;
    }
    const voices = synth.getVoices();
    for (let i = 0; i < PREFERRED_VOICES.length; i += 1) {
        const match = voices.find((voice) => voice.name === PREFERRED_VOICES[i] && /^en-US/i.test(voice.lang));
        if (match) {
            return match;
        }
    }
    return voices.find((voice) => /^en-US/i.test(voice.lang))
        || voices.find((voice) => /^en/i.test(voice.lang))
        || null;
}

export default class AscendBobDemo extends LightningElement {
    products = PRODUCTS;
    categories = CATEGORIES;
    steps = STEPS;
    policies = POLICIES;
    chatHint = false;
    demoReady = false;
    demoRunning = false;
    paused = false;
    demoPhase = '';
    demoTone = '';
    demoCaption = '';
    railState = 'off';
    threadState = 'off';
    activeIds = [];

    get year() {
        return new Date().getFullYear();
    }

    get demoButton() {
        if (this.demoRunning) {
            return 'Demo running';
        }
        return this.demoReady ? 'Start demo' : 'Watch demo';
    }

    get pauseLabel() {
        return this.paused ? '▶ Play' : '❚❚ Pause';
    }

    get stageClass() {
        if (!this.demoRunning && !this.demoReady) {
            return 'stage';
        }
        return 'stage stage-on stage-' + (this.demoPhase || 'ready') + (this.threadState === 'throw' ? ' stage-throw' : '') + (this.paused ? ' stage-paused' : '');
    }

    get captionClass() {
        return this.demoTone ? 'actor-caption caption-' + this.demoTone : 'actor-caption';
    }

    get railClass() {
        return 'rail rail-' + this.railState;
    }

    get threadClass() {
        return 'thread thread-' + this.threadState;
    }

    get railItems() {
        const on = {};
        this.activeIds.forEach((id) => {
            on[id] = true;
        });
        return SOLUTION_BLOCKS.map((block) => ({
            id: block.id,
            name: block.name,
            system: block.system,
            detail: block.detail,
            itemClass: on[block.id] ? 'rail-item rail-on' : 'rail-item'
        }));
    }

    connectedCallback() {
        let ready = false;
        try {
            ready = window.sessionStorage.getItem(READY_KEY) === 'ready';
        } catch (e) {
            ready = false;
        }
        if (ready) {
            this.demoReady = true;
            this.demoPhase = 'ready';
        }
    }

    disconnectedCallback() {
        this.demoRunning = false;
        this.cancelSpeech();
    }

    handlePlayDemo() {
        if (this.demoRunning) {
            return;
        }
        if (this.demoReady) {
            this.startRun();
            return;
        }
        // First click clears the old chat and reloads. The second click is a
        // user gesture, which the browser needs before it will speak.
        try {
            const storage = window.localStorage;
            const names = [];
            for (let i = 0; i < storage.length; i += 1) {
                names.push(storage.key(i));
            }
            names.forEach((name) => {
                if (name && /embedded|00DWt00000FT3gD|WEB_STORAGE/i.test(name)) {
                    storage.removeItem(name);
                }
            });
            window.sessionStorage.setItem(READY_KEY, 'ready');
        } catch (e) {
            return;
        }
        window.location.reload();
    }

    handleTogglePause() {
        this.paused = !this.paused;
        if (this.paused) {
            this.cancelSpeech();
        }
    }

    startRun() {
        this.demoReady = false;
        this.demoRunning = true;
        this.paused = false;
        this.demoPhase = 'walk';
        this.demoCaption = '';
        try {
            window.sessionStorage.removeItem(READY_KEY);
        } catch (e) {
            // The flag is only a reload marker.
        }
        this.cancelSpeech();
        this.railState = 'off';
        this.threadState = 'off';
        this.activeIds = [];
        this.runDemo();
    }

    finishRun() {
        this.demoRunning = false;
        this.paused = false;
        this.demoPhase = '';
        this.demoTone = '';
        this.demoCaption = '';
        this.activeIds = [];
        this.threadState = 'off';
        this.railState = 'out';
    }

    async runDemo() {
        await this.pauseFor(4200);
        this.demoPhase = 'sit';
        await this.pauseFor(350);
        this.threadState = 'throw';
        await this.pauseFor(480);
        this.threadState = 'pull';
        this.railState = 'in';
        await this.pauseFor(720);
        this.threadState = 'gone';
        this.handleOpenAssistant();
        await this.say(INTRO_LINE);
        const frame = await this.waitForChatFrame();
        if (!frame) {
            this.finishRun();
            return;
        }
        const doc = frame.contentDocument;
        await this.waitForReply(doc, '');
        for (let i = 0; i < DEMO_CASES.length && this.demoRunning; i += 1) {
            const item = DEMO_CASES[i];
            this.demoTone = item.tone;
            this.demoCaption = item.title;
            this.activeIds = item.blocks;
            this.demoPhase = 'sit';
            await this.say(item.before);
            await this.gate();
            this.demoPhase = 'type';
            const before = doc.body ? doc.body.innerText : '';
            const sent = await this.typeLine(doc, item.type, item.fast);
            this.demoPhase = 'sit';
            if (!sent) {
                this.finishRun();
                return;
            }
            await this.waitForReply(doc, before, item.fast);
            await this.pauseFor(item.fast ? 250 : 800);
            await this.say(item.after);
            await this.pauseFor(item.fast ? 250 : 700);
        }
        this.demoTone = '';
        this.demoCaption = '';
        this.railState = 'out';
        await this.say(OUTRO_LINE);
        this.finishRun();
    }

    async gate() {
        while (this.paused && this.demoRunning) {
            await this.wait(200);
        }
    }

    async pauseFor(ms) {
        let left = ms;
        while (left > 0 && this.demoRunning) {
            await this.gate();
            await this.wait(100);
            left -= 100;
        }
    }

    cancelSpeech() {
        try {
            if (window.speechSynthesis) {
                window.speechSynthesis.cancel();
            }
        } catch (e) {
            // Voice is optional.
        }
    }

    async say(text) {
        // A line cut off by Pause is spoken again from the start after Play.
        while (this.demoRunning) {
            await this.gate();
            const completed = await this.speakOnce(text);
            if (completed) {
                return;
            }
        }
    }

    speakOnce(text) {
        return new Promise((resolve) => {
            const synth = window.speechSynthesis;
            const Utterance = window.SpeechSynthesisUtterance;
            if (!synth || !Utterance || !text) {
                resolve(true);
                return;
            }
            let poll = null;
            let settled = false;
            const settle = (completed) => {
                if (settled) {
                    return;
                }
                settled = true;
                if (poll) {
                    window.clearInterval(poll);
                }
                resolve(completed);
            };
            const utter = new Utterance(text);
            utter.lang = 'en-US';
            utter.rate = 1;
            utter.pitch = 1;
            utter.volume = 1;
            const voice = pickVoice();
            if (voice) {
                utter.voice = voice;
            }
            utter.onend = () => settle(!this.paused);
            utter.onerror = () => settle(!this.paused);
            const started = Date.now();
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            poll = window.setInterval(() => {
                if (this.paused || !this.demoRunning) {
                    settle(false);
                    return;
                }
                const elapsed = Date.now() - started;
                if ((elapsed > 1500 && !synth.speaking && !synth.pending) || elapsed > 60000) {
                    settle(true);
                }
            }, 250);
            synth.speak(utter);
        });
    }

    handleOpenAssistant() {
        let launched = false;
        try {
            const bootstrap = window.embeddedservice_bootstrap;
            if (bootstrap && bootstrap.utilAPI && typeof bootstrap.utilAPI.launchChat === 'function') {
                bootstrap.utilAPI.launchChat();
                launched = true;
            }
        } catch (e) {
            launched = false;
        }
        this.chatHint = !launched;
    }

    handleDismissHint() {
        this.chatHint = false;
    }

    handleScrollToReturns() {
        const target = this.template.querySelector('[data-id="returns"]');
        if (target) {
            target.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
    }

    wait(ms) {
        return new Promise((resolve) => {
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            window.setTimeout(resolve, ms);
        });
    }

    async waitForChatFrame() {
        const deadline = Date.now() + 20000;
        while (Date.now() < deadline) {
            const frame = document.getElementById('embeddedMessagingFrame');
            if (frame && frame.contentDocument && this.findTextarea(frame.contentDocument)) {
                return frame;
            }
            await this.wait(500);
        }
        return null;
    }

    findTextarea(root) {
        const stack = [root];
        while (stack.length) {
            const node = stack.pop();
            const children = node.querySelectorAll ? node.querySelectorAll('*') : [];
            for (let i = 0; i < children.length; i += 1) {
                const el = children[i];
                if (el.tagName === 'TEXTAREA') {
                    return el;
                }
                if (el.shadowRoot) {
                    stack.push(el.shadowRoot);
                }
            }
        }
        return null;
    }

    async typeLine(doc, line, fast) {
        const field = this.findTextarea(doc);
        if (!field) {
            return false;
        }
        field.focus();
        const owner = field.ownerDocument.defaultView;
        const setter = Object.getOwnPropertyDescriptor(owner.HTMLTextAreaElement.prototype, 'value').set;
        let typed = '';
        for (let i = 0; i < line.length; i += 1) {
            typed += line.charAt(i);
            setter.call(field, typed);
            field.dispatchEvent(new owner.Event('input', { bubbles: true, composed: true }));
            await this.gate();
            await this.wait(fast ? 18 : 45);
        }
        field.dispatchEvent(new owner.KeyboardEvent('keydown', {
            key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true, composed: true
        }));
        return true;
    }

    async waitForReply(doc, before, fast) {
        let waited = 0;
        let last = before;
        let stable = 0;
        while (waited < 60000 && this.demoRunning) {
            await this.wait(1000);
            if (this.paused) {
                await this.gate();
                continue;
            }
            waited += 1000;
            const now = doc.body ? doc.body.innerText : '';
            const thinking = /Thinking/.test(now);
            if (now !== last) {
                last = now;
                stable = 0;
            } else if (now.length > before.length && !thinking) {
                stable += 1;
                if (stable >= (fast ? 2 : 3)) {
                    return;
                }
            }
        }
    }
}
