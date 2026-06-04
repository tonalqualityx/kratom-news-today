# Editorial Rules

## Hard Constraints

These constraints are enforced by the rules-check agent. Violations are flagged for revision (or halt-and-report per options.md).

1. **Never make first-person product recommendations.** The publication does not recommend products, suppliers, vendors, retailers, or brands. This applies to all categories, including (and especially) Herba Releaf's own products.

2. **Never link editorial content to commercial pages.** Article bodies do not contain links to product pages, checkout pages, store pages, or any commercial purchase flow. This includes Herba Pumps' pages and all competitor commercial pages. Links to commercial pages appear only in clearly-marked ad slots, never in editorial.

3. **No em dashes.** Em dashes are banned outright in editorial content. Replace with commas, periods, parentheses, or colons depending on what the sentence needs. This is a hard rule.

4. **No contrast-pivot constructions.** Forbidden patterns: "not X, but Y" / "isn't merely X, it's Y" / "doesn't just X, it Y" / "not only X, but also Y" when used for rhetorical emphasis rather than literal additive meaning. These are LLM tells. Write declaratively instead.

5. **No unattributed expertise claims.** "Experts agree," "studies show," "research suggests," "scientists believe" without immediately naming the experts, studies, research, or scientists. Every authoritative claim is attributed to a specific source at the point of the claim.

6. **No vendor copy.** Words and phrases that signal marketing rather than journalism: "premium," "high-quality," "best-in-class," "responsibly sourced," "industry-leading," "innovative," "cutting-edge," "trusted by," and similar promotional language. These do not appear in editorial.

7. **No second-person hectoring.** Briefings are reports, not advice. Avoid "you should," "you can," "if you're considering," "you'd be forgiven for thinking." Direct address to the reader belongs in opinion content (when launched), not daily briefings.

8. **No predictions framed as facts.** "Will impact" is acceptable; "will devastate," "will destroy," "will save the industry" is editorializing. When a piece reports that someone predicts something, name who predicts it.

9. **No sensationalist headlines.** Headlines front-load the news without amplifying it. "FDA Recommends Schedule I Classification for 7-Hydroxymitragynine" is correct. "FDA Drops Bombshell on Kratom Industry" is not.

10. **No undisclosed publisher favoritism.** Herba Releaf is covered like any other company in the industry. Unfavorable news about Herba Releaf, if it arises, is reported. The publisher relationship is disclosed; the editorial relationship is independent.

## Required Framings

1. **Always lead with attribution on claims about regulation, science, or industry.** "According to [Source], ..." or "[Source] reported that ..." or "[Source] told [outlet] that ..." The framing makes clear that the publication is reporting what's being reported, not asserting what's true.

2. **Always attribute statistics to a specific source.** "A Nielsen report" or "Frontiers in Pharmacology data" rather than "data shows" or "research indicates."

3. **Always describe what is being reported, not what is true.** "A study found that participants showed reduced anxiety scores" — not "kratom reduces anxiety." This framing applies to all categories: science, regulation, business.

4. **Always provide a TL;DR via the `summary` frontmatter field.** 2-3 sentences. Standalone — readable without the rest of the article. The headline plus the TL;DR should give the reader the gist of the story. The site renders `summary` as a TL;DR callout at the top of the page automatically — do NOT add a TL;DR heading or `**TL;DR:**` line in the body, or it will render twice.

5. **Always end briefings with a Sources section.** Every primary source mentioned in the body appears in the Sources section with publisher, date, and URL. The Sources section is non-negotiable.

6. **Always front-load the news in headlines.** The most important fact comes first. Analysis frames, "what this means" framings, and editorial angles do not appear in headlines. Headlines describe what happened.

## Forbidden Link Targets

Editorial article bodies do NOT link to:

- herbapumps.com (any page)
- Any product pages on any company's domain (e.g., /shop, /products, /buy, /store, /cart)
- Any checkout or purchase flow
- Competitor commercial pages (MIT45, OPMS, Kratom Spot, etc. — same rule applies to all)
- Affiliate links, tracked promotional links, or any URL with affiliate parameters
- Direct-to-consumer pages of any kind

Editorial article bodies DO link to:

- Primary regulatory documents (fda.gov, dea.gov, state government sites, court filings)
- Peer-reviewed research (DOI links, journal pages)
- Reporting from established journalism outlets
- Trade press original reporting (NOT trade press marketing content)
- Industry advocacy organization announcements (when newsworthy)
- Press releases when they are the primary source for a development
- Other Kratom News Today briefings (internal links via slug references)

When in doubt: link to the original journalism that broke the story, not to any party's commercial interests.

## Compliance Considerations

This publication operates in a regulated category. The following compliance considerations apply throughout:

**BRAM awareness.** The publication's domain and email infrastructure are scanned by payment processor and platform automated systems. The publication's content is journalistic and structurally separate from any merchant operation, which materially reduces (but does not eliminate) BRAM exposure. Editorial framing — reporting on what is being reported rather than making first-person claims — also reduces the surface area. The forbidden link targets list above is part of this protection.

**Google News editorial standards.** The publication is structured for Google News inclusion: clear publisher disclosure, named editorial team, distinct editorial and commercial content, transparent corrections policy. Editorial content should be written to clear the Google News bar, which generally means: clear sourcing, accurate attribution, no clickbait headlines, no undisclosed commercial relationships in editorial.

**FTC considerations.** Any product, supplier, or industry claim that could be construed as commercial endorsement is editorially impermissible. The publisher relationship is disclosed in the masthead and footer; specific editorial coverage does not endorse, recommend, or promote.

**FDA-regulated categories.** Kratom is not currently approved as a drug. The publication does not refer to kratom as a treatment, therapy, or medicine for any condition. Reporting on what regulators, researchers, or clinicians have said about kratom's effects is allowed and properly framed; the publication making those claims itself is not.

## Violation Examples

These examples calibrate the rules-check agent. Each is a real-world pattern that could appear in a draft and how to correct it.

**Bad:** "Kratom advocates were furious, the FDA's decision was a devastating blow to the industry."
**Why:** Editorializing ("furious," "devastating blow") without attribution; no source.
**Correction:** "The American Kratom Association called the FDA's decision a serious setback for the industry."

**Bad:** "It's not just a regulatory issue, it's an existential one for many operators."
**Why:** Contrast-pivot pattern. LLM tell.
**Correction:** "Several operators told KNT the regulatory question is existential for their businesses."

**Bad:** "Studies show that kratom can be effective for managing chronic pain."
**Why:** Unattributed "studies show"; the publication making a medical claim; "effective for managing" is a treatment framing.
**Correction:** "A 2024 study published in Drug and Alcohol Dependence reported that survey respondents who used kratom for chronic pain self-reported reduced pain scores."

**Bad:** "Industry-leading manufacturer Herba Releaf released its new 7-OH alternative this week..."
**Why:** Vendor copy ("industry-leading"); publisher favoritism; product promotion in editorial.
**Correction:** "Herba Releaf, a Wyoming, Pennsylvania-based manufacturer, released a new product positioned as an alternative to 7-OH this week. The company described the product as containing no synthetic 7-hydroxymitragynine. Industry analysts cited by Marijuana Moment noted the launch comes amid growing regulatory pressure on concentrated 7-OH products."

**Bad:** "You should consider switching to compliant kratom suppliers before the Utah deadline."
**Why:** Second-person advice; predictive/instructional framing.
**Correction:** "Retailers in Utah have until Wednesday to bring inventory into compliance with the Kratom Regulation Act. Operators contacted by KNT said they were reviewing supplier relationships in advance of the deadline."

**Bad:** "The FDA dropped a bombshell decision on the kratom industry today, devastating the burgeoning sector."
**Why:** Sensationalist language ("dropped a bombshell," "devastating," "burgeoning sector"); editorializing without attribution.
**Correction:** "The FDA announced today that it will recommend Schedule I classification for synthetic 7-hydroxymitragynine preparations. Industry advocates and operators are still processing the announcement."

## Compliance Hard Constraints

*This section is enforced by a dedicated compliance-check agent that runs after the rules-check passes. Violations of these constraints typically trigger halt-and-report — human review before publish.*

### Medical claims

The publication may report that a study, researcher, regulator, doctor, or named source made a medical claim about kratom. The publication may not itself make a medical claim about kratom.

**Forbidden patterns:**
- Stating or implying that kratom treats, cures, prevents, alleviates, manages, helps with, or is effective for any medical condition
- Stating that kratom is safe, unsafe, harmful, or beneficial as a general matter
- Recommending that readers use or avoid kratom for any specific purpose
- Describing kratom in clinical terms (analgesic, anxiolytic, antidepressant, etc.) as a property of kratom itself
- Suggesting dosages, products, or methods of use
- Presenting clinical findings as established medical fact rather than as what researchers found

**Allowed patterns:**
- Attributed reporting on what researchers, studies, doctors, or regulators have said
- Describing what a study found, with the study named at the point of the claim
- Reporting that an advocacy organization or named expert recommends something (the recommendation is theirs, not the publication's)
- Coverage of regulatory positions on kratom's safety or efficacy, framed as the regulator's position

**Violation examples:**

- Bad: "Kratom can help with anxiety and depression."
  - Why: Medical claim in the publication's voice.
  - Correction: "A survey study published in Frontiers in Psychiatry reported that participants who used kratom for self-reported anxiety described moderate symptom reduction. The authors cautioned that self-report studies of this type cannot establish efficacy."

- Bad: "Kratom is generally safe when used responsibly."
  - Why: Safety claim in the publication's voice.
  - Correction: "The American Kratom Association maintains that kratom is safe for adults when used responsibly. The FDA has not approved kratom for any use and has issued warnings about adverse events associated with kratom products."

- Bad: "Researchers are increasingly recognizing kratom's potential as an analgesic alternative."
  - Why: "Recognizing" frames researcher activity as confirming a fact; "analgesic alternative" is clinical framing in the publication's voice.
  - Correction: "A 2024 review in Drug and Alcohol Dependence summarized current research on kratom's pharmacology, noting that mitragynine binds to mu-opioid receptors with a different profile than classical opioids. The authors called for additional clinical studies."

- Bad: "If you're considering kratom for pain management, you should consult your doctor."
  - Why: Direct advice to the reader, medical-context framing.
  - Correction: Remove. Briefings do not give medical advice or instructions, including the instruction to consult a doctor. If medical context is relevant, frame as what a named expert or organization has said: "The Mayo Clinic recommends that patients considering kratom discuss the decision with a physician familiar with the patient's medical history."

### Legal advice

The publication may report on laws, court rulings, regulatory actions, and what lawyers, regulators, or named sources said about the law. The publication may not itself give legal advice.

**Forbidden patterns:**
- Telling readers what they should or should not do under the law
- Making definitive statements about whether something is legal or illegal in a given jurisdiction without attribution to a specific statute, court ruling, or authoritative source, and never as advice
- Advising readers on compliance, licensing, registration, or any regulatory matter
- Suggesting that readers consult counsel or take any specific legal action
- Stating "the law requires" or "the law allows" without specific statutory or case-law attribution

**Allowed patterns:**
- Reporting on what attorneys, regulators, advocacy organizations, or other named sources said about the law
- Describing what a specific statute or court ruling says, with the statute or ruling cited
- Coverage of pending legislation, framed as proposed rather than effective
- Reporting on enforcement actions and their stated legal basis

**Violation examples:**

- Bad: "Kratom is legal in your state if you're over 21."
  - Why: Legal advice; jurisdictional claim without specific attribution; second-person direct address.
  - Correction: "Several state-level laws restrict kratom sales to adults 21 or older, including Utah, Tennessee, and Nevada. The American Kratom Association maintains a state-by-state legal status tracker. The federal legal status of kratom remains unchanged."

- Bad: "Retailers in Utah should switch suppliers before Wednesday."
  - Why: Legal advice / business advice to readers; directive framing.
  - Correction: "Utah's Kratom Regulation Act takes effect Wednesday. Retailers must source from manufacturers registered with the state, according to the Act's text. The Utah Department of Agriculture has published a registered manufacturer list."

- Bad: "Anyone facing BRAM enforcement should immediately review their merchant agreement."
  - Why: Direct advice to the reader.
  - Correction: "Attorneys representing kratom merchants in BRAM-related disputes have emphasized the importance of merchant agreement review, according to coverage in Payments Dive. Several have argued that current BRAM enforcement exceeds the scope of merchant agreements."

- Bad: "The bill will require all retailers to register with the state."
  - Why: "Will require" framed as fact for pending legislation that may not pass; missing attribution.
  - Correction: "The pending bill, as introduced, would require retailers to register with the state. The bill is currently in committee and has not passed either chamber."

## Additional Editorial Notes

The publication uses "kratom" without ornamentation as the standard term. "Mitragyna speciosa" is used when the botanical reference is the point. Specific alkaloids are named when relevant: mitragynine, 7-hydroxymitragynine (or 7-OH on subsequent mentions in a piece), mitraphylline, and others.

When covering 7-OH specifically, the publication distinguishes carefully between:
- 7-OH as it occurs naturally in kratom leaf (trace amounts)
- 7-OH as it appears in concentrated extracts (variable concentrations)
- Synthetic 7-OH preparations (higher concentrations, currently the regulatory focus)

These three are not the same thing, and conflating them produces inaccurate reporting. The synthesis agent should attend to which specific 7-OH context is at issue.

The publication uses the Oxford comma. Numbers under ten are spelled out; ten and above use numerals. Dates use "Month Day, Year" format. URLs are linked, not displayed inline.
