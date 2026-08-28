# -*- coding: utf-8 -*-
"""Interview question bank, built entirely from the supplied past-paper corpus.

Every question in QUESTIONS is verbatim (or near-verbatim, as recalled by the
candidate who wrote the paper up). Nothing is invented.

Themes carry the rubric. For reflective and personal questions the rubric scores
MOVES, not content -- specificity, ownership, behavioural change, tolerated
uncertainty -- because a bank of model answers to personal questions is exactly
the canned-answer failure mode these panels are built to detect.
"""
import json, os

THEMES = {}
def theme(id, label, why, listen, followups, failure, shape, concepts, mode="3min"):
    THEMES[id] = dict(id=id, label=label, why=why, mode=mode, concepts=concepts,
                      listen=[{"text": t, "cues": c, "tier": k} for t, c, k in listen],
                      followups=followups, failure=failure, shape=shape)

# ------------------------------------------------------------------ RESEARCH
theme("research_own", "Your own research", 
  "The single most frequent question in the entire corpus — it appears at Cardiff, Birmingham, Coventry, "
  "Glasgow, Exeter, Plymouth and Southampton, in every year sampled. Several courses ask you to present it "
  "for 5–10 minutes before questioning. Assume you will be asked this everywhere, and that the follow-ups "
  "are where the marks are.",
  [("States the research QUESTION in one sentence — not the topic area", [r"question was|aimed to (test|examine|establish)|asked whether|investigated whether"], "core"),
   ("Gives the rationale: what gap or clinical problem made it worth doing", [r"gap|nobody had|little (research|evidence)|because|clinical(ly)? (problem|relevant)|mattered"], "core"),
   ("Names the design precisely AND says why that design followed from the question", [r"design", r"because|so that|in order to|which allowed"], "core"),
   ("Sample: who, how recruited, how many — and what that implies for the claim", [r"particip|sample|recruit|\bn ?= ?\d"], "core"),
   ("Measures: what they were and why those ones (psychometrics, not convenience)", [r"measure|questionnaire|scale|interview schedule", r"chose|because|validated|reliab"], "core"),
   ("Analysis named with a reason, not just a label", [r"(t.?test|anova|regression|chi|thematic|ipa|correlat|mixed model)", r"because|since|as the|appropriate"], "core"),
   ("Findings given with direction and magnitude — not only 'it was significant'", [r"(increas|decreas|higher|lower|larger|smaller|effect size|\bd ?=|mean)"], "core"),
   ("Limitations SPECIFIC to this study, not a generic list", [r"limitation|weakness|caveat"], "core"),
   ("What you would do differently, with the reason — and ideally how you would operationalise it", [r"differently|next time|would have|in hindsight|would change"], "core"),
   ("Theory: what underpinned it, or what it implies theoretically", [r"theor|model|framework|conceptual"], "advanced"),
   ("A reflexive layer: what it taught you about being a researcher, or about being a scientist-practitioner in the NHS", [r"learn|taught me|realis|scientist.?practitioner|reflect"], "advanced"),
   ("Connects to clinical practice or service context", [r"clinic|practice|service|patient|NHS"], "advanced")],
  ["What was your independent variable and your dependent variable?",
   "What statistics did you use, and why those?",
   "What would you have done if the assumptions of that test were not met?",
   "What were the theoretical implications of the findings?",
   "How would you extend this research?",
   "What would you do differently, and how would you operationalise that change?",
   "In what way would that have improved the research?",
   "Remind me — when in your career did you complete this?",
   "What was the biggest threat to the validity of your conclusions?"],
  "Narrating the project chronologically — 'so first we recruited, then we ran it, then we analysed' — and "
  "running out of time before reaching limitations or reflection. The panel already assumes you can describe "
  "what you did; they are testing whether you can evaluate it.",
  "Question → why it mattered → design and why → sample → measures → analysis → what you found (with direction and "
  "size) → what it genuinely supports → what it does not → what you would change and why. Aim to reach limitations "
  "inside 90 seconds, because that is where every follow-up lives. Have one sentence ready for 'what does this mean "
  "theoretically' — Exeter's service user panellist asked exactly that.",
  ["scientist_practitioner", "test_selection", "external_validity", "reflective_practice"])

theme("research_design", "Designing a study on the spot",
  "Every course in the corpus does this. Birmingham gave a written version (evaluating CBT for CYP anxiety), "
  "Cardiff asked about rising young male suicide in rural areas, Glasgow gave a substance-use vignette, "
  "Exeter asked about parental intervention and child anxiety, Coventry asked for a systematic review method, "
  "Plymouth gave two vignettes under exam conditions. The content varies; the reasoning chain does not.",
  [("Clarifies or states the question before proposing a method", [r"(first|start|begin)[\s\S]{0,80}(question|clarify|what (we|I) (want|are) (to )?(know|answer))|depends (on )?what"], "core"),
   ("Says who they would consult first — service users, clinicians, the team, existing data", [r"consult|involve|talk to|ask|stakeholder|service user|co.?produc|patient and public"], "core"),
   ("Chooses qualitative or quantitative FROM the question rather than by preference", [r"(qualitative|quantitative|mixed)", r"because|since|as the question|depends|given that"], "core"),
   ("Names the design and its comparator", [r"(rct|randomis|cohort|cross.?sectional|longitudinal|case.?control|single.?case|feasibilit|survey|thematic|ipa|grounded)"], "core"),
   ("Specifies outcome measures and why", [r"(measure|outcome|instrument|scale)", r"validated|because|primary outcome"], "core"),
   ("Addresses sample and recruitment realistically, including who will be missed", [r"(recruit|sampl|access|hard to reach|who (we|I) (would )?miss|representat)"], "core"),
   ("Names ethical considerations specific to THIS question", [r"ethic|consent|capacity|distress|risk|safeguard|vulnerab"], "core"),
   ("Says what the design can and cannot establish", [r"(cannot|can't|would not|unable to) (say|establish|conclude|prove)|causal|only tells us"], "core"),
   ("Anticipates feasibility — time, funding, access, attrition", [r"feasib|realistic|resource|time|fund|attrition|drop"], "advanced"),
   ("Says how findings would be communicated and to whom", [r"disseminat|communicat|feed back|report|publish|share"], "advanced")],
  ["What sample size would you use, and how did you arrive at that?",
   "What are the ethical considerations?",
   "What are the limitations of that approach?",
   "How would you communicate your results?",
   "What if you already had your hypothesis — how would that change the design?",
   "What would you do if you could not recruit enough people?",
   "How would you know if it had been effective or ineffective?",
   "How would you ensure the study was worthwhile?"],
  "Naming a method in the first sentence. 'I'd do an RCT' before establishing what the question is, who cares "
  "about it, and whether the intervention is even ready to be trialled. The strongest candidates spend their "
  "first fifteen seconds on the question, not the method.",
  "Question → who I'd consult → what kind of knowledge this needs → design and comparator → outcome and measures "
  "→ sample and who gets missed → ethics specific to this → what it can and cannot show → how it gets used. "
  "Say 'it depends on what we want to know' and then say what it depends on — that is the answer, not a dodge.",
  ["test_selection", "rct", "qualitative_designs", "ethics_approval", "coproduction", "service_evaluation"])

theme("critical_appraisal", "Appraising a paper or abstract handed to you",
  "Coventry handed candidates an RCT abstract with 1–2 minutes to read; Birmingham circulated a journal article "
  "a month ahead and built the academic interview on it; Birmingham 2019 asked how you would establish the "
  "scientific merit of an RCT. Several courses ask about a paper that influenced you.",
  [("Works to a systematic order rather than hunting for flaws at random", [r"(first|start|begin|then|next|order|systematic|framework)"], "core"),
   ("Population and recruitment — who is in it, who is missing", [r"(sampl|particip|recruit|inclusion|exclusion|who was)"], "core"),
   ("Design and comparator — what was it compared against", [r"(comparator|control|tau|waitlist|active|placebo|compared (to|with))"], "core"),
   ("Measurement — are the outcomes valid, reliable, blind-assessed, and is the primary one pre-specified", [r"(measure|outcome|blind|reliab|valid|primary outcome|self.?report)"], "core"),
   ("Attrition and missing data", [r"(attrit|drop|lost to follow|missing|itt|intention.?to.?treat|completed)"], "core"),
   ("Analysis and effect — reports magnitude and precision, not only significance", [r"(effect size|confidence interval|\bci\b|magnitude|\bd ?=|how large)"], "core"),
   ("Generalisability — to whom does this actually apply", [r"generalis|generaliz|applic|transfer|represent|our (population|service)"], "core"),
   ("Lands on what the study genuinely allows us to conclude, rather than a list of faults", [r"(so (we|what)|therefore|allows us to|can conclude|bottom line|overall|on balance|genuinely)"], "core"),
   ("Says what would change the conclusion, or what the next study should do", [r"(would need|next step|to establish|would strengthen|would want)"], "advanced"),
   ("Notes something the study does well — appraisal is not prosecution", [r"(strength|well done|good|credit|to their credit|robust)"], "advanced")],
  ["What are the strengths of this study?",
   "What can you tell us about the effect size?",
   "Something about parametric versus non-parametric data…",
   "How would you measure the quality of the literature?",
   "How would you find out the scientific merit of an RCT for a psychological therapy?",
   "Would you change your practice on the basis of this?",
   "What would you need to see before you did?"],
  "Producing an unstructured list of complaints. Every candidate can say 'small sample, no control group'. "
  "The distinguishing move is landing on what the study DOES support, and saying what would settle the question.",
  "Population → recruitment → design → comparator → measurement → blinding → attrition → analysis → effect and "
  "precision → generalisability → conclusion. Then one sentence: 'so what this genuinely supports is X, and what "
  "it does not support is Y.' Say one thing the study does well before you list the problems.",
  ["risk_of_bias", "external_validity", "effect_size", "control_group", "attrition", "quality_appraisal"])

theme("systematic_review", "Designing a systematic review",
  "Coventry 2018 asked how you would conduct a systematic review of mindfulness-based interventions for anxiety, "
  "then how you would measure the quality of the literature. Glasgow's substance-use vignette also offered a "
  "review as one route.",
  [("Frames a specific answerable question, ideally with a structure such as PICO", [r"\bpico\b|population|intervention|comparator|outcome|specific question|answerable"], "core"),
   ("Protocol written and registered in advance (PROSPERO)", [r"protocol|prospero|register|pre.?specif|a priori"], "core"),
   ("Search strategy: databases, terms, grey literature, reference chaining", [r"(database|medline|psycinfo|embase|cochrane|search (term|strateg)|grey literature|hand search|reference)"], "core"),
   ("Explicit inclusion and exclusion criteria", [r"(inclusion|exclusion|eligib|criteria)"], "core"),
   ("Screening in duplicate with a process for disagreement", [r"(two|second|dual|independent|duplicate) (reviewer|rater|screen)|kappa|disagree|third reviewer"], "core"),
   ("Quality appraisal with a named tool", [r"(casp|cochrane|rob ?2|grade|jadad|quality (appraisal|assessment)|risk of bias)"], "core"),
   ("Synthesis: meta-analysis only if the studies are similar enough; otherwise narrative", [r"(meta.?analys|narrative synthesis|heterogen|i.?2|pool)"], "core"),
   ("Publication bias considered", [r"publication bias|funnel|file drawer|grey literature|unpublished"], "advanced"),
   ("PRISMA reporting and flow diagram", [r"prisma|flow (diagram|chart)"], "advanced")],
  ["How would you measure the quality of the literature?",
   "What would you do if the studies were too different to pool?",
   "How would you handle unpublished studies?",
   "What if you found only three studies?"],
  "Describing a thorough literature review and calling it systematic. The word 'systematic' means reproducible: "
  "another researcher following your protocol should reach the same set of papers.",
  "Question (PICO) → registered protocol → search across named databases plus grey literature → explicit criteria "
  "→ duplicate screening with disagreement process → quality appraisal with a named tool → synthesis appropriate "
  "to heterogeneity → publication bias → PRISMA. One sentence on why each step exists beats naming all nine.",
  ["systematic_review", "prisma", "quality_appraisal", "meta_analysis", "publication_bias"])

# ------------------------------------------------------------------ CLINICAL
theme("model_switch", "Formulating with a second, different model",
  "The highest-stakes question in the corpus, and the one candidates report being caught by. Birmingham 2019 "
  "asked candidates to name a model, and ONLY THEN told them the second part required formulating with a "
  "DIFFERENT one — 'this caught us all out'. Cardiff asks it in both 2012 and 2013. Plymouth and Southampton "
  "ask for the theory and its critiques. Your confirmed courses all use clinical vignettes, so assume it.",
  [("Names the second model precisely rather than gesturing at it", [r"(systemic|\bact\b|acceptance and commitment|\bdbt\b|dialectical|\bcft\b|compassion|psychodynamic|narrative|\bcat\b|ptmf|attachment)"], "core"),
   ("States the model's core explanatory principle before applying it", [r"(the (idea|principle|premise)|this model (says|holds|proposes)|works on the basis|central to)"], "core"),
   ("Applies it to THIS person's material, not in the abstract", [r"(for (him|her|them|this (person|client|man|woman))|in (his|her|their) case|specifically)"], "core"),
   ("Identifies a different maintaining mechanism from the one the first model named", [r"(maintain|keeps? (it|this) going|perpetuat|cycle|loop|function)"], "core"),
   ("Says what the second lens ILLUMINATES that the first missed", [r"(adds|illuminat|brings|reveals|makes visible|what (this|the systemic|the act) lens|highlights|foreground)"], "core"),
   ("Says what the second lens OVERLOOKS or risks losing", [r"(overlook|miss|lose|risk|limitation|downside|less good at|does not (capture|address))"], "core"),
   ("Derives an intervention that FOLLOWS from the formulation, not from preference", [r"(would follow|therefore|so the intervention|which suggests|leads to|because the formulation)"], "core"),
   ("Holds it as a hypothesis, and says how it would be shared and tested with the person", [r"(hypothes|share|collaborat|test|check (with|out)|together|wonder)"], "core"),
   ("Explicitly compares: same person, two accounts, and what governs the choice between them", [r"(whereas|by contrast|compared (to|with)|the difference|whereas the (cbt|first)|choosing between)"], "advanced")],
  ["Now formulate the same client using a different model.",
   "What does that model illuminate that the first one did not?",
   "What might it overlook?",
   "What intervention would follow from that formulation?",
   "What would make this formulation less plausible?",
   "What would you expect to see if your formulation were correct?",
   "Is there anything else that could have affected this work?",
   "What are the critiques of that theory?"],
  "Having only one model with any depth. Candidates give a fluent CBT formulation and then produce a thin "
  "systemic or psychodynamic gesture — 'I'd also think about the family' — with no mechanism. The second model "
  "must do explanatory work, not decorative work.",
  "Prepare ONE clinical case you can formulate genuinely from three angles: CBT, one relational/contextual model "
  "(systemic is the most examinable), and one third-wave model (ACT). For each: core principle → what maintains "
  "the problem on this account → what intervention follows → what this lens adds → what it loses. Then rehearse "
  "the Birmingham trap: give your best model first, assuming you will be required to abandon it.",
  ["formulation", "cbt_model", "systemic", "act", "circular_causality", "hypothesis_testing"])

theme("clinical_case", "A piece of clinical work you have done",
  "Asked at Southampton (2012, 2013, 2015), Plymouth 2013, Cardiff, Birmingham 2018. Usually followed by "
  "theory, then critiques of the theory, then what you would do differently. The TIPS document from a "
  "successful candidate is emphatic: know your formulation, and know how you built it WITH the client.",
  [("Sets the scene economically — who, setting, referral question, in two or three sentences", [r"(referred|referral|presented|working (in|with)|setting|service)"], "core"),
   ("States what YOU did, with your role and level of supervision clear", [r"(I |my role|under (the )?supervision|supervised by|I was)"], "core"),
   ("The formulation is described as shared and provisional — built WITH the person", [r"(shared|collaborat|together|we (developed|drew|built)|hypothesis|hypothesis(ed|ised)|with (him|her|them))"], "core"),
   ("The intervention follows from the hypothesised mechanism, not from the client's preference alone", [r"(because|followed from|given that|since the formulation|targeted|the mechanism)"], "core"),
   ("Names the theory or model underpinning the work", [r"(cbt|cognitive|behavioural|systemic|act|dbt|psychodynamic|attachment|model|theory)"], "core"),
   ("Reports the outcome honestly, including where it did not work", [r"(did not|didn't|partially|mixed|stuck|no change|less well|struggled)"], "core"),
   ("Reflects: what went well, what you would do differently, what you learned", [r"(reflect|would (do )?differently|learned|in hindsight|looking back)"], "core"),
   ("Names how supervision shaped the work", [r"supervis"], "core"),
   ("Can critique the model itself, not just their own delivery of it", [r"(critique|limitation of (the|this) (model|approach)|criticis|does not account)"], "advanced"),
   ("Language is psychological and non-pathologising throughout", [r"(wonder|hypothes|might|seemed|understandab|made sense|given (his|her|their))"], "advanced")],
  ["What psychological theory is this linked to?",
   "What are the critiques of that theory?",
   "How did you plan the intervention?",
   "Were there any hurdles?",
   "What would you do differently?",
   "Is there anything else that could have affected this work?",
   "You've been seeing this client for some time and are starting to feel stuck. What factors might you consider?"],
  "Two failures. First, the intervention justified by preference — 'I used CBT because the client wanted a "
  "practical approach' — rather than by mechanism. Second, a case that went perfectly, which reads as either "
  "unreflective or untrue.",
  "Choose a case that did NOT go smoothly. Referral → what you understood was happening and how you built that "
  "understanding with them → what followed from it → what happened → what you would change. Use 'we hypothesised', "
  "'we shared', 'collaboratively' — the TIPS document from a successful candidate flags these words specifically. "
  "Then be able to critique the model you used, not only your own performance.",
  ["formulation", "cbt_model", "therapeutic_alliance", "supervision", "reflective_practice", "hypothesis_testing"])

theme("risk_live", "Risk arriving in the room",
  "Birmingham 2018: a client messages you on social media saying they feel suicidal. Exeter 2012: a teenage "
  "client's mother rings to say he has disappeared, possibly with an 'irresponsible' uncle, and he is due to "
  "see you later. Cardiff: a carer rings about a husband with a stroke who is not eating or drinking. These "
  "are graded for process, not for a correct answer.",
  [("Establishes immediate safety first, before anything procedural", [r"(immediate|right now|first|safety|are they safe|where (are|is) (they|he|she)|now)"], "core"),
   ("Asks specifically rather than generally — ideation, intent, plan, means, timeframe", [r"(intent|plan|means|when|how|thoughts of|specific)"], "core"),
   ("Recognises the channel or frame issue and addresses it", [r"(social media|not (a|the) (right|appropriate|safe) (channel|route|medium)|boundar|frame|not monitored|out of hours)"], "core"),
   ("Does not act alone — names supervision, duty, crisis team or the wider system", [r"(supervis|duty|crisis|team|on.?call|escalat|discuss with|senior|colleague)"], "core"),
   ("Considers confidentiality and its limits, and what would be shared with whom", [r"confidential|share|disclos|need to know|inform"], "core"),
   ("Thinks about the person's experience, not only the procedure", [r"(they must|frightening|distress|how (they|he|she) (feel|might)|desperate|reaching out|what it took)"], "core"),
   ("Documents and follows up — including what happens in the next session about the frame", [r"(document|record|write|next session|follow.?up|revisit|come back to)"], "core"),
   ("Distinguishes risk assessment from risk prediction", [r"(cannot predict|not (a )?prediction|formulat|circumstances (under )?which|when risk)"], "advanced"),
   ("Notes what is unknown and what they would need to find out", [r"(I (would )?(want|need) to know|unknown|unclear|would ask|more information)"], "advanced")],
  ["What if they don't answer the phone?",
   "What if they tell you not to tell anyone?",
   "The client says they will disengage if you contact anyone. What now?",
   "What would you document?",
   "How would this affect the next session?",
   "How would you feel?"],
  "Jumping to procedure without the person, or to empathy without the safety. Also: promising confidentiality "
  "you cannot keep, or contacting everyone without thinking about the therapeutic cost.",
  "Immediate safety → specific enquiry → what I can and cannot do through this channel → who I involve and when "
  "→ what I say about confidentiality → document → what I do with the frame afterwards. Say out loud that risk "
  "assessment is not prediction: what you are doing is formulating the circumstances under which risk rises, and "
  "planning for those.",
  ["risk_assessment", "suicide_risk", "safety_plan", "confidentiality", "social_media_boundary", "escalation"])

theme("ethics_clash", "A clash of ethics or values",
  "Plymouth 2014 and Southampton 2015 both ask for a time you felt there was a clash of ethical interests. "
  "Exeter 2013 gives a graded assisted-suicide scenario with escalating information. South Wales set the "
  "witnessed-theft written task. Cardiff asks 'you can help 4 people at 80%, or 8 people at 40% — discuss'.",
  [("Identifies WHICH principles are in tension, by name", [r"(autonomy|beneficen|non.?malefic|justice|confidential|capacity|consent|duty|competing|tension between)"], "core"),
   ("Does not collapse the dilemma prematurely into one right answer", [r"(both|on the one hand|tension|difficult|not (straightforward|simple)|competing|no (easy|clear) answer)"], "core"),
   ("Considers the perspectives of each party affected", [r"(for (the|them|him|her)|from (their|his|her) (point of view|perspective)|the (client|family|colleague|team))"], "core"),
   ("Names the relevant framework or legal instrument where one applies", [r"(bps|hcpc|code of (ethics|conduct)|mental (capacity|health) act|safeguard|policy|law|legal)"], "core"),
   ("Takes it to supervision or consultation rather than deciding alone", [r"supervis|consult|discuss with|senior|team|advice|not (alone|on my own)"], "core"),
   ("Arrives at a proportionate action — reflection leads somewhere", [r"(I would|the action|what I('d| would) do|next step|so I)"], "core"),
   ("Documents the reasoning, including options rejected", [r"(document|record|written|note|rationale|reasoning)"], "advanced"),
   ("Acknowledges what remains unresolved or uncomfortable afterwards", [r"(still|remain|uncomfortab|not (fully )?resolved|sat with|difficult afterwards|would stay with)"], "advanced")],
  ["What did you learn from this situation?",
   "What are the issues for you? For your colleague? For the client?",
   "The client's sister turns up angry and wants to make a complaint about you. What would you do? How would you feel?",
   "What if your supervisor disagreed with you?",
   "What would you do if the service told you not to pursue it?"],
  "Resolving the dilemma in the first sentence. If you knew immediately what to do, it was not an ethical "
  "dilemma — it was a procedure. The panel wants to see you hold the tension before you act.",
  "Name the competing principles → say who is affected and how → say what makes it genuinely hard → name the "
  "framework and the person I would consult → state the proportionate action → say what remains unresolved. "
  "Exeter's version escalates: expect new information designed to destabilise your first answer, and treat "
  "revising your position as strength rather than as being caught out.",
  ["confidentiality", "capacity", "safeguarding", "escalation", "supervision", "documentation", "positive_risk"])

theme("stuck", "Feeling stuck, or out of your depth",
  "Birmingham 2018: you've been seeing a client for some time and are starting to feel stuck — what factors "
  "might you consider? Coventry 2018: talk about a time you felt out of your depth. Exeter: how do you "
  "experience and manage stress.",
  [("Treats stuckness as information about the work rather than as personal failure", [r"(information|tells (me|us)|data|meaningful|says something|understand(able)?|not (a )?failure)"], "core"),
   ("Revisits the formulation — is the hypothesis wrong, or incomplete", [r"(formulation|hypothes|re.?formulat|revisit|might have missed|wrong (about|model))"], "core"),
   ("Considers the alliance — rupture, unspoken disagreement about goals or tasks", [r"(alliance|relationship|rupture|goal|task|agreement|unspoken|between us)"], "core"),
   ("Considers what is outside the room — the system, the family, material circumstances", [r"(system|family|context|housing|financ|work|outside|wider|social)"], "core"),
   ("Uses their own response as data", [r"(my (own )?(response|reaction|feeling)|countertransference|what (it|this) evokes|I notice(d)? (in|that) (myself|I))"], "core"),
   ("Asks the client directly", [r"(ask (them|him|her)|raise it|name it|talk about it with|check (with|out) (them|him|her)|be curious with)"], "core"),
   ("Takes it to supervision", [r"supervis"], "core"),
   ("Considers that the intervention may be wrong, or the timing, or that the person may not want this now", [r"(wrong (model|approach|intervention)|different (approach|model)|timing|might not want|readiness|pause|stop)"], "advanced")],
  ["What if the client says everything is fine?",
   "What if supervision does not help?",
   "How would you know when to stop the work?",
   "How did you manage this? What skills did you need?"],
  "Listing techniques you would try. Stuckness is rarely solved by a new technique; it is usually a signal "
  "about the formulation, the alliance, or something outside the room.",
  "Stuck is data → check the formulation → check the alliance and ask them directly → look outside the room → "
  "use my own reaction → supervision → consider that the model or the timing may be wrong. Notice that the "
  "answer moves outward from the technique to the relationship to the system.",
  ["therapeutic_alliance", "rupture_repair", "formulation", "use_of_self", "supervision", "context"])

theme("engagement", "Engaging someone who is hard to reach",
  "Southampton 2013: how would you build a relationship with someone who is silent? Cardiff 2013: how would "
  "you engage with a service user, and what barriers might you encounter? South Wales: it can be distressing "
  "for people to come and see a clinical psychologist — how would you handle other people's distress?",
  [("Starts from curiosity about the meaning of the behaviour rather than from technique", [r"(why|what (might|does) (it|silence|this) mean|curious|wonder|understand(able)?|makes sense)"], "core"),
   ("Considers what the person may be protecting themselves from", [r"(protect|safe|risk|frighten|been (hurt|let down)|previous experience|history)"], "core"),
   ("Names the power and institutional context of the encounter", [r"(power|referred by|not (their|his|her) choice|statutory|institution|who sent|why (they are|he is|she is) here)"], "core"),
   ("Adapts the frame — pace, setting, length, medium, who else is present", [r"(pace|slow|shorter|setting|walk|different room|home|online|someone (else|with)|activity)"], "core"),
   ("Considers structural and practical barriers", [r"(transport|cost|childcare|work|language|interpret|literacy|access|time of day)"], "core"),
   ("Tolerates the silence or the non-engagement without filling it anxiously", [r"(tolerate|sit with|not (rush|fill|push)|space|allow|patience|silence (is|can))"], "core"),
   ("Names it directly and collaboratively with the person", [r"(name it|say (to them|out loud)|check (with|out)|ask (them|him|her) (what|how)|be open about)"], "advanced"),
   ("Reflects on their own contribution to the difficulty", [r"(my (own )?(part|contribution|manner|assumption)|what I (might be|am) doing|am I)"], "advanced")],
  ["What barriers and problems might you encounter?",
   "What if they still do not speak in the third session?",
   "A clinician interprets a patient's disengagement as poor motivation. What alternative explanations would you consider?",
   "How would you make sure I trusted you?"],
  "Producing a list of rapport techniques. The strong answer starts from 'what might this silence be doing for "
  "them?' and stays there before it moves to what the clinician does.",
  "What might this mean for them → what are they protecting → what does the institutional context add → what I "
  "would change about the frame → what practical barriers exist → what I would name openly → what my own part "
  "might be. Cardiff's 2016 phrasing — 'how would you make sure I trusted you?' — is asked BY a carer on the "
  "panel, so answer it to them, not about them.",
  ["therapeutic_alliance", "power_relations", "cultural_humility", "access_inequality", "validation"])

theme("formulation_layperson", "Explaining a formulation to a lay audience",
  "Coventry 2018's written exercise: after watching a ten-minute therapy session, 'write out a formulation of "
  "the client's difficulties that a layman would understand'. This tests whether you can hold psychological "
  "precision and plain language at once.",
  [("Uses the person's own words and idiom where possible", [r"(her words|his words|as (she|he) (put|said|described)|in (their|her|his) (own )?(words|terms))"], "core"),
   ("Explains mechanism, not just a list of factors", [r"(because|which (then|means)|leads to|feeds back|keeps|so that|the more.{0,40}the more)"], "core"),
   ("No jargon, or jargon immediately unpacked", [r"(in other words|that is|which means|what I mean by)"], "core"),
   ("Includes what makes sense about the person's response — it is understandable, not irrational", [r"(makes sense|understandab|given (what|everything)|no wonder|anyone (would|might)|not (irrational|mad|strange))"], "core"),
   ("Names a maintaining cycle in ordinary language", [r"(cycle|loop|vicious|the more.{0,50}the more|keeps (it|this) going|feeds)"], "core"),
   ("Includes strengths and what has helped", [r"(strength|resource|managed|coped|helped|what (works|has worked)|despite)"], "core"),
   ("Is offered tentatively as something to check, not delivered as a verdict", [r"(does that fit|wonder|might|seems|check|tell me if|my sense|would that)"], "core"),
   ("Points toward what could change, and why", [r"(change|different|if (we|you)|might help|way (out|forward)|break the cycle)"], "advanced")],
  ["What do you think the client is feeling or experiencing?",
   "What do you think the therapist is feeling or experiencing?",
   "How would you check this with the client?",
   "What would you do if she disagreed with your formulation?"],
  "Translating jargon into simpler jargon. 'Your negative automatic thoughts are maintaining a cycle of "
  "avoidance' is not lay language. Also: producing a list of the 5 Ps with no mechanism connecting them.",
  "Start from what happened to them → what they came to expect or believe → what they do to cope → why that "
  "makes complete sense → how it keeps the problem going → what they have that helps → what could change. "
  "Then: 'does that fit with how it feels from the inside?' Write it as if reading it aloud to the person.",
  ["formulation", "maintenance_cycle", "five_ps", "validation", "power_relations"])

# ------------------------------------------------------------------ PERSONAL / PROFESSIONAL
theme("reflective_personal", "Reflective and personal questions",
  "Resilience (Exeter 2011, 2012), a challenging experience (Plymouth 2013), criticism you disagreed with "
  "(Exeter 2011), a disagreement with a colleague (Cardiff 2016), a 360 appraisal (Coventry 2018), feedback "
  "you received (Southampton 2013), how your experiences shaped you (Birmingham 2018, 2019). This is where "
  "you are already strong — the risk is generic delivery, not lack of insight.",
  [("Gives a SPECIFIC episode, not a general disposition", [r"(there was (a|one)|last (year|month)|I remember|on one occasion|a client|a colleague|specifically|for example)"], "core"),
   ("Names the actual feeling, not a professionalised version of it", [r"(I felt|I was (angry|frightened|ashamed|embarrassed|defensive|hurt|anxious|out of my depth)|it stung|I dreaded)"], "core"),
   ("Owns a genuine contribution to the problem", [r"(my (own )?(part|contribution|fault|mistake|error)|I (had|was) (assumed|missed|avoided|got (it|this) wrong)|I contributed)"], "core"),
   ("Names the assumption they were making", [r"(assum|took for granted|I thought that|my belief|expected)"], "core"),
   ("Says what someone else saw that they had not", [r"(supervisor (said|pointed|noticed)|colleague (said|told)|they saw|pointed out|feedback (was|said)|someone else)"], "core"),
   ("Describes a BEHAVIOURAL change, not just an insight", [r"(since then I|now I|I (started|changed|began|stopped)|I do (it )?differently|next time I)"], "core"),
   ("Distinguishes intention from impact", [r"(intended|meant to|impact|how it landed|came across|effect on (them|her|him))"], "advanced"),
   ("Leaves something genuinely unresolved", [r"(still|not sure|remain|don't (fully )?know|continue to (find|struggle)|ongoing)"], "advanced")],
  ["What did you learn from it?",
   "What would you do now?",
   "What did your supervisor see that you had not?",
   "What if it happened again tomorrow?",
   "Talk about a time your resilience was LOW.",
   "If you received a 360-degree appraisal from your colleagues and supervisor, what would it say?"],
  "The polished redemption arc: difficulty, learning, resolution, moral. Panels hear forty of these a day. "
  "The second failure is answering the negative version — 'a time your resilience was low', 'what would the "
  "appraisal say' — with a disguised strength.",
  "Specific episode → what I actually felt → what I assumed → what I contributed → what someone else saw → what "
  "I did differently afterwards → what is still unresolved. Prepare the NEGATIVE versions deliberately: a time "
  "resilience was low, criticism that was fair, what colleagues would say you find difficult. Those are the "
  "questions that separate candidates, and they cannot be answered with a strength in disguise.",
  ["reflective_practice", "use_of_self", "supervision", "rupture_repair"])

theme("supervision_use", "Using supervision",
  "Southampton 2015 asks directly for an example of appropriate use of clinical supervision. South Wales asks "
  "the difference between a supervisor and a mentor. Almost every clinical answer should route through "
  "supervision at some point.",
  [("Brings difficult material rather than a summary of successes", [r"(difficult|stuck|worried|mistake|uncomfortab|did not know|struggling|got (it )?wrong|uncertain)"], "core"),
   ("Names a specific instance, with what they took and why", [r"(I took|I brought|I raised|I asked (about|whether))"], "core"),
   ("Shows supervision changing something", [r"(changed|different|after that|as a result|shifted|I then|realised)"], "core"),
   ("Recognises supervision's normative function — safety and accountability, not only support", [r"(safe|accountab|responsib|governance|oversight|patient safety|check)"], "advanced"),
   ("Distinguishes supervision from line management or from therapy", [r"(not (line )?management|not therapy|different (from|to)|whereas (a )?(mentor|manager))"], "advanced"),
   ("Shows they can disagree with a supervisor and manage it", [r"(disagree|different view|I thought|challenged|pushed back)"], "advanced")],
  ["What is the difference between having a supervisor and a mentor?",
   "What would you do if you disagreed with your supervisor?",
   "What would you do if supervision was not available?",
   "What makes supervision unsafe?"],
  "Describing supervision as a place you report on cases and receive reassurance. The examinable insight is "
  "that supervision has a normative function — it is part of how services keep people safe.",
  "One specific instance of taking something difficult → why I took THAT → what shifted → what I did "
  "differently. Have ready: the three functions (normative, formative, restorative), and what you would do if "
  "you disagreed with your supervisor.",
  ["supervision", "reflective_practice", "escalation", "documentation"])

theme("professional_identity", "What clinical psychology is for",
  "Cardiff role-plays a psychologist joining a new learning disability MDT and asks what the psychologist "
  "brings. Glasgow asks the key skills and knowledge needed. South Wales asks what skills a clinical "
  "psychologist needs and how you demonstrate your value. The Clinical Application Tips document is explicit: "
  "understand the wider role, not just therapy.",
  [("Names contributions beyond direct therapy", [r"(consultation|supervis|research|evaluation|teaching|training|leadership|service (development|design)|systems|audit|indirect)"], "core"),
   ("Puts formulation at the centre as the distinctive contribution", [r"formulat"], "core"),
   ("Names the scientist-practitioner or evidence-appraisal contribution", [r"(scientist.?practitioner|evidence|appraise|research skills|critical)"], "core"),
   ("Avoids constructing a hierarchy over other professions", [r"(alongside|with colleagues|complement|other professions (also|bring)|not (better|superior)|shared)"], "core"),
   ("Acknowledges limits of the profession honestly", [r"(limit|cannot|not (always|the answer)|risk of|criticis|weakness of)"], "core"),
   ("Attends to the psychological process of the team as well as the patient", [r"(team (dynamic|process|anxiety)|containment|reflective (practice|space)|staff (support|wellbeing)|splitting|parallel)"], "advanced"),
   ("Grounds it in a concrete example", [r"(for example|in my (role|post)|when I|I have)"], "advanced")],
  ["What would the clinical psychologist bring to this team?",
   "How do you demonstrate your value?",
   "What can clinical psychology offer for university students with stress?",
   "How might a clinical psychologist support someone with physical health problems?",
   "What are the limitations in the literature on that?",
   "What is the clinical psychologist's role in integrating care?"],
  "Answering as though clinical psychology is individual therapy plus an interest in research. The corpus is "
  "full of questions about indirect work, consultation, teams and leadership, and Cardiff's non-1:1 written "
  "task makes the point explicitly.",
  "Formulation as the distinctive contribution → applied to individuals, to teams, and to services → plus "
  "evidence appraisal, evaluation, consultation, training, supervision and leadership → held alongside other "
  "professions rather than above them → with an honest limit. Ground each claim in one concrete example.",
  ["mdt", "consultation", "team_formulation", "leadership", "scientist_practitioner", "formulation"])

theme("leadership", "Leadership",
  "Exeter asks in 2011 and 2012 what leadership is and what skills it needs; Coventry 2018 asks which "
  "qualities you have and which you would need to work on. The Clinical Application Tips document says "
  "flatly: 'Leadership is a huge area on courses! Definitely mention this.'",
  [("Defines leadership as influence rather than authority", [r"(influence|without (formal )?authority|not (about )?(being in charge|position|hierarchy|management)|anyone can)"], "core"),
   ("Names concrete leadership behaviours", [r"(advocat|develop(ing)? others|model|set (the )?(tone|standard)|challeng|speak up|convene|shape|hold (a )?vision)"], "core"),
   ("Links it to psychological skills specifically — process, containment, formulation of systems", [r"(process|containment|reflective|systems|formulation|psychological (thinking|mind))"], "core"),
   ("Identifies a genuine developmental need in themselves", [r"(I (would )?(need|struggle|find (it )?(hard|difficult))|less (confident|good)|develop|work on|not (yet )?(strong|comfortable))"], "core"),
   ("Gives an example of having influenced something", [r"(for example|I (led|changed|set up|proposed|persuaded|influenced))"], "core"),
   ("Distinguishes leadership from management explicitly", [r"(management|manager)", r"(different|whereas|not the same|distinct)"], "advanced"),
   ("Acknowledges the risk of psychologists claiming leadership over other professions", [r"(risk|careful|not (over|above)|other professions|humility|assume)"], "advanced")],
  ["Which of these do you have, and what would you need to work on in training?",
   "Do you want to be a leader?",
   "Have you influenced somebody? Talk about a time you influenced somebody.",
   "What is the difference between leadership and management?"],
  "Describing leadership as seniority, or claiming leadership qualities without a single instance of having "
  "exercised them. Also: naming a fake development need ('I take on too much').",
  "Influence rather than authority → the specific behaviours → what psychology contributes that is distinctive "
  "(attention to process, containment, formulating systems) → one real example of influencing something → one "
  "genuine limitation with what you are doing about it.",
  ["leadership", "service_development", "mdt", "advocacy", "reflective_practice"])

theme("service_user", "Service user and carer involvement",
  "Cardiff foregrounds this more than any other course in the corpus — 2012 and 2013 both have multiple "
  "questions, and service users and carers sit on panels at Cardiff, Exeter, Southampton, Glasgow and "
  "Coventry, asking their own questions. Expect to be asked BY a service user or carer.",
  [("Distinguishes involvement from co-production — who holds power over what", [r"(co.?produc|power|from the (start|beginning|outset)|token|who decides|shar(e|ing) power)"], "core"),
   ("Names concrete domains: selection, teaching, service design, research, governance", [r"(selection|interview|teach|train|curriculum|design|research|governance|recruit)"], "core"),
   ("States a genuine difficulty honestly rather than only benefits", [r"(difficult|challenge|risk|tension|not (always )?easy|cost|burden|tokenis|pay|unpaid)"], "core"),
   ("Addresses payment, support and accessibility", [r"(paid|payment|remunerat|expenses|support|accessib|training for)"], "advanced"),
   ("Recognises that involvement changes what is ASKED, not only what is answered", [r"(question|agenda|what we ask|frame|priorit|different (question|things))"], "advanced"),
   ("Attends to whose voices get selected and who is left out", [r"(whose|which (people|voices)|left out|not represent|articulate|already engaged|seldom heard)"], "advanced")],
  ["What are the benefits and difficulties of having service users involved in services, service design or clinical training?",
   "What are your beliefs and values about service user involvement?",
   "What are the advantages of involving a service user in training?",
   "What can a clinical psychologist do to support a carer?",
   "Who can clinical psychology support more — service users or carers?",
   "How would you show me you respected and valued my viewpoint?"],
  "Unqualified enthusiasm. 'It's really important and brings the service user voice' is what everybody says. "
  "Naming a real difficulty — tokenism, unpaid labour, selecting for the most articulate — is what "
  "distinguishes a considered position from a rehearsed one.",
  "Involvement sits on a spectrum from consultation to co-production, and the question is always who holds "
  "power over the decision → concrete domains → a genuine difficulty → payment and support as the test of "
  "whether it is real → whose voices get selected. If a service user or carer asks you, answer TO them.",
  ["coproduction", "service_user_involvement", "carers", "power_relations", "equity_equality"])

theme("policy_context", "Policy, austerity and the NHS",
  "Glasgow 2018 asks about a government policy and its impact; South Wales asks what clinical psychology can "
  "do in the face of austerity; Exeter 2012 asks about the Health and Social Care Bill; Cardiff asks how "
  "England and Wales differ. Plymouth asked candidates to read the Berwick report in advance. The TIPS "
  "document says plainly: read the Guardian.",
  [("Names a specific policy or document rather than gesturing at 'cuts'", [r"(long term plan|community mental health framework|talking therapies|iapt|berwick|francis|marmot|social services and well.?being|health and social care|act|strategy|nice)"], "core"),
   ("Explains the mechanism by which it reaches clinical work", [r"(means that|so that|leads to|results in|in practice|on the ground|for clinicians|the effect (is|of))"], "core"),
   ("Names who is most affected", [r"(most affected|deprived|poorest|inequalit|those who|hardest hit|marginalis)"], "core"),
   ("Holds a position without being polemical", [r"(I think|my view|although|however|on balance|there is (a )?(case|argument)|complicat)"], "core"),
   ("Says what psychologists can actually DO about it", [r"(we can|psychologists (can|could)|evidence|evaluat|advocat|design|redesign|target|reach)"], "core"),
   ("Connects to the psychological evidence on the social determinants of distress", [r"(social determinant|poverty|housing|inequalit|material|debt|deprivation|marmot)"], "advanced")],
  ["What might that mean for a trainee?",
   "What can clinical psychology do in the face of austerity?",
   "How do we overcome the challenges to implementing the evidence base?",
   "What will the impact be to psychology if we don't find time to do research?",
   "What did you feel was the most important aspect of the Berwick report, and how would you disseminate it?"],
  "Vague dismay about cuts and waiting lists. The TIPS document from a successful candidate advises having an "
  "opinion 'that's not too strong' — a position you can defend, held with some complexity.",
  "Name one policy you actually know → the mechanism by which it changes clinical work → who bears the cost → "
  "your position, held with complexity → what psychologists can do about it. Prepare TWO: one UK-wide, one "
  "specific to your course's nation. For Cardiff, know that Wales has its own strategy and legislation and "
  "that 'what's different about Wales' is asked repeatedly.",
  ["social_determinants", "access_inequality", "stepped_care", "community_framework", "leadership", "equity_equality"])

theme("diversity", "Difference, diversity and inequality",
  "Exeter 2012 asks what diversity means and what it implies for the profession; Birmingham 2018 asks about "
  "diversity and difference including deafness; Plymouth 2013 asks for an example of adapting practice, and "
  "how your own values and background affect your work; South Wales asks a diversity question from a service "
  "user panellist.",
  [("Moves beyond 'culture matters' to a specific mechanism", [r"(mechanism|specifically|for example|because|the way (that|in which)|what (that|this) means in practice)"], "core"),
   ("Names structural factors, not only individual attitudes", [r"(structural|institution|access|pathway|referral|detention|system|poverty|racism|barrier)"], "core"),
   ("Distinguishes cultural humility from cultural competence", [r"(humilit|not (about )?(knowing|expertise)|the person is the expert|lifelong|competence)"], "core"),
   ("Reflects on their OWN position and its effects", [r"(my (own )?(background|position|assumptions|privilege|whiteness|class)|how I (am|might be) (seen|read)|what I bring)"], "core"),
   ("Gives a concrete adaptation with a rationale", [r"(adapt|changed|interpret|format|pace|setting|involved|different)", r"because|so that|since"], "core"),
   ("Names equity rather than equality", [r"(equit|according to need|same (service|offer) (is|does) not)"], "advanced"),
   ("Considers intersection rather than single categories", [r"(intersect|both|multiple|combination|not just|as well as being)"], "advanced")],
  ["What implications does this have for clinical psychology?",
   "How do you think your values and background may affect your practice?",
   "What does stigma mean to you, and how would your values address this?",
   "How do you work with difference and diversity?",
   "A clinician interprets a patient's disengagement as poor motivation. What alternative contextual explanations would you consider?"],
  "Warm generality. 'Everyone is an individual and I'd be curious about their culture' passes for an answer "
  "but distinguishes nobody. The move that lands is naming a specific structural mechanism and one concrete "
  "thing you would do differently.",
  "One specific mechanism (who gets referred, who gets detained, who drops out, and why) → structural rather "
  "than attitudinal → my own position and its effects → one concrete adaptation with its rationale → equity "
  "rather than equality. Have a real example of adapting your own practice ready.",
  ["cultural_humility", "structural_racism", "access_inequality", "equity_equality", "intersectionality", "adaptation", "power_relations"])

theme("motivation", "Why clinical psychology, and why you",
  "Asked everywhere. Birmingham 2019 asks how personal experiences, positive AND negative, led you here. "
  "Exeter 2013 and 2012 ask directly. South Wales asks what you would add to your application form. Cardiff "
  "asks what experience makes you ready to train.",
  [("Gives something specific rather than a vocation narrative", [r"(specific|for example|when I|there was|a (client|patient|person)|in my (role|job))"], "core"),
   ("Connects to what clinical psychology actually is, in its breadth", [r"(formulation|research|evidence|systems|consultation|breadth|not just therapy|scientist)"], "core"),
   ("Handles personal experience with boundaried openness where they choose to use it", [r"(personal|my own|family|experience of)"], "advanced"),
   ("Shows they know what they are letting themselves in for", [r"(difficult|demanding|hard|challenge|not (easy|glamorous)|realistic|cost)"], "core"),
   ("Says what they would bring, not only what they want", [r"(I bring|I would (bring|contribute|offer)|what I (have|can offer))"], "core"),
   ("Course-specific: connects to THIS course's ethos, research or model", [r"(this course|here|your (course|programme|department)|research (here|interest)|why (cardiff|ucl|uea|wales))"], "core")],
  ["Why this course?",
   "Why do you want to train in Wales?",
   "How have your personal experiences, both positive and negative, led you to clinical psychology?",
   "What experience have you got which makes you ready to train?",
   "The application form can be constricting — what would you like to add?",
   "How would you juggle the demands and manage the pressures of the course?"],
  "The origin story with no specificity, or the answer that could be given to any of the four courses. "
  "Cardiff asks 'why Wales' explicitly; a generic answer there is very visible.",
  "One specific thing that happened, briefly → what it made you understand about the work → what you have "
  "since learned about the breadth of the role → what you would bring → why THIS course specifically. Write "
  "the last section separately for each of your four courses.",
  ["scientist_practitioner", "reflective_practice", "professional_identity" if False else "mdt"])

theme("group_task", "Group discussion tasks",
  "Coventry splits candidates into groups to discuss set clinical topics before a panel including a service "
  "user. Exeter shows a video of a service user's experience of depression — WITH that person in the room — "
  "and asks the group questions in turn. You are assessed on how you work with others, not on being right.",
  [("Brings others in, especially anyone who has not spoken", [r"(bring (them|others) in|what do you think|invite|hasn't (spoken|said)|others|space for)"], "core"),
   ("Builds on what someone else said rather than restarting", [r"(building on|picking up|as (x|someone) said|adding to|that made me think)"], "core"),
   ("Disagrees without dismissing", [r"(I see it differently|another way|although|I wonder whether|not sure I agree|but also)"], "core"),
   ("Addresses the service user in the room as a person, not a case", [r"(you|your experience|ask (you|them)|directly|thank you for)"], "core"),
   ("Contributes substance, not only process management", [r"(I think|my view|the evidence|research|because)"], "core"),
   ("Watches the time and the task", [r"(time|we should|move on|cover|the question was|come back to)"], "advanced")],
  ["Why do you think I found couples therapy more helpful than individual therapy?",
   "What do you think my experience of having suicidal thoughts was?",
   "What would someone experiencing depression for the first time understand by the term 'recovery'?",
   "Why do you think I have not got better despite lots of therapy and medication? How do you think that would feel?",
   "The role of service users in developing clinical psychology training programmes.",
   "The need for personal therapy during training — is it essential?"],
  "Two opposite failures: dominating, and disappearing. A third, specific to the Exeter format — talking ABOUT "
  "the service user in the room in the third person while they sit there.",
  "Speak early so you are not silent, then make your next contribution one that brings someone else in. If a "
  "service user is present and the question is about their experience, address them directly and ask rather "
  "than theorise. Exeter's write-up notes candidates were 'encouraged to fulfil your potential' — the panel "
  "wants everyone to speak, so helping that happen is scored positively.",
  ["mdt", "service_user_involvement", "power_relations", "validation"])

theme("roleplay_prep", "Role-play",
  "Glasgow gives four possible colleague scenarios a week ahead — deliberately designed so no career path is "
  "advantaged — and states the aim explicitly: establish the circumstances and understand the colleague's "
  "reaction. There is NO expectation you resolve the problem. Southampton has you play a college counsellor "
  "meeting a student with exam stress, assessing engagement and brief formulation. Cardiff role-plays joining "
  "a new MDT.",
  [("Does not try to solve the problem", [r"(not (my job|to (fix|solve))|resist|understand first|explore|before (fixing|advising))"], "core"),
   ("Opens the space rather than interrogating", [r"(open question|tell me|what('s| is) (been )?(happening|going on)|how (has|have)|where (would|do) you want)"], "core"),
   ("Reflects content AND feeling back", [r"(sounds|it seems|I('m| am) hearing|that must|reflect|so what (you're|you are) saying)"], "core"),
   ("Validates before moving on", [r"(makes sense|understandab|no wonder|of course|anyone (would|might)|not surprising)"], "core"),
   ("Stays with the person's experience rather than the facts of the incident", [r"(how (that|it) (felt|was|landed)|for you|your (reaction|experience)|what (that|it) was like)"], "core"),
   ("Checks rather than assumes", [r"(have I got|is that right|does that fit|am I understanding|correct me)"], "core"),
   ("Manages own reaction and role boundary — a peer, not a therapist", [r"(colleague|peer|equal|not (their|your) (therapist|supervisor)|role|boundar)"], "advanced"),
   ("Closes by asking what would be useful, rather than prescribing it", [r"(what would (be )?(help|useful)|what do you want|where (do|would) you want to (take|go)|would it help)"], "advanced")],
  ["What was the presenting issue for the client?",
   "How could you see the intervention moving forward with this client?",
   "Was there anything about your performance you felt could be improved? What? How?",
   "How did you find that?"],
  "Rushing to advice. Under pressure candidates fill silence with suggestions, which is precisely what Glasgow's "
  "brief says is NOT required. The second failure is treating a peer as a patient.",
  "Open → listen → reflect content and feeling → validate → stay with their experience not the incident → check "
  "your understanding → ask what would help. Say almost nothing in the first ninety seconds beyond open "
  "questions. Southampton's write-up is reassuring on this: 'once the conversation started I actually forgot I "
  "was being observed'.",
  ["therapeutic_alliance", "validation", "use_of_self", "dual_relationship", "rupture_repair"])

theme("uncertainty", "Not knowing",
  "The TIPS document from a successful candidate is unambiguous: 'Don't worry if you don't know the answer — "
  "openly reflect on your difficulties and acknowledge any limitations openly. State what you would do to find "
  "out.' This is a scored competency, not a fallback.",
  [("Says plainly that they do not know, without collapsing", [r"(I don't know|I'm not (sure|certain)|I haven't (come across|encountered)|that's not something I)"], "core"),
   ("Identifies what they DO know that is relevant", [r"(what I do know|I do know|related|similar|from what I understand|I can say)"], "core"),
   ("Offers a reasoned provisional hypothesis, flagged as such", [r"(my (initial )?(hypothesis|guess|thinking)|I would (imagine|expect|wonder)|provisional|tentativ|might be)"], "core"),
   ("States what information would resolve it", [r"(I would (want|need) to know|would find out|depends on|the question is whether|more information)"], "core"),
   ("Names a concrete route to finding out", [r"(supervis|read|literature|guideline|nice|bps|consult|colleague|ask)"], "core"),
   ("Does not bluff", [r"^(?!.*\b(obviously|clearly|definitely|certainly)\b)"], "advanced")],
  ["What don't you know?",
   "What would you do to find out?",
   "So how would you proceed in the meantime?",
   "What would change your mind?"],
  "Bluffing. Panels can tell, and a fabricated answer costs more than the gap it was hiding. The other failure "
  "is over-apologising and losing the rest of the interview to the one question.",
  "'I don't know' → 'what I do know that's relevant is…' → 'my provisional thinking would be…' → 'what I'd want "
  "to find out is…' → 'and I'd do that by…'. Practise this until it is fluent, because delivered well it "
  "demonstrates exactly the professional stance the courses are selecting for. The TIPS document also suggests "
  "asking to come back to a question at the end.",
  ["scientist_practitioner", "supervision", "reflective_practice", "hypothesis_testing"])

# =====================================================================
# VERBATIM QUESTIONS FROM THE CORPUS
# =====================================================================
Q = []
def q(text, course, year, panel, theme_id, mode="3min"):
    Q.append({"id": f"q{len(Q)+1:03d}", "text": text, "course": course, "year": year,
              "panel": panel, "theme": theme_id, "mode": mode})

# ---- Cardiff
for t in ["How does your current role prepare you to train to be a clinical psychologist?",
          "What skills do you have that prepare you to train to be a clinical psychologist?"]:
    q(t, "Cardiff", 2013, "personal", "motivation")
q("How would you engage with a service user? What barriers and problems might you encounter?", "Cardiff", 2013, "personal", "engagement")
q("What ways do England and Wales differ, NHS-wise? What might this mean for a trainee?", "Cardiff", 2013, "personal", "policy_context")
q("How might you check a carer is engaged with a service user's care plan?", "Cardiff", 2013, "personal", "service_user")
q("A carer calls to say her husband, who has had a stroke, is not eating or drinking. What would you do?", "Cardiff", 2013, "personal", "risk_live", "vignette")
q("What are the advantages of involving a service user in training?", "Cardiff", 2013, "personal", "service_user")
q("How might a clinical psychologist support someone with physical health problems? What are the limitations in the literature on this?", "Cardiff", 2013, "clinical", "professional_identity")
q("If you had unlimited funds, what research question would you address?", "Cardiff", 2013, "academic", "research_design")
q("Talk about a piece of research or audit you have done. Strengths and limitations?", "Cardiff", 2013, "academic", "research_own")
q("Talk about a psychological model you have used with a client. Now talk about a different model you could use with the same client. Is there anything else that could have affected this work?", "Cardiff", 2013, "clinical", "model_switch")
q("You are working with a medical colleague who is a strong proponent of genetics. How would you persuade him about psychological approaches?", "Cardiff", 2013, "clinical", "professional_identity")
q("What are the advantages of formulation?", "Cardiff", 2013, "clinical", "professional_identity", "60s")
q("Tell us about a disagreement you had with a colleague. What do you think they thought your role was?", "Cardiff", 2016, "clinical", "reflective_personal")
q("If I came to you and said I was unhappy or distressed by my diagnosis, what would you do?", "Cardiff", 2016, "clinical", "engagement", "vignette")
q("With reference to the written test — what values underpinned your answers?", "Cardiff", 2016, "clinical", "professional_identity")
q("If I was a carer for a person with dementia, how would you show me you respected and valued my viewpoint? How would you make sure I trusted you?", "Cardiff", 2016, "personal", "service_user", "vignette")
q("Aneurin Bevan wrote about the NHS. What are three things you think are worth fighting for?", "Cardiff", 2016, "personal", "policy_context")
q("In what way have your experiences prepared you for training?", "Cardiff", 2016, "personal", "motivation")
q("How do you think working in rural and urban areas would help you be a better psychologist?", "Cardiff", 2016, "personal", "diversity")
q("Why do you think the developmental approach in psychology is important?", "Cardiff", 2016, "academic", "professional_identity")
q("The Samaritans reported a rise in young male suicides in rural areas. How would you find out why? How would you design your research if you already had your hypothesis?", "Cardiff", 2016, "academic", "research_design", "vignette")
q("You can help 4 people to an 80% improvement, or 8 people to 40%. Discuss.", "Cardiff", 2016, "academic", "ethics_clash")
q("Tell me about your weakness in research.", "Cardiff", 2012, "academic", "research_own", "60s")
q("Much is written about positive psychology — what do you think the implications are for clinical psychologists?", "Cardiff", 2012, "academic", "professional_identity")
q("Role-play: you are a clinical psychologist in a brand new learning disabilities multidisciplinary team. What would the clinical psychologist bring to the team?", "Cardiff", 2012, "clinical", "professional_identity", "roleplay")
q("What is the difference between working as a clinical psychologist in Wales as opposed to England?", "Cardiff", 2012, "clinical", "policy_context")
q("Talk about the letter-writing exercise. How did you feel it went? On reflection what would you do better, and what would you change?", "Cardiff", 2012, "clinical", "reflective_personal")
q("What can a clinical psychologist do to support a carer?", "Cardiff", 2012, "personal", "service_user")
q("What are the benefits and difficulties you would perceive of having service users and patients involved in services, service design or clinical training?", "Cardiff", 2012, "personal", "service_user")
q("What are your beliefs and values about service user involvement?", "Cardiff", 2012, "personal", "service_user")
q("A carer of a patient with the first signs of degenerative dementia contacts you because the patient is refusing to go to a neurological testing appointment for diagnosis. How would you handle that situation?", "Cardiff", 2012, "personal", "ethics_clash", "vignette")
q("Talk about a paper you have read recently that has influenced your practice, and how this could be applied in the wider sense of the profession.", "Cardiff", 2012, "academic", "critical_appraisal")

# ---- Birmingham
q("How would you ensure the study was worthwhile?", "Birmingham", 2019, "written", "research_design")
q("You are designing a research study to evaluate a cognitive-behavioural intervention for children and young people experiencing anxiety. What design would you use?", "Birmingham", 2019, "written", "research_design", "vignette")
q("How would you find out if it had been effective or ineffective?", "Birmingham", 2019, "written", "research_design")
q("What other factors would you consider?", "Birmingham", 2019, "written", "research_design")
q("How would you find out the scientific merit of a randomised controlled trial for a psychological therapy?", "Birmingham", 2019, "academic", "critical_appraisal")
q("Consider links between childhood adverse events and adult wellbeing. Name three psychological theories and how they exert their influence.", "Birmingham", 2019, "academic", "model_switch")
q("There are many reasons people want to train as a clinical psychologist. How have your personal experiences, both positive and negative, led you to clinical psychology?", "Birmingham", 2019, "personal", "motivation")
q("What does stigma mean to you, and how would your values address this as a clinical psychologist?", "Birmingham", 2019, "personal", "diversity")
q("A friend tells you they are worried about you and they think you seem to be struggling. What do you say or do?", "Birmingham", 2019, "personal", "reflective_personal", "vignette")
q("What can clinical psychology offer for university students with stress?", "Birmingham", 2019, "clinical", "professional_identity")
q("You have picked up a referral to work with an unaccompanied child seeking asylum, placed in a foster home. The family have expressed concerns as the child is behaving aggressively. What factors do you consider?", "Birmingham", 2019, "clinical", "model_switch", "vignette")
q("Name a psychological model. [Then, only after you answer:] Now name a DIFFERENT psychological model and explain how you would use it to formulate with a client experiencing depression or anxiety.", "Birmingham", 2019, "clinical", "model_switch")
q("How have you used CBT before with a client?", "Birmingham", 2018, "clinical", "clinical_case")
q("You've been seeing a client for some time and are starting to feel stuck. What factors might you consider?", "Birmingham", 2018, "clinical", "stuck")
q("A client messaged you on social media saying they're feeling suicidal. What would you do?", "Birmingham", 2018, "clinical", "risk_live", "vignette")
q("How do you deal with diversity and differences, including deafness?", "Birmingham", 2018, "personal", "diversity")
q("Do you think psychologists need therapy?", "Birmingham", 2018, "personal", "reflective_personal")
q("Can you tell me how your experiences have shaped you?", "Birmingham", 2018, "personal", "motivation")
q("Detail a piece of research you've been heavily involved in — literature, methods, results, discussion.", "Birmingham", 2018, "academic", "research_own")
q("What is experience sampling methodology, and what are its strengths and weaknesses?", "Birmingham", 2018, "academic", "research_design")
q("Can you define abnormality, what factors it may affect, and the implications?", "Birmingham", 2018, "academic", "professional_identity")

# ---- Coventry & Warwick
q("How would you perform a systematic literature review if looking into the effectiveness of mindfulness-based interventions for anxiety?", "Coventry & Warwick", 2018, "academic", "systematic_review")
q("How would you measure the quality of the literature?", "Coventry & Warwick", 2018, "academic", "systematic_review")
q("Can you talk about a piece of research you have been involved in — design, strengths, limitations?", "Coventry & Warwick", 2018, "academic", "research_own")
q("Can you talk about an article you have read that has influenced you?", "Coventry & Warwick", 2018, "academic", "critical_appraisal")
q("[Handed an abstract: an RCT of CBT and/or befriending control for older women with anxiety, 1–2 minutes to read.] What are the strengths of this study? Limitations? What can you tell us about the effect size?", "Coventry & Warwick", 2018, "academic", "critical_appraisal", "vignette")
q("What type of research do you prefer?", "Coventry & Warwick", 2018, "academic", "research_own", "60s")
q("What has brought you to clinical psychology?", "Coventry & Warwick", 2018, "clinical", "motivation")
q("If you were to receive a 360-degree appraisal containing feedback about you from your colleagues and supervisor, what would it say?", "Coventry & Warwick", 2018, "clinical", "reflective_personal")
q("What qualities and skills do you feel are important as a leader? Which of these do you have, and what would you need to work on in training?", "Coventry & Warwick", 2018, "clinical", "leadership")
q("Can you talk about a time you felt out of your depth?", "Coventry & Warwick", 2018, "clinical", "stuck")
q("[After a video of siblings disagreeing about placing their mother in a care home:] What did you think and feel watching this? Who could you relate to more?", "Coventry & Warwick", 2018, "clinical", "reflective_personal", "vignette")
q("[After a 10-minute recorded therapy session:] What do you think the client is feeling and experiencing? What do you think the therapist is feeling and experiencing? Write out a formulation of the client's difficulties that a layman would understand.", "Coventry & Warwick", 2018, "written", "formulation_layperson", "vignette")
q("The role of service users in developing clinical psychology training programmes.", "Coventry & Warwick", 2018, "group", "service_user", "group")
q("The need for personal therapy during training. Is it essential?", "Coventry & Warwick", 2018, "group", "reflective_personal", "group")

# ---- Glasgow
q("Can you talk about a piece of research you have completed — the findings, strengths and limitations, and what you would do differently with hindsight?", "Glasgow", 2018, "academic", "research_own")
q("[Vignette on reducing substance use behaviours in mental health settings:] What type of research? How would you design your research question? What are the ethical considerations?", "Glasgow", 2018, "academic", "research_design", "vignette")
q("Can you talk about a paper or article you have learned lessons from, and how you can share these?", "Glasgow", 2018, "academic", "critical_appraisal")
q("What are the key skills and knowledge needed as a clinical psychologist? How has your experience prepared you for this?", "Glasgow", 2018, "clinical", "professional_identity")
q("Can you talk about a government policy and how this impacts on clinical psychology — for example, austerity?", "Glasgow", 2018, "clinical", "policy_context")
q("[Reading a BPS statement about respect and integrity:] Can you tell us about a time you have shown respect and integrity?", "Glasgow", 2018, "clinical", "reflective_personal")
q("A colleague has received negative feedback about their timekeeping from your line manager and is unhappy about it. Establish the circumstances and understand their reaction. You are not expected to resolve the problem.", "Glasgow", 2018, "roleplay", "roleplay_prep", "roleplay")
q("A colleague could not attend a team meeting and has just heard that the team leader re-allocated one of their tasks. They are unhappy about this.", "Glasgow", 2018, "roleplay", "roleplay_prep", "roleplay")
q("A colleague has been asked to attend an overnight meeting at short notice by your line manager. They feel unable to say no and are worried about giving a poor impression.", "Glasgow", 2018, "roleplay", "roleplay_prep", "roleplay")
q("A colleague has received feedback from their manager which has affected their decision to apply for a new post. They are uncertain whether to apply and worried about rejection.", "Glasgow", 2018, "roleplay", "roleplay_prep", "roleplay")

# ---- Exeter
q("Why do you want to be a clinical psychologist?", "Exeter", 2012, "clinical", "motivation", "60s")
q("How do you think the new Health and Social Care Bill will affect services? And the role of clinical psychology?", "Exeter", 2012, "clinical", "policy_context")
q("What does diversity mean? What implications does this have for clinical psychology?", "Exeter", 2012, "clinical", "diversity")
q("What do you understand by resilience? Talk about a time your resilience was high. Talk about a time your resilience was low.", "Exeter", 2012, "clinical", "reflective_personal")
q("What do you think service users expect from clinicians?", "Exeter", 2012, "clinical", "service_user")
q("Our research interests here are neuropsychology and low mood. How do you think you would fit in here with this?", "Exeter", 2012, "academic", "motivation")
q("What do you think leadership is? What skills do you think you would need to be a good leader?", "Exeter", 2012, "clinical", "leadership")
q("What was your IV and your DV? What were the problems of the research? What are the theoretical implications? How would you extend this research?", "Exeter", 2012, "academic", "research_own")
q("How would you go about investigating the impact of parental intervention on the anxiety levels of the child? What measures would you use? What statistics would you consider, and why?", "Exeter", 2012, "academic", "research_design", "vignette")
q("[Scenario: the mother of a teenage boy you have seen for a year rings, distressed — he has disappeared and may be with an uncle she describes as irresponsible. You have a session with the boy later that day.] How do you manage this? [Then: at the appointment he is in the waiting room with a man in his twenties.] How do you manage this? If, despite your best efforts, the man raised his voice and made others uncomfortable, how might this make you feel?", "Exeter", 2012, "clinical", "risk_live", "vignette")
q("How would you juggle the demands and manage the pressures of the course?", "Exeter", 2012, "clinical", "motivation")
q("If a colleague on the course had failed an assessment and was thinking of quitting to go travelling, and asked your advice, what would you say?", "Exeter", 2012, "clinical", "roleplay_prep", "vignette")
q("[Video of a service user's experience of depression, with that person in the room:] Why do you think I found couples therapy more helpful than individual therapy? What do you think my experience of having suicidal thoughts was? What would someone experiencing depression for the first time understand by 'recovery'? Why do you think I have not got better despite lots of therapy and medication — and how do you think that would feel?", "Exeter", 2013, "group", "group_task", "group")
q("Tell us about a piece of completed research you have undertaken. What were the strengths and limitations? What would you do differently? What was the theory underlying your research?", "Exeter", 2013, "academic", "research_own")
q("[Ethical scenario, chosen from three, read beforehand: a colleague contacts you for advice because a client they are seeing for depression has disclosed that he assisted his mother's suicide.] What do you think the issues are for you, your colleague, and the client? What would you do? [Then: the client is now caring for a terminally ill father with much guilt about his mother.] [Then: the client's sister turns up angry, wanting to complain about you.]", "Exeter", 2013, "clinical", "ethics_clash", "vignette")
q("How do you experience stress? How do you manage stress?", "Exeter", 2013, "clinical", "reflective_personal")
q("Talk about a problem you experienced. How did you manage it? How did you feel?", "Exeter", 2013, "clinical", "reflective_personal")
q("You and a friend both get onto clinical psychology training. Your friend struggles, feels stressed and wants to drop out. What would you say to them?", "Exeter", 2013, "clinical", "roleplay_prep", "vignette")
q("Talk about an experience of multidisciplinary team working. What skills did you need?", "Exeter", 2013, "clinical", "professional_identity")
q("Describe a piece of academic or service-related research you have been involved in. Discuss the implications, outcomes and challenges of relating this to the modern-day NHS.", "Exeter", 2011, "academic", "research_own")
q("Talk about a time you have shown resilience in your personal or professional life. What did you learn? What skills did you need?", "Exeter", 2011, "clinical", "reflective_personal")
q("What is your understanding of the scientist-practitioner model? Talk about a time you have used it. Do you have any criticisms of the model?", "Exeter", 2011, "clinical", "professional_identity")
q("Describe a time you have been criticised when you did not agree with the criticism. What did you do? What did you learn from it?", "Exeter", 2011, "clinical", "reflective_personal")
q("Talk about a paper, publication or book you have read recently. How would it affect the role of a clinical psychologist?", "Exeter", 2011, "academic", "critical_appraisal")
q("Do you think you have influenced somebody? Talk about a time you have influenced somebody.", "Exeter", 2011, "clinical", "leadership")

# ---- Plymouth
q("[Scenario: developing training for inpatient staff working with learning disability populations, including a focus group with patients and carers.] How would you prepare for this work? What issues may come up for you, staff, patients and carers? What psychological theories or knowledge would you draw on? How would you evaluate the training?", "Plymouth", 2013, "clinical", "professional_identity", "vignette")
q("[Having read a BPS document on community approaches to care:] What would the role of the clinical psychologist be within this project? What are the strengths and potential barriers to working in this way?", "Plymouth", 2013, "clinical", "professional_identity")
q("Talk about a challenging time or experience. How did you manage this? What skills did you need?", "Plymouth", 2013, "clinical", "reflective_personal")
q("Give an example of adapting your practice to the needs of a diverse population. How do you think your values and background may affect practice?", "Plymouth", 2013, "clinical", "diversity")
q("[Scenario: a consultant asks you as a trainee to design a study exploring the efficacious components of an intervention in an older adult service.] Who would you consult with before beginning? What methodology would you use? What are the limitations of this approach? How would you communicate your results?", "Plymouth", 2013, "academic", "research_design", "vignette")
q("What is practice-based evidence?", "Plymouth", 2013, "academic", "professional_identity", "60s")
q("What do you understand by reflection? Give an example of reflective practice within your practice.", "Plymouth", 2013, "clinical", "reflective_personal")
q("Talk about a clinical case you have worked on. What theory underlies it? What are the critiques of that theory?", "Plymouth", 2013, "clinical", "clinical_case")
q("[Vignette, 15 minutes' preparation: you are leading a team creating psychological support for carers of people with dementia.] What would your first steps be? Who would you consult? What form would your intervention take? What are your hopes and fears for this intervention? Are there any ethical implications?", "Plymouth", 2014, "clinical", "professional_identity", "vignette")
q("Describe a situation where you felt there was a clash of ethics. How did you deal with this? What did you learn?", "Plymouth", 2014, "clinical", "ethics_clash")
q("[Having read the Berwick report (2013):] What did you feel was the most important aspect of this report? How would you disseminate this point to the service you work for?", "Plymouth", 2014, "clinical", "policy_context")
q("[Research vignette: a well-regarded bereavement support unit for families who have lost a child or sibling. You could explore the cycle of change during therapy, the interactions with the clinician, the group dynamics of the family, or the milestones of each service user.] Who would you discuss these ideas with first? Which area would you focus on and why? What method would you use? What sample size? What are the potential implications of this type of research?", "Plymouth", 2014, "academic", "research_design", "vignette")

# ---- Southampton
q("Talk about a piece of research you have been involved in. What would you do differently? What are the limitations? What are the implications?", "Southampton", 2012, "academic", "research_own")
q("At Southampton we value self-management and self-learning. Can you give examples from your practice that demonstrate self-initiative? What are the pros and cons of working in this way, and the difficulties?", "Southampton", 2012, "academic", "reflective_personal")
q("Talk about a clinical piece of work you undertook under supervision.", "Southampton", 2012, "clinical", "clinical_case")
q("How would you build a therapeutic relationship with a client?", "Southampton", 2012, "clinical", "engagement")
q("How do you self-manage your time in a busy clinical environment?", "Southampton", 2012, "clinical", "reflective_personal", "60s")
q("Talk about a time you received academic feedback and how this has influenced your practice.", "Southampton", 2013, "academic", "reflective_personal")
q("Clinical psychologists have to work with many different professionals. Can you give examples of this, and what helped?", "Southampton", 2013, "clinical", "professional_identity")
q("The therapeutic relationship is a significant part of interventions. How would you build a relationship with someone who is silent?", "Southampton", 2013, "clinical", "engagement")
q("Describe a piece of clinical work you have had with a client. What did you do? How did you plan the intervention? Were there any hurdles? What psychological theory is this linked to?", "Southampton", 2015, "clinical", "clinical_case")
q("Describe a time you have felt there was a clash of ethical interests.", "Southampton", 2015, "clinical", "ethics_clash")
q("Describe an example of appropriate use of clinical supervision.", "Southampton", 2015, "clinical", "supervision_use")
q("Describe a piece of research you have undertaken. Why did you choose this method? What informed this choice? What would you have done differently in hindsight? How could you operationalise these changes? In what way would this have improved the research? What psychological theory does this work support?", "Southampton", 2015, "academic", "research_own")
q("[Role-play: you are a college counsellor about to see a student struggling with exam stress. No intervention is expected — this is about engagement and brief assessment and formulation.] Afterwards: what was the presenting issue? How could you see the intervention moving forward? Was there anything about your performance you felt could be improved?", "Southampton", 2015, "roleplay", "roleplay_prep", "roleplay")

# ---- South Wales
q("The application form can be quite constricting. What would you like to add to your application?", "South Wales", 2015, "personal", "motivation")
q("Why do you want to train in Wales? Why this course?", "South Wales", 2015, "personal", "motivation")
q("What do you think the written task was trying to assess?", "South Wales", 2015, "personal", "reflective_personal")
q("What's the difference between having a supervisor and a mentor?", "South Wales", 2015, "personal", "supervision_use", "60s")
q("It can be distressing for people to come and see a clinical psychologist. How would you handle other people's distress?", "South Wales", 2015, "personal", "engagement")
q("How do you work with difference and diversity?", "South Wales", 2015, "personal", "diversity")
q("Who can clinical psychology support more — service users or carers?", "South Wales", 2015, "personal", "service_user")
q("What is a clinical psychologist's role in integrating care?", "South Wales", 2015, "personal", "professional_identity")
q("What can clinical psychology do in the face of austerity?", "South Wales", 2015, "personal", "policy_context")
q("Tell us about your current role. What skills do you think a clinical psychologist needs?", "South Wales", 2015, "clinical", "professional_identity")
q("What psychological theory are you most drawn to, and why?", "South Wales", 2015, "clinical", "model_switch")
q("What will the impacts be to psychology if we don't find time to do research?", "South Wales", 2015, "clinical", "policy_context")
q("How do we overcome the challenges to implementing the evidence base?", "South Wales", 2015, "clinical", "policy_context")
q("Think about something you have seen in the media recently. How would you choose to report it, and can you link it to a psychological theory?", "South Wales", 2015, "clinical", "policy_context")
q("How do you demonstrate your value?", "South Wales", 2015, "clinical", "professional_identity")

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "trainer", "data", "interview.json")
concepts = {c["id"] for c in json.load(open(os.path.join(os.path.dirname(OUT), "concepts.json")))["nodes"]}
for t in THEMES.values():
    for c in t["concepts"]:
        assert c in concepts, f"theme {t['id']} -> unknown concept {c}"
for item in Q:
    assert item["theme"] in THEMES, f"{item['id']} -> unknown theme {item['theme']}"
json.dump({"version": 1, "themes": list(THEMES.values()), "questions": Q},
          open(OUT, "w"), indent=1, ensure_ascii=False)
from collections import Counter
print(f"{len(THEMES)} themes, {len(Q)} verbatim questions -> {OUT}")
print("by course:", dict(Counter(x["course"] for x in Q)))
print("by panel :", dict(Counter(x["panel"] for x in Q)))
print("by mode  :", dict(Counter(x["mode"] for x in Q)))
tc = Counter(x["theme"] for x in Q)
print("theme freq:", tc.most_common())
