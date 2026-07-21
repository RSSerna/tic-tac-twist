# 06 — Privacy Policy & Store Compliance

Two deliverables in this file:

1. **§1 — a draft privacy policy**, in publishable prose. Draft, not final: have
   it reviewed before it goes live, and re-verify against current App Store /
   Play Store / GDPR / COPPA policy at submission time (policy in this area
   changes often — see `03-PRODUCT.md` §1.1's same caveat).
2. **§2 — a data-collection mapping**, for filling out Apple's App Store
   privacy "nutrition label" and Google Play's Data Safety form. Both are
   console forms only the developer can submit; this is the checklist to
   work from, not a substitute for filling them out.

Both are grounded in what Phase 9 actually built — update this file if the
underlying data handling changes (a new SDK, a real crash/analytics backend
switched on, chests added, etc.).

---

## 1. Privacy Policy (draft)

> **Effective date:** [fill in before publishing]
> **App:** Nested (dev.rsaldarris.nested)
> **Developer:** Ricardo Saldarriaga Serna

### What this app is

Nested is an offline tic-tac-toe game. You can play locally against another
person on the same device, or against a computer opponent. No account, sign
up, or login is ever required or offered.

### Information we collect

**We do not collect your name, email address, or any other way to identify
you personally.** We do not assign you an advertising ID, and we never
combine anything below with an identity.

| Data | Collected? | Why | Linked to you? |
|---|---|---|---|
| Game settings (language, sound, turn timer) | Yes, stored only on your device | Remember your preferences | No — never leaves your device |
| Local win/loss/draw stats | Yes, stored only on your device | Show your stats screen | No — never leaves your device |
| Age range (child / not child) | Yes, stored only on your device | Required by app store policy to configure ads appropriately | No — a yes/no flag, not your birth date, and never leaves your device |
| Crash reports | Only if enabled | Fix bugs | No — no user ID is ever attached |
| Gameplay analytics (which mode, how a game ended, tutorial completion) | Only if enabled | Understand which parts of the game work well | No — aggregated, no user ID, no per-move data |
| Ad interaction data | Only if you're served ads | Ads are how the free version is funded | Handled by Google AdMob under its own policy — see below |
| Purchase records (remove-ads, skin packs) | Only if you buy something | Deliver your purchase | Handled by Apple/Google's payment platform — we never see your card details |

**We never collect:** your contacts, photos, location, microphone/camera,
browsing history, or anything you type outside this app.

### Third parties

- **Google AdMob** serves ads (if you haven't purchased remove-ads). Children
  and users of unknown age are only ever shown non-personalised ads. See
  [Google's Privacy Policy](https://policies.google.com/privacy).
- **Apple App Store / Google Play** process any purchase you make. We never
  see or store your payment details.
- **Crash reporting / analytics providers**: not finalised as of this draft
  (`CLAUDE.md`'s Phase 9 decisions record the two candidates under
  evaluation). This section must name the actual chosen provider(s) — and
  link their privacy policy — before publishing.

### Children's privacy

This app is directed at a general, mixed audience that includes children.
We comply with COPPA (US) and equivalent regulations elsewhere:

- We ask for an age range once, up front, before anything else — see the
  in-app age screen. This determines only whether ads are shown in
  non-personalised mode; nothing else in the app changes.
- We do not knowingly collect personal information from children.
- We do not request the advertising ID from children or from users who
  haven't answered the age screen.

### Your choices

- Sound effects, music, and the local turn timer can be turned off in
  Settings at any time.
- Crash reporting and analytics (once a backend is switched on) will have
  their own settings toggle — **not yet implemented**; note this policy
  needs to reflect that toggle's actual existence before publishing, or the
  toggle needs to ship before this app does.
- You can restore or manage purchases through your platform's App Store /
  Play Store account.
- Uninstalling the app deletes everything stored on your device.

### Contact

[developer contact email — fill in before publishing]

### Changes to this policy

We'll update the effective date above if this policy changes. Material
changes will be reflected in the app's store listing update notes.

---

## 2. Store data-collection mapping

Use this table when filling out Apple's App Privacy questionnaire (App Store
Connect → App Privacy) and Google Play's Data Safety form. Both ask
essentially the same questions in different shapes.

### Data types actually handled

| Data type | Collected | Linked to identity | Used for tracking (cross-app/site) | Purpose |
|---|---|---|---|---|
| Purchase history | Yes (if a purchase is made) | No (platform handles identity) | No | App functionality (unlock content) |
| Crash data | Yes, if a crash backend is enabled | No | No | App functionality / analytics (bug fixing) |
| Performance/diagnostics data | Yes, if a crash backend is enabled | No | No | Analytics |
| Product interaction (analytics events: game started/ended, tutorial) | Yes, if enabled | No | No | Analytics |
| Advertising data | Yes, if ads are shown and not removed | No (no ad ID from children/unknown-age users) | Depends on AdMob's own configuration — declare per AdMob's current guidance | Ads (third-party) |

### Data types this app does NOT collect

Contacts, precise or coarse location, photos/videos, audio recordings, health
data, financial info beyond purchase history (no card numbers ever seen by
the app), browsing history outside the app, search history, user-generated
content (there is none — no chat, no profiles, no usernames), device
contacts, or any persistent cross-app identifier.

### Apple App Store specifics

- **Data Not Linked to You**: crash data, performance data, product
  interaction — since none of it carries a user identifier.
- **Third-Party Advertising**: declare AdMob per its current disclosure
  requirements (check the AdMob/Google Mobile Ads SDK's own App Store
  privacy manifest guidance — it changes with SDK versions).
- Complete the **Privacy Nutrition Label** in App Store Connect under
  *App Privacy* using the table above. If no crash/analytics backend is live
  yet at submission time, omit those rows until one is enabled.

### Google Play specifics

- Complete the **Data Safety** form in Play Console using the same table.
- Declare whether data is *collected* vs. *shared* — for this app, purchase
  processing and ad serving are the only "shared with third party"
  categories (Apple/Google's payment platform, and Google AdMob
  respectively).
- Declare the **Families policy** requirements if targeting the "Designed
  for Families" program — this app currently targets **mixed audience**
  with a neutral age gate instead (see `03-PRODUCT.md` §1), which is a
  different compliance path than Families; don't conflate the two when
  filling out the form.

### Before submitting either form

1. Confirm which crash-reporting backend (Crashlytics or Sentry) is actually
   live, and update both this file and the privacy policy draft above to
   name it.
2. Confirm whether Firebase Analytics is live, since Firebase Crashlytics
   and Firebase Analytics are declared slightly differently on some forms.
3. Re-check AdMob's current SDK privacy manifest / data disclosure
   requirements — these are updated by Google periodically independent of
   this document.
