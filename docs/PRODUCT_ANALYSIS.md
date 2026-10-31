# Contact Photos: making it more marketable

_2026-10-31. App Store v1.0.5 (Oct 23), Utilities, 0 ratings, lifetime IAP `contact_photos_lifetime`._

## Where it stands
The job today is: search a company → pick its logo → save a contact, so texts
from that company show a logo instead of a gray circle. It does that well.
The problem is that **people don't wake up wanting contact photos**. They wake up
annoyed or worried by texts from numbers they don't recognize. The product
and the listing should start from that worry.

### Quick wins (days, not weeks)
1. **The App Store description is one sentence.** It's the biggest conversion leak and an easy fix. A draft is below.
2. **No ratings.** Add `in_app_review` after the 2nd contact created; that's the happy moment.
3. **Keywords.** Nobody searches "contact photos". They search *who is texting me*, *unknown number*, *caller id*, *spam text*, *short code lookup*, *business contacts*, *logo*. Use them in the subtitle and keywords.
4. **App Check deadline (Nov 2).** v1.0.5 shipped with App Check. Confirm in Firebase console → App Check that AI Logic requests show as **verified** for both platforms, before enforcement starts.

---

## Your three questions

### 1. "Can we get the phone number of whoever's texting or calling?"
**Not directly on iPhone.** iOS gives no app access to Messages or the call
history. There are three sanctioned routes, from easiest to hardest:

| Route | What it gives us | Effort |
|---|---|---|
| **Paste a number** (iOS 16+ paste button, no permission prompt) | The user long-presses the number in Messages → Copy → taps Paste in our app. We recognize it from our number database (see #2), and the logo and company are ready. Two taps. | Small. **Do first.** |
| **Call Directory extension** (CallKit, the same system Hiya and Truecaller use) | We give iOS a list of number → name, and **incoming calls from those numbers show the business name**, even without a contact. Names only, no photos. | Medium (Swift extension + App Group + a number list). |
| **Message Filter extension** (`ILMessageFilterExtension`) | iOS shows us the sender and text of messages **from unknown senders only**, so we can sort them into Junk / Transactions / Promotions. Apple tightly limits keeping that data. It's a filtering feature, not a way to capture numbers. | Medium. Good for the scam angle in #3. |

**On Android it's much more open.** Holding the **Call Screening role**
(`CallScreeningService`) means we see every incoming number without call-log
permission. We could offer "This was Chase — add their logo?" right after
the call. Reading SMS requires being the default SMS app, so that one's out.

### 2. "A database of numbers with commonly used images?"
**Yes, and it's the most valuable asset this app could build.** It's what turns
"search and pick a logo" into "it already knows".

- **Seed it:** the top ~100 brands that text people.
  - Banks' alert short codes, delivery (UPS/FedEx/USPS/Amazon), airlines, pharmacies, 2FA senders (Google, Microsoft, Apple), utilities, schools/district alert systems.
  - Each entry: number, company, website (for the logo), source URL proving it. Only use numbers the company publishes on its own site.
- **Grow it (opt-in, business numbers only):**
  - When a user creates a contact, offer "Help others recognize this number", sending only number + company + domain, never the user's info.
  - Only publish a mapping after **3+ independent users** agree, and never for normal 10-digit numbers unless confirmed as a business. That keeps personal numbers out.
- **Ship it as "Business Packs":** one tap adds a few contacts with logos at once: "My bank", "Deliveries", "Airlines".
  - This is a new, demoable, marketable feature, and it also feeds the Call Directory list.
- **Store:** Firestore `numbers/{e164}` → `{company, domain, logoUrl, verifiedBy: n, sources}`, read-only to the app, written by a Cloud Function that does the 3-vote rule.

### 3. "A validation API for numbers that text people?"
**Possible eventually, but as a business-to-business play it's crowded and needs scale first.**

- **Incumbents:**
  - Hiya, Truecaller, First Orion and TNS for caller ID;
  - Numeracle for branded calling;
  - carriers' own verified-sender programs: RCS verified business messaging, 10DLC brand registration through The Campaign Registry, Apple Business Connect for calls.
- **Where it'd come from:** a big, trusted number → brand map, which is #2. Without that, there's nothing to sell.

**The version that sells now is the consumer one: "Is this text real?"**
- Smishing is everywhere: fake toll notices, fake USPS redelivery, fake bank alerts.
- The user pastes the text (number + message). We check the number against the known-good list for the brand it claims to be, check the links against the brand's real domain, and ask the existing Gemini model for red flags.
- Then we show a verdict: ✅ "Matches Chase's real alert number" or ⚠️ "Chase doesn't text from this number, and the link isn't chase.com."
- This reuses everything already built (Firebase AI + App Check, company/domain matching), and the number DB makes it better over time.
- Months later, the same lookup becomes the API: `GET /v1/number/{e164}` → brand, confidence, last seen.

---

## Recommended plan

**Positioning:** *"Know who's texting you, and whether it's really them."*

1. **Week 1:** listing rewrite (below), review prompt, a **Paste number** button on the first screen, and a seeded DB of the top ~50 brands so a pasted number shows the logo instantly.
2. **Weeks 2–3:** **Is this text real?** (paste a message → verdict). This is the new headline feature for the listing and for TikTok/Reels ("I checked the toll scam text…").
3. **Weeks 3–4:** Business Packs + opt-in contributions + the 3-vote Cloud Function.
4. **Later:** Call Directory extension (iOS caller ID names), Android Call Screening, then consider a public lookup API once the DB has a few thousand confirmed numbers.

**Money:**
- Keep the lifetime unlock.
- Free: 3 contacts and 3 scam checks a month.
- Pro (lifetime $4.99–6.99, or $9.99/yr): unlimited, Business Packs, caller-ID names.
- Scam checking is the feature people will pay for monthly. Price it as a subscription once it exists.

---

## Listing draft

**Name (30):** `Contact Photos: Who's Texting` (29)
**Subtitle (30):** `Business Caller ID & Logos` (26)
**Keywords (100):** `unknown,number,text,spam,scam,sms,short,code,lookup,company,brand,logo,identify,picture,avatar,sender` (98)

**Description:**
> Stop guessing who texted you. Contact Photos turns mystery numbers from businesses into real contacts, with the company's logo, in seconds.
>
> - Search any company and we find its official logo
> - Save it as a contact: your bank, pharmacy, delivery service or school now shows up with its logo in Messages
> - Works for short codes (those 5- and 6-digit numbers) and regular numbers
> - Private by design: no account, nothing uploaded from your contacts
>
> Coming soon: paste a text to check whether it's really from who it claims.

**Screenshots:**
1. Before/after Messages list: gray circles → logos.
2. "Search any company".
3. "Pick the logo".
4. "Saved in seconds".
5. "No account. Private."
