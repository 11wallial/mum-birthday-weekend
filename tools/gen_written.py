# -*- coding: utf-8 -*-
"""Written-exercise simulator content.

The Birmingham 2014 exercise is transcribed from the official marking scheme
supplied with the paper: every rubric point below is a marker's bullet, with its
official weighting. Detection cues are authored so free text can be matched
against each point; the learner then confirms or overrides each award, which is
itself the intervention (comparing your own answer against a marking scheme is
the highest-yield use of a past paper).
"""
import json, os

EX = []

def cues(*c):
    return list(c)

# =====================================================================
# BIRMINGHAM 2014 — official marking scheme, 44 points
# =====================================================================
b14_stimulus = [
 {"t": "h", "v": "Mindfulness Group Intervention for people with Crohn's Disease: a pilot study"},
 {"t": "p", "v": "Crohn's disease is a long-term condition, affecting all age groups, that causes inflammation of the lining of the digestive system. Inflammation can affect any part of the digestive system, and common symptoms include: diarrhoea; severe abdominal pain; fatigue; unintended weight loss; blood and mucus in the stools."},
 {"t": "p", "v": "People with Crohn's disease can go for long periods without symptoms, or with very mild symptoms. This is known as remission. However, remission can be followed by periods where symptoms flare up. The condition is managed by changes to the diet, including eating a low fibre diet, although this is not helpful for all people with the condition. Medication, such as steroids, is often prescribed during a flare up, and surgery to remove damaged parts of the gut is common. The cyclical nature of the disease and the potential severity of symptoms mean that for some, managing the condition can be challenging."},
 {"t": "p", "v": "Gastroenterologists recognise the psychosocial implications of Crohn's Disease and have been working with clinical psychologists to develop a group intervention for adults struggling to manage the condition. In a recent study, a group intervention was developed based on the principles of Mindfulness (e.g. Kabat-Zinn, 1990), which included 6 sessions lasting 90 minutes each, over 12 weeks. It covered psycho-education, breathing, meditation, mindful activity and using mindfulness to cope with negative experiences."},
 {"t": "p", "v": "Adult patients with severe Crohn's disease were assigned to either a mindfulness group (MFG; N = 24) or a “treatment as usual” condition (TAU; N = 24). Patients attending the group were assessed before the group commenced (time 1) and at the end of the 6 sessions (time 2). The TAU patients were assessed on the same measures at similar time points."},
 {"t": "p", "v": "Mindfulness was measured using the Mindful Attention Awareness Scale (MAAS); mood was measured using the Depression, Anxiety & Stress Scale (DASS); and quality of life was measured using the newly developed Crohn's Disease Questionnaire (CrDQ; Howard 2014). The CrDQ was adapted for this study from the existing Coeliac Disease Questionnaire (CDQ; Hauser et al., 2007). As the CrDQ was a new measure, the researchers explored this for internal reliability using Cronbach's alpha."},
 {"t": "table", "caption": "Table 1 — Cronbach's alpha for each measure",
  "head": ["Measure", "α"], "rows": [["DASS", ".87"], ["MAAS", ".85"], ["CrDQ", ".40"]]},
 {"t": "table", "caption": "Table 2 — Mean scores and t values for DASS, Mindfulness Group",
  "head": ["", "Time 1 (n=24)", "Time 2 (n=15)", "t1 vs t2"],
  "rows": [["Depression", "3.33", "3.85", "t = 4.78"], ["Anxiety", "4.05", "2.45", "t = 6.19*"],
           ["Stress", "4.63", "2.12", "t = 5.59*"], ["Total", "12.01", "8.42", "t = 5.75**"]],
  "note": "Higher scores indicate poorer well-being; * p<0.05; ** p<0.01"},
 {"t": "table", "caption": "Table 3 — Mean scores and t values for DASS, TAU condition",
  "head": ["", "Time 1 (n=24)", "Time 2 (n=20)", "t1 vs t2"],
  "rows": [["Depression", "4.52", "4.72", "t = 4.41"], ["Anxiety", "5.63", "3.15", "t = 6.69*"],
           ["Stress", "5.86", "6.33", "t = 4.24"], ["Total", "16.01", "14.2", "t = 5.16"]],
  "note": "Higher scores indicate poorer well-being; * p<0.05; ** p<0.01"},
 {"t": "table", "caption": "Table 4 — Mean scores for all measures, and t values comparing groups at each time point",
  "head": ["", "T1 MFG", "T1 TAU", "t", "T2 MFG", "T2 TAU", "t"],
  "rows": [["n", "24", "24", "", "15", "20", ""],
           ["DASS total", "12.01", "16.01", "6.19**", "8.42", "14.20", "5.68*"],
           ["MAAS total", "2.34", "2.03", "8.50", "8.23", "3.00", "7.54**"],
           ["CrDQ total", "13.71", "15.02", "5.56", "14.50", "16.50", "4.97"]],
  "note": "MAAS: higher = better mindfulness & self-compassion. CrDQ: higher = better quality of life. * p<0.05; ** p<0.01"},
]

b14_q = [
 {"id": "q1", "marks": 7,
  "prompt": "From the information provided about Crohn's Disease, what do you think the main psychosocial issues are for people with Crohn's Disease, and how might people feel as a result of this diagnosis and its management?",
  "guidance": "The marking scheme is explicit: a list of practical considerations scores nothing. Each point must connect a feature of the condition to a psychosocial consequence AND to how the person might feel.",
  "rubric": [
    ("r1", "Diagnosis of a long-term condition → issues around acceptance and self-esteem", 1,
     cues(r"long[- ]?term|chronic|lifelong|life.?long", r"accept|adjust|identity|self.?esteem|self.?worth"), "core"),
    ("r2", "Unpredictability / cyclical nature → loss of control, anxiety (especially social), low mood, anger, frustration", 1,
     cues(r"unpredictab|cyclical|flare|uncertain|fluctuat", r"control|anxiet|anxious|frustrat|anger|helpless|hypervigil"), "core"),
    ("r3", "Dietary self-management → social anxiety away from home, avoidance of eating out, loss of social life, temptation and loss of control", 1,
     cues(r"diet|food|eating|low fibre|meal", r"social|eat(ing)? out|restaurant|isolat|avoid"), "core"),
    ("r4", "Medication / steroid side effects → weight gain, body image, self-esteem; non-adherence → poorer symptom control", 1,
     cues(r"steroid|medication|drug", r"side.?effect|weight gain|body image|appearance|adherence|complian"), "core"),
    ("r5", "Impact on work and home life → loss of roles, reduced quality of life, effect on mood and self-esteem", 1,
     cues(r"work|employ|job|home life|role", r"loss|role|quality of life|identity|financ|mood"), "core"),
    ("r6", "Managing unpleasant symptoms (e.g. proximity to a toilet) → anxiety away from home, avoidance, social isolation", 1,
     cues(r"toilet|incontinen|diarrhoea|urgency|accident", r"anxiet|avoid|isolat|embarrass|shame|humiliat"), "core"),
    ("r7", "Poor pain control → low mood, inability to work or exercise, further low mood, weight gain, poor self-esteem", 1,
     cues(r"pain|fatigue|tired", r"mood|depress|exercise|activity|withdraw"), "core"),
  ],
  "traps": [(cues(r"^(?![\s\S]*(feel|felt|emotion|mood|anxiet|shame|anger|frustrat|distress|embarrass))"),
             "The scheme requires you to say how the person might FEEL. Points that name only a practical consequence do not score."),
            (cues(r"\bdiagnos(is|e)d? with (depression|anxiety)\b"),
             "Careful — the question asks about psychosocial issues and feelings, not about assigning a psychiatric diagnosis.")],
  "model": "Crohn's is a long-term, relapsing condition, so the first psychosocial task is one of adjustment: people face an identity shift from healthy to chronically ill, which commonly threatens self-esteem and provokes grief for a previous self. Because remission and flare-up alternate unpredictably, people cannot plan; that unpredictability tends to generate a sense of lost control, anticipatory anxiety and frustration, and for some a hypervigilance to bodily sensation that amplifies distress. Dietary management adds a social dimension: restricting food makes eating out and shared meals difficult, so people may begin to avoid social occasions, with consequent isolation and low mood, alongside the frustration of watching others eat freely and the guilt that follows breaking the diet. Steroid treatment carries visible side effects such as weight gain and changes in appearance, which can affect body image and self-esteem, and may lead some people to take medication inconsistently and so lose symptom control. Symptoms themselves are stigmatising and hard to talk about; needing to be near a toilet generates anxiety away from home, embarrassment and shame, and avoidance of work, travel and social contact. Pain and fatigue limit activity and employment, which removes valued roles and reinforces low mood, and for some raises financial worry. Across all of these, the common emotional threads are anxiety, shame and embarrassment, anger and frustration at the unpredictability, and low mood arising from cumulative loss of role and social contact."},

 {"id": "q2", "marks": 8,
  "prompt": "From the data and statistical analysis available, what can you conclude about any changes WITHIN groups?",
  "guidance": "Read Tables 2 and 3 only. Within-group means: time 1 compared with time 2, inside each condition separately. Note which t values carry asterisks.",
  "rubric": [
    ("r1", "MF group: significant improvement in anxiety", 1, cues(r"(mindful|mfg|mf group|intervention group)[\s\S]{0,160}anxiet|anxiet[\s\S]{0,80}(significan|improv)"), "core"),
    ("r2", "MF group: significant improvement in stress", 1, cues(r"stress[\s\S]{0,80}(significan|improv|reduc|fell|decreas)"), "core"),
    ("r3", "MF group: significant improvement in overall DASS total", 1, cues(r"(total|overall)[\s\S]{0,80}(significan|improv|reduc)"), "core"),
    ("r4", "MF group: NO significant change in depression", 1, cues(r"depress[\s\S]{0,90}(no |not |non.?signif|did not|unchanged|failed)"), "core"),
    ("r5", "Attrition in MF group: 24 → 15, so 9 dropped out; OR attrition much higher in MFG than TAU; OR the resulting bias (any one such comment scores the single point)", 1,
     cues(r"(24|twenty.?four)[\s\S]{0,40}(15|fifteen)", r"\b9\b[\s\S]{0,40}(drop|withdrew|left|lost)", r"attrit", r"drop.?out|dropped out"), "core"),
    ("r6", "TAU group: significant improvement in anxiety", 1, cues(r"(tau|treatment as usual|control)[\s\S]{0,160}anxiet"), "core"),
    ("r7", "TAU group: no significant change in depression or stress", 1, cues(r"(tau|control)[\s\S]{0,200}(depress|stress)[\s\S]{0,80}(no |not |non.?signif|unchanged)"), "core"),
    ("r8", "TAU group: no significant change in DASS total; and TAU attrition 24 → 20 (4 lost), with possible bias", 1,
     cues(r"(20|twenty)[\s\S]{0,40}(tau|control)", r"\b4\b[\s\S]{0,40}(drop|lost|withdrew)", r"(tau|control)[\s\S]{0,120}(total)[\s\S]{0,60}(no|not|non.?signif)"), "core"),
  ],
  "traps": [(cues(r"between (the )?groups?|compared (the |to )?tau (with|to|and) (the )?mindful"),
             "This question is about WITHIN-group change only. Between-group comparison is question 3 — material placed under the wrong question is not credited."),
            (cues(r"\bproves?\b|\bshows? that mindfulness works\b|\bcaused\b"),
             "Overclaiming. Within-group change in an uncontrolled comparison cannot establish that the intervention caused anything.")],
  "model": "Within the mindfulness group, anxiety and stress both improved significantly between time 1 and time 2, as did the DASS total score, but depression did not change significantly — indeed the depression mean rose slightly, from 3.33 to 3.85. Within the TAU condition, anxiety also improved significantly, while depression, stress and the DASS total did not. Two observations qualify all of this. First, the means are computed on different numbers of people at each time point: the mindfulness group falls from 24 to 15, so nine participants are unaccounted for, while TAU falls only from 24 to 20. The attrition is therefore both substantial and markedly unequal across conditions. Second, that pattern makes the within-group figures difficult to interpret, because the 15 people contributing to the time 2 mean are not the same sample as the 24 who contributed at time 1. Those who left may have been faring worse and found the intervention too demanding, in which case the apparent improvement is partly a selection artefact; alternatively they may have improved quickly and stopped attending, which would understate the benefit. Either way, the time 2 mean describes a self-selected subgroup, and the improvement in anxiety seen in both arms should also caution us that change over time here is not specific to mindfulness."},

 {"id": "q3", "marks": 7,
  "prompt": "From the data and statistical analysis available, what can you conclude about any differences BETWEEN groups?",
  "guidance": "Table 4. Look at baseline as well as follow-up — the marking scheme rewards noticing what was already true before the intervention began.",
  "rubric": [
    ("r1", "Caution in interpreting between-group differences because the study is under-powered, which can inflate sample means", 1,
     cues(r"under.?power|small sample|insufficient(ly)? power|lack of power|low power|not powered"), "core"),
    ("r2", "The groups already differed on DASS total at time 1 — TAU were more symptomatic / the intervention was given to a less symptomatic group (one point only, even if both stated)", 1,
     cues(r"(baseline|time 1|t1|outset|start)[\s\S]{0,140}(differ|not (equivalent|comparable|matched)|higher|worse|more (symptomatic|distress|stress))",
          r"(12\.01|16\.01)[\s\S]{0,60}(differ|higher|baseline)"), "core"),
    ("r3", "TAU showed more depression than the MF group at time 2", 1, cues(r"(time 2|t2|post|follow.?up)[\s\S]{0,140}depress"), "core"),
    ("r4", "Both groups decreased in DASS symptom severity, but significantly so only for the mindfulness group", 1,
     cues(r"both (groups?|arms?|conditions?)[\s\S]{0,120}(decreas|reduc|improv|fell)"), "core"),
    ("r5", "The groups were comparable at baseline on the other two measures (MAAS and CrDQ)", 1,
     cues(r"(maas|craq|crdq|mindfulness (score|measure)|quality of life)[\s\S]{0,120}(comparable|no (significant )?difference|similar|equivalent)[\s\S]{0,60}(baseline|time 1|t1)",
          r"(baseline|time 1|t1)[\s\S]{0,120}(maas|crdq)[\s\S]{0,80}(comparable|no (significant )?difference|similar)"), "core"),
    ("r6", "The MF group showed greater mindfulness than TAU at time 2", 1,
     cues(r"(maas|mindfulness)[\s\S]{0,140}(time 2|t2|post|greater|higher|increas)"), "core"),
    ("r7", "There was no difference between groups on quality of life at time 2", 1,
     cues(r"(quality of life|crdq|qol)[\s\S]{0,140}(no (significant )?difference|not signif|unchanged|no effect)"), "core"),
  ],
  "traps": [(cues(r"randomis|randomiz"),
             "The stimulus says patients were 'assigned' — it never says randomly. Assuming randomisation is the error that makes the baseline difference invisible to you.")],
  "model": "The first thing to establish is that the groups were not equivalent at the outset. On DASS total the TAU group scored 16.01 against the mindfulness group's 12.01, a significant difference at time 1, so the intervention was delivered to a group that was already less symptomatic. Since the paper says patients were 'assigned' rather than randomly allocated, this baseline imbalance may be systematic. On the other two measures, MAAS and CrDQ, the groups were comparable at baseline. At time 2 the mindfulness group scored lower on DASS total and specifically showed less depression than TAU, and showed significantly greater mindfulness on the MAAS. There was no significant between-group difference in quality of life at time 2. Both groups decreased in symptom severity over the period, but the decrease reached significance only in the mindfulness condition. All of these comparisons must be read cautiously, because with 15 and 20 participants at follow-up the study is clearly under-powered, and among under-powered comparisons those that do reach significance systematically overstate the size of the effect. Taken together, a difference at time 2 between two groups that already differed at time 1, in a small sample with unequal attrition, cannot be attributed to the intervention."},

 {"id": "q4", "marks": 6,
  "prompt": "Now summarise the main conclusions from the study. What do the results tell us about the mindfulness intervention?",
  "guidance": "The marking note is unusually direct: 'We can't really conclude very much from the data about the usefulness of the Mindfulness group, so award points when the candidate demonstrates that they understand this point.'",
  "rubric": [
    ("r1", "The improvement in MAAS scores suggests the group did succeed in teaching mindfulness", 1,
     cues(r"(maas|mindfulness (score|increas|improv))[\s\S]{0,140}(learn|taught|acquir|did increase|improved|suggests? the (group|intervention))"), "core"),
    ("r2", "The high attrition rate suggests the intervention may not be well suited to everyone with Crohn's disease", 1,
     cues(r"attrit|drop.?out", r"(not (well )?suited|acceptab|toleran|suit(able)? for (all|everyone)|may not suit)"), "core"),
    ("r3", "Although MFG appeared to do better on mood, the apparent improvement could simply reflect the different baseline scores", 1,
     cues(r"baseline|time 1|t1|started (lower|less)", r"(could|may|might) (simply |just )?(be|reflect|be because|be due)"), "core"),
    ("r4", "Any improvement must be read in the context of attrition bias — those who left may have been unsuited and unimproved; fewer left TAU, suggesting TAU may be more acceptable", 1,
     cues(r"(bias|those who (dropped|left)|selection)[\s\S]{0,200}(improv|unsuit|worse)", r"tau[\s\S]{0,120}(more acceptab|better tolerated|fewer (drop|left))"), "advanced"),
    ("r5", "Neither condition affected quality of life — but this may be because the CrDQ has poor internal reliability (α = .40), so the measure cannot be trusted (half marks if the reliability point is omitted)", 1,
     cues([r"quality of life|crdq", r"\.40|alpha|reliab"]), "core"),
    ("r6", "We cannot say anything with certainty about the relationship between mindfulness, mood and quality of life", 1,
     cues(r"cannot (say|conclude|be certain)|no firm conclusion|little can be concluded|tentative|cautious"), "core"),
  ],
  "traps": [(cues(r"the (intervention|group|mindfulness) (was |is )?(effective|works|helped)(?![\s\S]{0,80}(cannot|but|however|caution))"),
             "The marking note warns explicitly against this. Concluding the intervention worked is the single most costly error on this question.")],
  "model": "The clearest finding is that the group succeeded in teaching what it set out to teach: MAAS scores rose in the mindfulness condition and were significantly higher than TAU at time 2, so participants did become more mindful. Beyond that, very little can be concluded. The mindfulness group appeared to do better on mood, but they also began less symptomatic than TAU, so the time 2 difference may simply carry forward the time 1 difference. Nine of 24 participants left the mindfulness group, against four of 24 in TAU, which is itself a finding: it suggests the intervention may not be acceptable or suitable for everyone with Crohn's disease, and that TAU was better tolerated. It also means any apparent benefit is confounded with who chose to stay, since those who left may have been the people least suited to and least helped by the approach. Neither condition showed an effect on quality of life, but that null result cannot be interpreted, because the CrDQ has a Cronbach's alpha of .40 — well below acceptable — so the measure lacks the internal reliability required to detect change at all. Overall, this is a pilot that establishes the intervention can be delivered and does teach mindfulness, while telling us almost nothing reliable about whether it improves mood or quality of life."},

 {"id": "q5", "marks": 11,
  "prompt": "Bearing in mind this pilot study has a number of weaknesses, how would you build on this if you could design a follow-on study?",
  "guidance": "The marking note is explicit: a list of weaknesses scores nothing. Each point requires a SOLUTION, with the limitation stated or clearly implied by the solution.",
  "rubric": [
    ("r1", "No control for non-specific factors — add an appropriate placebo / active comparator", 1,
     cues([r"(control|comparator|placebo|active|attention.?matched|befriend)", r"(add|include|use|introduc|employ)"]), "core"),
    ("r2", "A qualitative study to understand acceptability of the intervention and adjust the protocol (only credited with a rationale)", 1,
     cues([r"qualitative|interview|focus group", r"acceptab|experience|why|understand|adjust|protocol"]), "core"),
    ("r3", "Acknowledge attrition at each stage, or address recruitment and use an appropriate analysis for missing data", 1,
     cues(r"missing data|imputation|multiple imputation|intention.?to.?treat|itt|consort|flow (diagram|chart)|account for (drop|attrition)"), "core"),
    ("r4", "Recognise this is essentially a feasibility study — a larger definitive trial would use intention-to-treat analysis", 1,
     cues(r"feasibilit|definitive trial|fully powered|full trial|scale up|larger (rct|trial)"), "core"),
    ("r5", "Recruit a larger sample", 1, cues(r"larger sample|bigger sample|increase (the )?sample|more participants|power calculation|a priori power"), "core"),
    ("r6", "Randomly allocate, so that groups should not differ at baseline", 1,
     cues([r"random(ly|is|iz)", r"(allocat|assign|group|baseline)"]), "core"),
    ("r7", "In a larger study, monitor and measure treatment fidelity", 1,
     cues(r"fidelit|adherence to (the )?protocol|treatment integrity|manualis|supervis(ion|ed) of (the )?(therapist|facilitator)"), "core"),
    ("r8", "No measure of Crohn's severity — measure it to ensure groups are matched", 1,
     cues([r"severit|disease activity|symptom (level|burden)|flare|medical", r"match|measur|control|stratif|baseline"]), "core"),
    ("r9", "The CrDQ has low α — find a more suitable QoL measure, or validate it further in another pilot", 1,
     cues([r"crdq|quality of life measure|qol measure|\.40|reliab", r"(different|another|alternative|better|validated|psychometric|validate|develop)"]), "core"),
    ("r10", "No follow-up — add one to establish whether improvements are maintained", 1,
     cues(r"follow.?up|maintenance|maintained|longer.?term|3.month|6.month|durability"), "core"),
    ("r11", "Blind outcome assessment — separate the people collecting the data from those running the group", 1,
     cues(r"blind|independent assessor|separate (the )?(researcher|assessor|data collect)|masked"), "core"),
  ],
  "traps": [(cues(r"^(?![\s\S]*(would|could|should|add|include|use|recruit|random|measur|blind|follow))"),
             "The marker is instructed not to credit limitations without solutions. Every point needs a 'so I would…'.")],
  "model": "I would design a definitive randomised controlled trial, treating this study as the feasibility work it effectively is. Because the current design cannot separate mindfulness from attention, time and expectancy, I would add an active comparator matched for contact time and credibility — a structured support group, for instance — rather than TAU alone. Participants would be randomly allocated, which should remove the baseline imbalance in DASS scores that makes the present findings uninterpretable, and I would stratify on disease severity, which this study did not measure at all; without it we cannot know that the groups were comparable on the thing most likely to drive both mood and quality of life. Sample size would be set by an a priori power calculation based on the smallest difference that would matter clinically, with inflation for the attrition rate observed here. Given that nine of 24 participants left the mindfulness arm, I would first run a qualitative study of acceptability — interviewing both completers and, importantly, those who withdrew — so that the protocol could be adapted before scaling, since a trial of an intervention people will not attend answers the wrong question. In the trial itself, attrition would be reported at every stage on a CONSORT flow diagram, the primary analysis would be intention-to-treat, and missing data would be handled by multiple imputation rather than by dropping cases. Treatment fidelity would be monitored through recorded sessions rated against a manual. The CrDQ should not be used as it stands with an alpha of .40; I would either select an already-validated quality of life measure for inflammatory bowel disease or complete proper psychometric development of the CrDQ first. Outcome assessment would be conducted by researchers blind to allocation and independent of the people facilitating the groups. Finally, I would add follow-up at three and six months, because a pilot that measures only at the end of treatment cannot tell us whether anything is maintained."},

 {"id": "q6", "marks": 5,
  "prompt": "What are the main ethical issues arising from the current study, or from a future improved study?",
  "guidance": "The marking note is emphatic: generic answers such as anonymising data or obtaining ethics approval score nothing. Only issues specific to THIS study are credited.",
  "rubric": [
    ("r1", "Allocating people to a placebo or control condition may deprive them of a needed intervention", 1,
     cues([r"placebo|control (group|condition|arm)|waiting.?list|randomis", r"deprive|withhold|denied|not receiv|miss out"]), "core"),
    ("r2", "What if people are already receiving an intervention — do you stop it, or recruit only newly diagnosed people?", 1,
     cues([r"already (receiving|having|in)|existing (treatment|therapy)|concurrent|newly diagnosed", r"stop|withdraw|exclud|recruit"]), "core"),
    ("r3", "What if someone in the placebo group deteriorates — do you withdraw them, and at what point?", 1,
     cues([r"deteriorat|worsen|gets worse|decline", r"withdraw|remove|stopping rule|criteria|take them out"]), "core"),
    ("r4", "The measures themselves could cause distress", 1,
     cues([r"measure|questionnaire|dass|assessment|item", r"distress|upset|burden|intrusive|discomfort"]), "core"),
    ("r5", "Participants may be depressed and therefore at risk of suicidal ideation — this needs assessing, with support offered", 1,
     cues([r"suicid|risk|self.?harm|safeguard", r"assess|protocol|support|refer|pathway"]), "core"),
  ],
  "traps": [(cues(r"anonymis|anonymiz|confidentialit|data protection|gdpr|store(d)? securely|ethics (committee |board )?approval|informed consent form"),
             "The marking note names these explicitly as non-scoring. They apply to any study — the question asks what is ethically particular about THIS one.")],
  "model": "The ethical issues specific to this design begin with the comparator. If a future trial randomises people to a placebo or attention control, some will be knowingly allocated to a condition expected to be inert while they are struggling to manage a painful, unpredictable illness — which requires justification through genuine equipoise, and a clear offer of the intervention at the end of the trial. Related to this, many people with severe Crohn's will already be receiving psychological or psychiatric input; asking them to stop in order to enter a trial is not acceptable, so the protocol has to decide between recruiting only newly diagnosed or currently untreated participants, at some cost to generalisability, and permitting concurrent treatment and measuring it. There must also be a pre-specified rule for what happens if a participant in the control condition deteriorates — what threshold triggers withdrawal from the study and referral into care, and who monitors it — because without one that judgement falls to whoever notices. The measures themselves carry burden: the DASS asks directly about hopelessness and low mood, and completing it repeatedly can be distressing for someone whose illness is flaring. Since the sample is selected for difficulty coping with a chronic condition, a meaningful proportion may experience suicidal thoughts, so there needs to be a risk protocol specifying how responses are reviewed, by whom, within what timeframe, and what the route to support is — not simply a debrief sheet."},
]

EX.append({
 "id": "birm2014",
 "title": "Mindfulness for Crohn's Disease",
 "course": "Birmingham",
 "year": 2014,
 "minutes": 60,
 "totalMarks": 44,
 "provenance": "Transcribed from the Birmingham ClinPsyD written exercise 2014, supplied WITH ITS OFFICIAL MARKING SCHEME. Every rubric point below is a marker's bullet with its official weighting.",
 "brief": "You have the study description and results tables below. Answer all six questions. Marks are unequal — questions 5 and 3 carry the most.",
 "stimulus": b14_stimulus,
 "questions": [{"id": q["id"], "marks": q["marks"], "prompt": q["prompt"], "guidance": q["guidance"],
                "rubric": [{"id": r[0], "text": r[1], "weight": r[2], "cues": r[3], "tier": r[4]} for r in q["rubric"]],
                "traps": [{"cues": t[0], "msg": t[1]} for t in q["traps"]],
                "model": q["model"]} for q in b14_q],
 "debrief": ("Two structural lessons carry beyond this paper. First, the marking scheme awards points for CONSEQUENCES, "
             "not observations: on Q1 a psychosocial issue only scores when linked to a feeling, and on Q5 a limitation only "
             "scores when paired with a solution. Second, the study is designed so that the correct overall answer is 'we "
             "cannot conclude much' — and the markers are told to reward candidates who see this. Under time pressure the "
             "instinct is to find something positive to say about the intervention. Resisting that instinct is what the "
             "exercise is testing.")
})

# =====================================================================
# BIRMINGHAM 2018 — real paper, rubric reconstructed from the question wording
# =====================================================================
b18_stimulus = [
 {"t": "h", "v": "Intensive Interaction for people with profound learning disability"},
 {"t": "p", "v": "Intensive Interaction is a therapeutic approach for promoting social interaction in individuals with severe communication impairments. The therapist or carer observes what the person is doing, tries to understand the focus and motivation of the behaviour, and then 'joins in' by using the same movements, vocalisations and direction of eye gaze. The approach is inspired by observational research on parent-baby interactions. Matching the behaviours is thought to enable the person to recognise the therapist's behaviour as a response to their own, laying the foundation for mutual interaction."},
 {"t": "p", "v": "Mainwaring and Wilson (2015) evaluated Intensive Interaction with 10 individuals with profound learning disability and no apparent language ability, attending an adult day centre. The purpose and nature of the research was explained to staff in an oral presentation. Staff were asked at the end of the meeting to nominate suitable people to take part, and to sign a form indicating that they consented to the participation of the person they had nominated."},
 {"t": "p", "v": "The intervention consisted of a single 30-minute session with each participant. One of the researchers spent the first 5 minutes observing the participant, then over the next 25 minutes remained within 1 metre of the participant and within their field of vision, implementing Intensive Interaction. Videos were made of the sessions. One of the researchers coded participant behaviour: eye gaze (at the communication partner or away); bodily orientation (towards the partner or away); emotional valence (negative or positive; neutral was not coded). For each variable the percentage of time in a 5-minute period was calculated."},
 {"t": "p", "v": "To evaluate effectiveness, time spent in the first 5 minutes was compared with the last 5 minutes, and for each participant and variable it was determined whether there was an increase in social interaction, or whether time spent was the same or had declined. A general z-test was used to calculate whether the percentage of participants showing an increase was significantly above chance. It was assumed 50% would show an increase by chance, and alpha was set at .05. Someone not otherwise involved coded 10% of the videos: Cohen's kappa was 0.64 for eye gaze, 0.59 for body orientation and 0.32 for emotional valence."},
 {"t": "table", "caption": "Table 1 — Patterns of change between the first and last 5 minutes",
  "head": ["Variable", "Increase", "Decrease or no change", "z and p (two-tailed)"],
  "rows": [["Eye gaze", "9", "0", "z = 2.530; p = .020"],
           ["Bodily orientation", "8", "1", "z = 1.897; p = .056"],
           ["Emotional valence", "6", "4", "z = 0.632; p = .527"]]},
]

b18_q = [
 {"id": "q1", "marks": 6,
  "prompt": "What do you think were the methodological limitations of the study? In your answer, (a) state what the limitation is and (b) explain why it creates difficulties in drawing conclusions. Confine your answer to the THREE issues you consider most relevant.",
  "guidance": "The paper states you get fewer marks for stating a limitation without explaining how it limits conclusions, that marks are capped at three issues, and that comments on the value or rationale of the therapy itself score nothing.",
  "rubric": [
    ("r1", "No control condition — change over 30 minutes cannot be separated from the effects of any adult's sustained one-to-one attention, or from habituation to the researcher's presence", 3,
     cues([r"(no|lack of|absence of|without)[\s\S]{0,40}(control|comparison|comparator)", r"attention|presence|any (adult|person)|non.?specific|habituat|settl"]), "core"),
    ("r2", "The person delivering the intervention also coded the outcome — unblinded assessment by an invested researcher creates detection bias", 3,
     cues([r"(same|one of the) researcher[\s\S]{0,80}(cod|rat|assess)|coded by (the|one)|not blind|unblind|blind", r"bias|invest|expect|influenc|objectiv"]), "core"),
    ("r3", "Only 10% of videos were double-coded, and kappa for emotional valence was 0.32 — poor agreement means that variable is not reliably measured, so its null result is uninterpretable", 3,
     cues([r"kappa|inter.?rater|0?\.32|10%|reliab", r"poor|low|unreliab|uninterpret|cannot (trust|interpret)|weak"]), "core"),
    ("r4", "A single 30-minute session with no follow-up — within-session change says nothing about durable learning or generalisation beyond the researcher", 3,
     cues([r"single session|one session|30.?minute|no follow.?up|only one", r"generalis|generaliz|maintain|durab|lasting|beyond|transfer"]), "core"),
    ("r5", "Sample of 10, recruited by staff nomination from one day centre — selection is non-random and the sample is unrepresentative", 3,
     cues([r"(nominat|staff (chose|selected)|one (day )?centre|sample of (10|ten)|small sample)", r"select(ion)? bias|represent|generalis|not random|skew"]), "core"),
    ("r6", "Dichotomising continuous percentage-of-time data into 'increase' vs 'no increase' discards magnitude and statistical power", 3,
     cues([r"dichotom|binary|increase (or|vs)|categoris|reduc(ing|ed) (the )?data", r"magnitude|information|power|how much|size"]), "advanced"),
  ],
  "traps": [(cues(r"the (therapy|approach|intervention) (is|seems|may be) (a )?(good|valuable|useful|questionable|poor)"),
             "The paper says explicitly that no marks are awarded for opinions about the rationale for the therapy or its potential value. This is a methodology question."),
            (cues(r"^(?![\s\S]*(because|which means|so that|therefore|this means|as a result|so we cannot))"),
             "Marks require part (b) — WHY the limitation restricts the conclusions. A list of limitations scores at the bottom of the range.")],
  "model": "The most serious limitation is the absence of any control condition. Behaviour in the last five minutes is compared with behaviour in the first five minutes of the same session, so any increase in eye gaze is equally consistent with the participant habituating to an unfamiliar adult sitting a metre away, or responding to sustained one-to-one attention of any kind. Since the study offers no condition in which an adult is present without delivering Intensive Interaction, nothing in the design distinguishes the specific technique from ordinary attentive presence, which is precisely the claim the study wants to make. Second, one of the researchers delivering the intervention also coded the outcome from the videos. That researcher knew which phase of the session each clip came from and had an investment in the result, and the outcome — whether a glance counts as gaze 'at the partner' — requires exactly the kind of borderline judgement that expectation influences. Only 10% of the videos were independently coded, which is too small a proportion to detect systematic drift, and the agreement obtained was itself weak: a kappa of 0.32 for emotional valence is poor, so the non-significant result for that variable cannot be interpreted as evidence of no change when the measurement is this unreliable. Third, the study measures a single 30-minute session with no follow-up and no measurement outside the session with the researcher. Even taking the eye gaze finding at face value, it shows only that behaviour shifted within one interaction with one person; it says nothing about whether anything was learned, whether it persisted, or whether it generalised to the care staff and family members who would actually deliver the approach — which is the only outcome with clinical meaning for this client group."},

 {"id": "q2", "marks": 6,
  "prompt": "In one or two sentences, write a brief summary of the results as they might appear in an abstract. Then: what limitations were there in the way the authors decided to ANALYSE the data? State the limitation and explain why it creates difficulties for interpretation. Confine your answer to TWO limitations.",
  "guidance": "Two tasks. The summary must be accurate and compressed — note that only eye gaze reached significance. Then two ANALYSIS limitations, not design limitations.",
  "rubric": [
    ("r1", "Accurate summary: eye gaze increased significantly; bodily orientation did not (p = .056); emotional valence did not (p = .527)", 3,
     cues([r"eye gaze", r"signific"], [r"(\.056|orientation)", r"(not|non).?signific|did not"]), "core"),
    ("r2", "Dichotomising the continuous percentage data into increase / no-increase throws away the magnitude of change — a one-second and a ten-minute increase count identically", 3,
     cues([r"dichotom|binary|categoris|increase (vs|or) (no|decrease)|percentage.{0,30}(reduc|convert)", r"magnitude|how much|size|information|discard|lost"]), "core"),
    ("r3", "Only the first and last 5 minutes were used, discarding the middle 20 minutes of data", 3,
     cues([r"first (and|&) last|middle|20 minutes|only.{0,30}(5|five) minutes", r"discard|ignor|wast|not used|lost"]), "core"),
    ("r4", "Three tests conducted with no correction for multiple comparisons — with alpha at .05 across three outcomes the family-wise error rate is inflated, and eye gaze at p = .020 is the only survivor", 3,
     cues([r"multiple (comparison|test)|three (tests|analyses)|bonferroni|correct(ion|ed) for|family.?wise", r"inflat|type (i|1) error|false positive|adjust"]), "advanced"),
    ("r5", "The denominators differ (9, 9 and 10) because participants showing no change appear to have been dropped from some analyses — unexplained and inconsistent", 3,
     cues([r"\b9\b[\s\S]{0,60}\b10\b|denominator|(number|n) (of participants )?(differ|vary|inconsistent)|9 (rather|instead) than 10"]), "advanced"),
    ("r6", "Treating p = .056 as a failure and p = .020 as a success reifies an arbitrary threshold on evidence that is nearly identical", 3,
     cues([r"\.056|arbitrar|threshold|cut.?off|dichotomous (thinking|decision)|just (above|missed)", r"similar|nearly|almost|little difference|arbitrar"]), "advanced"),
  ],
  "traps": [(cues(r"(no control|blinding|sample size|recruitment|nomination)"),
             "These are design limitations — they belong in question 1. This question asks specifically about the ANALYSIS.")],
  "model": "Summary: across ten adults with profound learning disability, a single session of Intensive Interaction was associated with a significant increase in eye gaze towards the communication partner between the first and last five minutes (z = 2.53, p = .020), while increases in bodily orientation (p = .056) and positive emotional valence (p = .527) did not reach significance. The first analytic limitation is the decision to dichotomise. The authors calculated percentage of time — a continuous, informative measure — and then reduced it to a binary judgement of whether each participant increased or did not. A participant who gazed at the partner for one second longer is counted identically to one who gazed for four minutes longer, so the analysis discards the magnitude of change entirely, throws away statistical power, and leaves us unable to say whether the significant eye gaze result reflects a clinically meaningful shift or a trivial one. The second is the absence of any correction for multiple comparisons. Three tests were run at alpha = .05, which raises the probability of at least one false positive to roughly 14%, and eye gaze at p = .020 is the only result to cross the threshold. Under even a simple Bonferroni adjustment it would not survive. Since no primary outcome was pre-specified, we cannot distinguish a real effect on gaze from the expected consequence of testing three outcomes and reporting the one that reached significance."},

 {"id": "q3", "marks": 6,
  "prompt": "(a) What ethical concerns do you have about the process of gaining consent in this study? State your concern and explain how you would address it. (b) The researchers conducted no assessment of the risk of adverse outcomes. What potential risks needed to be assessed, and how could they have been minimised? Confine part (b) to the ONE risk you consider most relevant.",
  "guidance": "Note the participants have profound learning disability and no apparent language ability, and that STAFF nominated them and signed the consent form.",
  "rubric": [
    ("r1", "Staff cannot consent on behalf of an adult — for adults lacking capacity in England and Wales the Mental Capacity Act route requires a consultee, not a proxy signature from a day centre worker", 3,
     cues([r"staff (cannot|can't|are not|should not|have no)|proxy|on behalf|consultee|mental capacity act|\bmca\b", r"consent|legal|authoris|entitled"]), "core"),
    ("r2", "No assessment of the participants' own capacity, and no attempt to seek assent or to support communication of a decision — capacity is decision-specific and must be assessed, not assumed absent from diagnosis", 3,
     cues([r"capacity|assent|decision.?specific|presum", r"assess|not assum|support|communicat|accessible"]), "core"),
    ("r3", "Consent was sought at the end of a presentation promoting the research, from staff in a dependent relationship with the researchers — this compromises voluntariness", 3,
     cues([r"end of (the )?(meeting|presentation)|pressure|on the spot|immediate|time to (consider|think)|voluntar", r"presur|pressur|coerc|volunt|reflect|consider"]), "advanced"),
    ("r4", "No indication that families, carers or an independent advocate were involved in the decision", 3,
     cues(r"famil|next of kin|carer|advocate|imca|relative"), "advanced"),
    ("r5", "Addressed by: MCA consultee process, individual capacity assessment with accessible information, ongoing behavioural assent monitored throughout, family and advocate consultation, and time to decide", 3,
     cues([r"consultee|capacity assessment|accessible (information|format)|easy read|ongoing (assent|consent)|withdraw", r"would|should|address|process|procedure"]), "core"),
    ("r6", "(b) Risk of distress: an unfamiliar adult sits within one metre, in the participant's field of vision, and mirrors their movements for 25 minutes; a person with no verbal means of objecting may find this intrusive or frightening and be unable to say so", 3,
     cues([r"distress|frighten|intrusi|threat|invad|personal space|1 metre|one metre|close|uncomfortab", r"cannot (say|communicate|object|tell)|no (verbal|language|way)|unable to"]), "core"),
    ("r7", "(b) Minimised by: pre-agreed behavioural indicators of distress defined with people who know the person, a stopping rule, a familiar person present, and staged approach with monitoring", 3,
     cues([r"stopping rule|withdraw|stop the session|indicator|sign(s)? of distress|familiar (person|staff)|baseline|know the person|graded|staged"]), "core"),
  ],
  "traps": [(cues(r"(gdpr|data protection|anonymis|store(d)? securely|password)(?![\s\S]{0,120}(capacity|consent|assent))"),
             "Generic data handling is not the ethical issue this study raises. The issue is that non-verbal adults were entered into research on a staff member's signature."),
            (cues(r"they (signed|gave) (a )?consent form(?![\s\S]{0,100}(cannot|not valid|no legal|proxy))"),
             "A signed form is not consent. Ask who signed it, on what authority, and whether the participant was assessed at all.")],
  "model": "The consent process is the most serious problem in the study. Participants were adults with profound learning disability and no apparent language ability, and the people who consented to their participation were day centre staff who had been asked to nominate them at the end of a presentation about the research. In England and Wales no adult can consent on behalf of another adult: where an adult may lack capacity to decide about research, the Mental Capacity Act requires the researcher to assess capacity for that specific decision, to take all practicable steps to support the person to decide including accessible and non-verbal formats, and where capacity is genuinely absent to consult a personal consultee — usually a family member or someone who knows the person well in an unpaid capacity — about what the person's wishes and feelings would likely have been. A staff signature on a nomination form satisfies none of this. There is also no evidence any capacity assessment was attempted, so incapacity appears to have been inferred from diagnosis, which is precisely what the Act prohibits. The circumstances compound this: staff were asked to decide immediately, at the end of a meeting held to promote the study, with no time to consider and an implicit expectation of cooperation, which undermines voluntariness even as a consultee decision. I would address this by assessing each person's capacity individually with accessible materials, consulting family members and, where there is no appropriate person, an independent advocate, allowing time for consideration away from the presentation, and treating consent as ongoing rather than a single event, with behavioural assent monitored throughout. On risk: the intervention places an unfamiliar researcher within one metre of the participant, inside their field of vision, mirroring their movements and vocalisations for 25 minutes. For someone who cannot say no, that is a plausible source of distress — the proximity may be experienced as intrusive or threatening, and mirroring may be confusing or mocking rather than attuned. The study assessed this risk not at all, and coded emotional valence only as an outcome, with poor reliability. I would minimise it by agreeing individualised behavioural indicators of distress in advance with the people who know the person best, establishing an explicit stopping rule applied by an observer rather than by the person delivering the intervention, having a familiar member of staff present, and building up contact gradually rather than beginning with 25 minutes."},

 {"id": "q4", "marks": 6,
  "prompt": "Suppose you were working with someone with profound learning disability and the benefits of more social interaction with her family were highlighted by your assessment. What issues would you consider in deciding whether to use Intensive Interaction? Confine your answer to the THREE issues you consider most relevant.",
  "guidance": "This is a clinical decision question, not a critique. You are being asked how a psychologist reasons from a weak evidence base to a decision about one person.",
  "rubric": [
    ("r1", "The evidence base is weak — but absence of strong evidence is not evidence of absence, and for this population the alternative evidence-based options are few, so the decision is proportionate rather than dictated by the literature", 3,
     cues([r"evidence (base|is)|weak|limited (evidence|research)|poor(ly)? (evidenced|researched)", r"not evidence of absence|few alternatives|proportionate|does not mean|still|nevertheless|balanc"]), "core"),
    ("r2", "Whether the approach fits this person — her sensory profile, tolerance of proximity, existing communication repertoire, history of trauma or aversive experience of close contact", 3,
     cues([r"sensor|proximity|close|touch|tolerat|individual|this (person|woman)|her (profile|preference|history)|trauma|autis"]), "core"),
    ("r3", "Who delivers it — the goal is interaction with FAMILY, so the family must be trained, supported and willing; an intervention delivered only by the psychologist does not meet the identified need", 3,
     cues([r"famil", r"train|deliver|teach|support|coach|carry out|who (does|delivers|implements)"]), "core"),
    ("r4", "Consent and assent — capacity assessment, best interests decision under the MCA, ongoing behavioural assent, and the least restrictive alternative", 3,
     cues([r"capacity|consent|assent|best interest|\bmca\b|least restrictive"]), "core"),
    ("r5", "How you would know whether it is working for HER — individualised, repeated, ideally single-case measurement (multiple baseline) rather than reliance on group findings", 3,
     cues([r"single.?case|multiple baseline|baseline|repeated measure|monitor|evaluat|outcome|measure", r"individual|her|this person|idiographic|n.?of.?1"]), "advanced"),
    ("r6", "Alternatives considered — other communication approaches (objects of reference, PECS, Talking Mats, augmentative communication), and the possibility of environmental or staff-level change", 3,
     cues(r"alternativ|other (approach|option|intervention)|pecs|objects of reference|talking mats|augmentative|makaton|communication (aid|passport)"), "advanced"),
    ("r7", "Values and rights — whose goal is more social interaction, and does she show any sign of wanting it; the risk of imposing a normative goal on a person who cannot dissent", 3,
     cues([r"whose (goal|aim|agenda)|want|prefer|impos|normative|right|choice|her (view|wish)"]), "advanced"),
  ],
  "traps": [(cues(r"^(?![\s\S]*(famil))"),
             "The question specifies that the benefit identified was interaction with her FAMILY. An answer that never mentions the family has not answered the question asked.")],
  "model": "The first issue is what the evidence actually supports. The published work on Intensive Interaction, including this study, is methodologically weak, so I could not tell the family that it is established as effective. But weak evidence is not evidence of ineffectiveness, and for someone with profound learning disability and no language the range of alternatives with better evidence is very small; refusing on evidential grounds alone would leave the identified need unaddressed. So I would treat the decision as a proportionate one made under uncertainty, and be explicit with the family that this is what we are doing. The second issue is fit with this particular person. Intensive Interaction requires close physical proximity and mirroring, so I would want to know her sensory profile, how she responds to people entering her space, whether there is any history of aversive or frightening close contact, and what communicative behaviour she already has, since the approach builds on her existing repertoire rather than teaching a new one. If proximity is aversive for her, the intervention is not neutral. The third issue is who delivers it and how I would know if it is working. The assessment identified benefit from interaction with her family, not with me, so the intervention has to be something the family can learn, sustain and adapt — which makes their willingness, confidence and capacity to do it part of the clinical decision rather than a practical detail. Alongside that I would set up individualised measurement before starting: an agreed baseline of specific behaviours over several sessions, then repeated measurement across settings, ideally in a multiple baseline design, so that the decision to continue rests on evidence about her rather than on a group finding from ten other people. I would also want the capacity and best interests position documented, with assent monitored behaviourally throughout, and a clear agreement about what would make us stop."},
]

EX.append({
 "id": "birm2018",
 "title": "Intensive Interaction in profound learning disability",
 "course": "Birmingham",
 "year": 2018,
 "minutes": 60,
 "totalMarks": 24,
 "provenance": "Real Birmingham pre-selection written test, 2018 intake. The questions and instructions are verbatim. No official marking scheme was supplied with this paper, so the rubric points below are reconstructed from the question wording and its explicit marking instructions — treat them as a strong guide rather than the marker's own list.",
 "brief": "Answer all four questions. The paper's own instructions apply: write in full sentences, not notes; marks are capped at the number of issues requested, so more issues will not earn more marks; and you are marked on written presentation as well as content.",
 "stimulus": b18_stimulus,
 "questions": [{"id": q["id"], "marks": q["marks"], "prompt": q["prompt"], "guidance": q["guidance"],
                "rubric": [{"id": r[0], "text": r[1], "weight": r[2], "cues": r[3], "tier": r[4]} for r in q["rubric"]],
                "traps": [{"cues": t[0], "msg": t[1]} for t in q["traps"]],
                "model": q["model"]} for q in b18_q],
 "debrief": ("This paper rewards discipline more than knowledge. It caps the number of issues, so a fourth point is "
             "wasted effort; it demands the explanation as well as the limitation, so half your marks live in the word "
             "'because'; and it explicitly refuses marks for opinions about the therapy's value in Q1. The candidates who "
             "do badly here are usually the ones who knew the most and could not stop writing.")
})

# =====================================================================
# SURREY / CCCU 2016 PART 2 — abstract writing
# =====================================================================
EX.append({
 "id": "abstract2016",
 "title": "Structured abstract: alcohol feedback in A&E",
 "course": "Surrey & Canterbury Christ Church",
 "year": 2016,
 "minutes": 25,
 "totalMarks": 15,
 "provenance": "Real Surrey/CCCU selection written test 2016, Part 2 (Written Communication). The task and study text are verbatim; rubric points are reconstructed from the stated sub-headings and the study content.",
 "brief": "Write a succinct structured abstract of the study below, using the sub-headings Background, Methods, Results, Conclusions. Do not copy sentences verbatim from the description — copied sentences score nothing. This part assesses your ability to extract, interpret and summarise, and is marked separately with its own threshold.",
 "stimulus": [
  {"t": "h", "v": "Impact of health consequences feedback on patients' acceptance of advice about alcohol consumption"},
  {"t": "note", "v": "Patton R, Crawford MJ & Touquet R. (2003), Emergency Medicine Journal, 20: 451–452"},
  {"t": "p", "v": "The effects of excessive alcohol consumption are well reported and include liver disease, suicide, and accidents. Recent research has highlighted the increased level of alcohol consumption among patients reporting to the accident and emergency (A&E) department. Programmes of Screening and Brief Intervention (SBI) based in the A&E department may reduce levels of drinking among participating patients; however, no matter how effective an intervention may be, it is reliant upon the willingness of a patient to accept it."},
  {"t": "p", "v": "Patients reporting to the A&E department at St Mary's hospital are routinely screened for hazardous drinking using the Paddington Alcohol Test (PAT). Those who screen positive are offered advice about their drinking. At the start of the recruitment phase of a separate randomised controlled trial, it was observed that fewer patients were accepting advice than had been anticipated. Action was therefore taken to increase the proportion of patients who would accept help."},
  {"t": "p", "v": "METHODS. This brief report is a retrospective analysis of a sample of patients who presented to the A&E department and screened positive on the PAT. During a 12 week period between March and June 2001, senior house officers (SHOs) trained to implement a screening and brief intervention protocol identified patients aged 18 and over who were hazardous drinkers. Male patients were PAT positive if drinking eight or more units on one or more occasions per week; for women the limit was six units. Any patient stating their visit was related to alcohol consumption was also deemed PAT positive."},
  {"t": "p", "v": "For the first six weeks SHOs were instructed to screen patients and offer help to those who were PAT positive (control period). After six weeks the SHOs received a brief training session that emphasised making a link between screening positive and potential health consequences (feedback period), by saying “you are drinking at a level that is harmful to your health”, and then offering advice. Patients' sex, age, and level of alcohol consumed in a single session were recorded together with willingness to accept advice. Local research ethics committee approval was given for the project of which this study forms a part."},
  {"t": "p", "v": "RESULTS. Altogether 281 patients were PAT positive. They were predominantly male (77%) with an average age of 44.4 years, and a mean of 21.8 units consumed in a single session. There were no significant differences between the control and feedback periods on these variables. On average 64% of patients accepted advice during the feedback period compared with 52.1% during the control period (χ² = 3.99, df = 1, p < 0.05)."},
  {"t": "p", "v": "DISCUSSION. The provision of simple feedback by doctors was associated with a 22.8% increase in the proportion of patients willing to accept brief advice. In a typical A&E department we estimate this could lead to an additional 350 patients per year accepting help and advice to reduce their drinking. While we cannot rule out the possibility that changes other than the introduction of simple feedback were responsible for this increase, the timing of the increase suggests that this is the most probable explanation."},
 ],
 "questions": [
  {"id": "q1", "marks": 15,
   "prompt": "Write a structured abstract using the sub-headings Background, Methods, Results, Conclusions.",
   "guidance": "Aim for roughly 200–250 words. Each section must carry its own weight: background states the problem and the gap, methods gives design, setting, sample, measure and comparison, results gives the numbers, conclusions state what follows AND what the design cannot support.",
   "rubric": [
     ("b1", "BACKGROUND: brief intervention works only if patients accept it — acceptance is the identified problem", 1,
      cues([r"accept", r"(brief intervention|advice|help|sbi)"]), "core"),
     ("b2", "BACKGROUND: sets the A&E screening context (PAT / hazardous drinking)", 1,
      cues(r"a&e|accident and emergency|emergency department|screen"), "core"),
     ("m1", "METHODS: identifies the design as retrospective, and as a before-and-after comparison of two consecutive periods", 1,
      cues([r"retrospectiv|before.?and.?after|before and after|two periods|sequential|non.?randomis"]), "core"),
     ("m2", "METHODS: setting and sample — 281 PAT-positive adults at one London A&E over 12 weeks", 1,
      cues([r"281|12 week|twelve week", r"a&e|hospital|department"]), "core"),
     ("m3", "METHODS: the manipulation — six weeks of usual practice, then SHO training to add an explicit health-consequences statement before offering advice", 1,
      cues([r"six week|6 week|first half|second", r"train|feedback|health consequence|harmful to your health"]), "core"),
     ("m4", "METHODS: outcome — proportion of patients accepting advice", 1,
      cues([r"(proportion|percentage|rate|number)[\s\S]{0,40}accept|accept[\s\S]{0,30}(advice|help)"]), "core"),
     ("r1", "RESULTS: 64% accepted in the feedback period vs 52.1% in the control period", 2,
      cues([r"64", r"52"]), "core"),
     ("r2", "RESULTS: reports the test and significance (χ² = 3.99, df = 1, p < .05)", 1,
      cues([r"chi|χ|3\.99|p ?[<=] ?\.?0?5"]), "core"),
     ("r3", "RESULTS: notes groups did not differ on age, sex or units consumed", 1,
      cues([r"no (significant )?difference|did not differ|comparable|similar", r"age|sex|units|demographic"]), "advanced"),
     ("c1", "CONCLUSIONS: adding an explicit health-consequences statement was associated with greater acceptance of advice", 2,
      cues([r"associat|linked|accompanied", r"accept"]), "core"),
     ("c2", "CONCLUSIONS: states the causal limitation — an uncontrolled before-and-after design cannot exclude concurrent change (SHO experience, seasonality, secular trend)", 2,
      cues([r"cannot|causal|confound|other (change|factor)|secular|season|experience|maturation|temporal|not randomis"]), "core"),
     ("c3", "CONCLUSIONS: notes the practical implication (potential additional patients accepting help per year)", 1,
      cues([r"350|per year|annually|implication|service"]), "advanced"),
   ],
   "traps": [(cues(r"randomised controlled trial|\brct\b(?![\s\S]{0,60}(separate|different|another))"),
              "This study is NOT the RCT. The RCT is mentioned as a separate trial being run in the same department; this brief report is a retrospective before-and-after analysis. Calling it an RCT is a comprehension error that would be heavily penalised."),
             (cues(r"22\.8% (increase|more) (of |in )?patients accepted"),
              "Careful with the 22.8% figure — it is a RELATIVE increase (52.1 → 64). The absolute increase is about 12 percentage points. Reporting the relative figure as though it were absolute overstates the finding."),
             (cues(r"caused|proves|demonstrates that feedback"),
              "Overclaiming causation from a before-and-after design.")],
   "model": "Background: Screening and brief intervention for hazardous drinking in emergency departments can reduce consumption, but its impact depends on patients agreeing to accept advice, and acceptance rates in practice were lower than anticipated. This study examined whether explicitly linking a positive screen to health consequences increased the proportion of patients who accepted advice.\n\nMethods: Retrospective analysis of consecutive patients aged 18 and over attending a London emergency department over 12 weeks in 2001 who screened positive for hazardous drinking on the Paddington Alcohol Test (n = 281). The study compared two consecutive six-week periods. During the first, senior house officers screened patients and offered help as usual. Before the second, they received brief training emphasising an explicit statement that the patient was drinking at a level harmful to their health, delivered before the offer of advice. The outcome was the proportion of PAT-positive patients accepting advice; age, sex and units consumed in a single session were also recorded.\n\nResults: Patients were predominantly male (77%), mean age 44.4 years, consuming a mean of 21.8 units per session, with no significant differences between periods on these variables. Acceptance of advice rose from 52.1% during the control period to 64% during the feedback period (χ² = 3.99, df = 1, p < .05), an absolute increase of approximately 12 percentage points.\n\nConclusions: Adding a brief explicit statement about health consequences was associated with a higher proportion of patients accepting advice, and the authors estimate this could correspond to around 350 additional patients accepting help annually in a typical department. Because the design compared two consecutive periods without randomisation or a concurrent control, the increase cannot be attributed to the feedback with confidence; growing clinician experience, seasonal variation and other concurrent changes remain plausible alternative explanations. A randomised or stepped-wedge evaluation would be needed to establish the effect."}
 ],
 "debrief": ("Abstract-writing is a selection task because it tests compression under constraint — exactly what a case "
             "summary, a referral letter and an interview answer all require. Two habits transfer. Give every section a "
             "job and do not let one leak into another. And put the design limitation in the conclusions rather than "
             "leaving it implied: the marker cannot award you a point for a caveat you were privately aware of.")
})

# =====================================================================
# CARDIFF 2016 — 30 minute scenario
# =====================================================================
EX.append({
 "id": "cardiff2016",
 "title": "Indirect working in an intellectual disability service",
 "course": "Cardiff",
 "year": 2016,
 "minutes": 30,
 "totalMarks": 20,
 "provenance": "Real Cardiff written test task, 2016. The scenario and the four prompts the paper suggested candidates address are verbatim from the recalled paper; the rubric is reconstructed. Cardiff's written task is followed in interview by 'with reference to the written test — what values underpinned your answers?', so write it as something you can defend aloud.",
 "brief": "You have 30 minutes. Answer ONE scenario. The paper suggested including: the Welsh context, cost-benefit, assessment and evaluation, and ethics.",
 "stimulus": [
  {"t": "h", "v": "Scenario 1"},
  {"t": "p", "v": "You are a psychologist in an intellectual disabilities residential care home. Discuss three ways in which you could help service users that DO NOT involve one-to-one interventions."},
  {"t": "h", "v": "Scenario 2"},
  {"t": "p", "v": "You are a psychologist in a young person's inpatient unit. Discuss three ways in which you could help service users that DO NOT involve one-to-one interventions."},
  {"t": "note", "v": "Things the paper suggested including: the Welsh context; cost-benefit; assessment and evaluation; ethics."},
 ],
 "questions": [
  {"id": "q1", "marks": 20,
   "prompt": "Choose one scenario. Set out three ways you could help service users that do not involve one-to-one intervention. For each, say what psychological thinking underpins it, how you would evaluate it, and what it costs and saves.",
   "guidance": "The constraint is the question. 'Not one-to-one' is asking whether you understand that the psychologist's leverage in a residential or inpatient setting lies mostly in the system, not the therapy room. Three developed routes beat six listed ones.",
   "rubric": [
     ("r1", "Staff training — with a stated psychological rationale (e.g. attributions about behaviour, emotional labour, burnout) rather than training as a generic good", 3,
      cues([r"train|teach|workshop|upskill", r"staff|team|carer|support worker"]), "core"),
     ("r2", "Team formulation / consultation — shifting staff attributions and reducing blame, with the mechanism named", 3,
      cues([r"team formulation|formulation (meeting|session|with (the )?(team|staff))|consultation|reflective practice (group|session)"]), "core"),
     ("r3", "Environmental, systemic or PBS-informed change — antecedent-level work, structure, predictability, meaningful activity, reduction of restrictive practice", 3,
      cues([r"environment|antecedent|positive behaviour support|\bpbs\b|routine|structure|activity|restrictive practice|sensory"]), "core"),
     ("r4", "Group intervention or peer-led work delivered by others under supervision", 2,
      cues([r"group (work|intervention|programme|session)|peer (support|led)|psychoeducation group"]), "advanced"),
     ("r5", "Evaluation is specified — what data, collected when, compared with what (not merely 'I would evaluate it')", 3,
      cues([r"(measure|data|outcome|audit|baseline|incident|before and after|pre.?post|single.?case|multiple baseline)", r"(evaluat|monitor|review|compare)"]), "core"),
     ("r6", "Cost-benefit is addressed concretely — psychologist time is the scarce resource, and indirect work multiplies reach across a whole staff group and outlasts your post", 2,
      cues([r"cost|resourc|time|capacity|reach|scale|value|sustainab|efficien", r"staff|whole (home|unit|team)|many|multipl|beyond"]), "core"),
     ("r7", "Welsh context is engaged specifically — e.g. the Welsh language, the Social Services and Well-being (Wales) Act, Welsh Government mental health strategy, rurality and travel, distinct NHS Wales structures", 3,
      cues(r"welsh|wales|cymraeg|cymru|social services and well.?being|rural|bilingual|welsh language|active offer"), "core"),
     ("r8", "Ethics engaged specifically — consent and capacity in a residential setting, restrictive practice and least restriction, power imbalance, whose goals are being served", 3,
      cues([r"consent|capacity|restrictive|least restrict|power|coerc|rights|whose (goal|interest)|dignity|choice"]), "core"),
     ("r9", "Service users or families are involved in designing what is offered, not only receiving it", 2,
      cues([r"co.?produc|involve|consult|service user|resident|family|carer", r"design|shape|decide|plan|ask"]), "advanced"),
     ("r10", "The answer names an underlying value or principle it could defend aloud in interview", 2,
      cues(r"value|principle|belief|underpin|commit|stance|because I (think|believe)"), "advanced"),
   ],
   "traps": [(cues(r"(individual|1:1|one.to.one|one to one) (therapy|session|work|intervention)(?![\s\S]{0,80}(not|instead|rather|avoid|beyond))"),
              "The question explicitly excludes one-to-one work. Proposing it — even as one of three — loses the point and suggests you did not read the constraint."),
             (cues(r"^(?![\s\S]*(wales|welsh|cymru))"),
              "Cardiff asks about the Welsh context in the written task and in interview. An answer with nothing specific about Wales leaves marks on the table at a Welsh course.")],
   "model": "In a residential intellectual disability service the psychologist is one person among a staff team who provide care around the clock, so most of the psychological work available to me is indirect. I would prioritise three routes.\n\nFirst, regular team formulation. Behaviour that services describe as challenging is usually met with explanatory attributions — that the person is attention-seeking, or manipulative, or that this is 'just their autism' — and those attributions drive how staff respond, which in turn maintains the behaviour. A facilitated formulation session builds a shared account of what the behaviour communicates and what function it serves, and the evidence suggests the reliable effect is on staff attributions, emotional responses and confidence rather than immediately on the person. I would evaluate it accordingly: brief attribution and confidence measures before and three months after, alongside incident records and restrictive practice data, rather than expecting behaviour change to appear on its own.\n\nSecond, antecedent-level environmental work informed by positive behaviour support. Rather than responding to incidents, I would carry out functional assessment across the home and then work on predictability of routine, communication systems, meaningful daily activity and sensory environment. This is where the largest effects in this population usually sit, and it reaches every resident rather than the one on my caseload. Evaluation would be a multiple-baseline design across settings or individuals, using incident frequency and, importantly, quality of life and engagement measures — because a reduction in incidents achieved by restricting someone's life is not a good outcome.\n\nThird, staff training and reflective practice as a standing arrangement rather than a one-off. Care staff in this setting are low-paid, high-turnover and exposed to distressing behaviour with little space to think about it, and burnout predicts exactly the depersonalised responding that escalates incidents. I would run a monthly reflective group, evaluating through staff turnover and sickness data as well as validated burnout measures, since these are the outcomes the organisation will act on.\n\nCost-benefit runs through all three. My time is the scarce resource: an hour spent in a formulation meeting with eight staff shapes care delivered across every shift, and it persists after my post is funded elsewhere, whereas an hour of one-to-one therapy reaches one person once. The trade-off, which I would be honest about, is that indirect work has a longer lag to visible outcome and is harder to attribute.\n\nThe Welsh context shapes delivery. The Social Services and Well-being (Wales) Act places well-being and voice at the centre of care and gives carers a statutory right to assessment, which strengthens the case for family and staff involvement. The Welsh language matters: for many people with an intellectual disability, particularly older residents in Welsh-speaking communities, Welsh is their first and sometimes only language, and the Active Offer means provision in Welsh should not depend on the person asking. Rurality also matters practically — in a dispersed service, consultation and training models travel better than weekly individual appointments.\n\nEthically, the central issue is that everything I have described happens to people rather than with them. Residents may lack capacity to consent to a change in the environment, and the MCA framework of best interests and least restriction applies. There is a real risk of the service's goals — fewer incidents, easier shifts — substituting for the residents' own, so I would want residents and families involved in setting the outcomes we measure, and I would treat any reduction in restrictive practice as a primary outcome rather than a side effect. The value underpinning all three choices is that the environment, not the person, is usually the appropriate target of change."}
 ],
 "debrief": ("Cardiff follows this task in interview with 'what values underpinned your answers?'. Write it so that you "
             "could answer that in one sentence — and if you cannot, the answer has not committed to anything. The "
             "highest-scoring version of this task is not the one that lists the most options; it is the one that "
             "explains why indirect work is the right choice in a setting where you are one person among many.")
})

# =====================================================================
# SOUTH WALES 2015 — reflective letter
# =====================================================================
EX.append({
 "id": "southwales2015",
 "title": "Reflective letter: witnessing a colleague",
 "course": "South Wales",
 "year": 2015,
 "minutes": 40,
 "totalMarks": 20,
 "provenance": "Real South Wales written task, 2015, verbatim scenario and prompts. Rubric reconstructed. South Wales followed this in interview with 'what do you think the written task was trying to assess?' — a question worth having an answer to.",
 "brief": "Write the reflective letter your supervisor has asked for. Address the headings given. You are writing to your supervisor, in advance of supervision — the register is professional and reflective, not a formal incident report.",
 "stimulus": [
  {"t": "p", "v": "You are a health care worker working in an adolescent forensic unit and you witness your manager taking money from one of the service users. They did not see you. The service user involved has seemed a bit low lately. You usually get on well with your manager, but you sometimes feel a bit uncomfortable in his presence. You have briefly spoken about the incident with your supervisor and he/she has asked you to write a reflective letter detailing what you would like to discuss in your upcoming supervision."},
  {"t": "note", "v": "Focus on: your dilemma; why is this a priority; any professional / personal issues; what do you want from supervision; any other issue."},
 ],
 "questions": [
  {"id": "q1", "marks": 20,
   "prompt": "Write the reflective letter.",
   "guidance": "Two failure modes here. One is to write a procedural incident report with no interior life. The other is to write pure feeling with no action. The task assesses whether you can hold both — and whether the safeguarding of a young person survives your discomfort about your manager.",
   "rubric": [
     ("r1", "Names the safeguarding dimension explicitly — a young person in a forensic unit, dependent, possibly unaware, and low in mood; this is potential abuse of a vulnerable person, not a workplace disagreement", 3,
      cues([r"safeguard|abuse|vulnerab|exploit|protect", r"young person|service user|adolescent|child|resident"]), "core"),
     ("r2", "Recognises the power imbalance — the person taking money holds authority over both the young person and over you", 2,
      cues([r"power|authorit|senior|manag|hierarch|imbalance|position"]), "core"),
     ("r3", "States that action is required regardless of certainty — raising a concern is a referral for assessment, not an accusation requiring proof", 2,
      cues([r"(do not|don't|not) (have to|need to) (be certain|prove|know)|not an accusation|report(ing)? (a )?concern|threshold|raise (it|a concern)|duty"]), "core"),
     ("r4", "Identifies the dilemma honestly — loyalty, the good working relationship, fear of consequences for oneself, doubt about what was seen", 3,
      cues([r"dilemma|loyal|conflict|torn|difficult|fear|worried|consequence|career|doubt|unsure|might have (mis)?(seen|understood)"]), "core"),
     ("r5", "Reflects on the pre-existing discomfort in the manager's presence, and considers what that might mean — including that it might be data, and might be bias", 3,
      cues([r"uncomfortab|unease|discomfort", r"what (that|this) (mean|tell|says)|bias|prejudg|data|inform|noticed before|already"]), "advanced"),
     ("r6", "Notes what has already been done and what happens next — escalation route named (safeguarding lead, whistleblowing / Freedom to Speak Up, local procedure)", 3,
      cues([r"safeguarding lead|whistleblow|freedom to speak up|policy|procedure|escalat|report to|senior manager|designated"]), "core"),
     ("r7", "Considers the service user directly — their low mood, whether it may be connected, whether and how they should be spoken to, and their right to be heard", 2,
      cues([r"(low|mood|distress|withdraw)[\s\S]{0,120}(connect|related|linked|might|wonder)", r"(speak|talk|ask|listen) (to|with) (them|the (service user|young person))"]), "core"),
     ("r8", "Makes a specific ask of supervision — not 'support' in general but named questions: what is the threshold, what is my role, what do I do about the working relationship afterwards", 3,
      cues([r"(want|ask|hoping|help me|need) [\s\S]{0,120}(supervis|you)", r"\?|whether|what (should|do) I|how (do|should) I|advice on|think through"]), "core"),
     ("r9", "Records the facts separately and contemporaneously — what was seen, when, where, in factual terms", 2,
      cues([r"record|document|written down|notes|contemporaneous|factual|date and time"]), "advanced"),
     ("r10", "Distinguishes fact from interpretation — what was actually observed versus what was inferred", 2,
      cues([r"what I (actually )?saw|fact|interpret|assum|infer|could have been|may (have )?(been|meant)|do not know why"]), "advanced"),
   ],
   "traps": [(cues(r"^(?![\s\S]*(safeguard|abuse|protect|vulnerab|report|escalat|lead|policy))"),
              "A letter that processes the emotional dilemma without ever arriving at protective action has failed the task. The reflection has to lead somewhere."),
             (cues(r"(confront|speak to|approach) (him|my manager|the manager)(?![\s\S]{0,140}(supervis|safeguard|advice|first|before|policy))"),
              "Confronting the manager directly first is a common and costly answer: it risks the evidence, the young person and yourself. The route is the safeguarding lead and supervision."),
             (cues(r"(wait|see if it happens again|monitor|keep an eye)(?![\s\S]{0,100}(but|however|alongside|while also|meanwhile))"),
              "Waiting to see if it recurs leaves a young person unprotected in the meantime and is not a defensible position afterwards."),
             (cues(r"\b(certain|sure|definitely) (that )?(he|she|they) (stole|took)"),
              "You saw an act; you do not know its meaning or its authorisation. Reporting a concern accurately means describing what you observed, not asserting a conclusion.")],
   "model": "Dear [supervisor],\n\nThank you for suggesting I write this before we meet. Setting it down has helped me separate what I actually saw from what I have been telling myself about it, and I want to use our session well.\n\nWhat I saw: on [date], in [location], I saw [manager] take money from [service user]'s [wallet/locker/bag]. I do not think he saw me. I have written a factual account with the date, time and place, and kept it separately. I want to be careful here, because I have noticed how quickly my account slides from what I observed into what I assume it meant. I saw money being taken. I do not know whether there was some arrangement I am unaware of, and I do not know what he intended. What I do know is that I saw enough to be concerned, and that my uncertainty about the meaning is not a reason to stay silent.\n\nWhy this is a priority. The person involved is a young person in a forensic inpatient unit. He is detained, dependent on staff for almost everything, and structurally in the weakest position in this building. If money is being taken from him, that is potential financial abuse of a vulnerable young person, and it falls under safeguarding rather than under workplace conduct. He has also seemed low recently. I do not want to over-interpret that — there are many reasons a young person on this unit might be low — but I cannot honestly say I have not wondered whether the two are connected, and I think that possibility raises the urgency rather than lowering it. My understanding is that raising a safeguarding concern is a referral for assessment, not an accusation, and that the threshold is concern rather than proof. That has helped me, because most of my hesitation has been organised around not being certain enough.\n\nThe dilemma, honestly. I get on well with [manager]. He has been good to me, he has more experience than me, and he is senior to me — which means he has influence over my working life, my references and my future in this service. I have found myself constructing reasons why I might have misunderstood, and I think I need to name that as avoidance rather than as caution. There is also something I want to bring that is less comfortable. I have felt uneasy in his presence for a while, before any of this. I have two thoughts about that and I cannot tell which is right. One is that I may have been noticing something I could not articulate, and that the unease is information. The other is that my unease may now be shaping how I read what I saw, and that I could be building a case against someone I already found difficult. I do not think I can settle that alone, and it is one of the things I most want your help with.\n\nWhat I have done and what I understand happens next. I have not spoken to [manager]. I considered it, and decided against it: it could compromise any subsequent enquiry, it could place the young person at greater risk, and given the power difference I do not think it is my conversation to have. I have written my factual account. I understand that the next step is to raise this with the safeguarding lead, and that because the concern is about a manager, the escalation route needs to go outside his line of management — I would like to check I have that right. I am also aware of the Freedom to Speak Up route if I feel it is not taken seriously.\n\nWhat I would like from supervision. Specifically: (1) Have I correctly identified the escalation route, given that the concern is about a manager? (2) What is my role in relation to the young person — should I be speaking with him at all, and if so about what, or would that compromise the enquiry? He has a right to be heard about something that happened to him, and I do not want him to become invisible in a process about adults. (3) How do I hold my working relationship with [manager] while this is looked into, given that I will be on shift with him? (4) Help me test whether my prior discomfort is informing or distorting my judgement. And (5) I would find it useful to think about my own support, because I have been sleeping badly since, and I would rather say that now than discover it in a month.\n\nOne further issue. If money has been taken from one young person, I do not know that it has not happened to others, and several residents here have no family contact and no one to notice. I think that is worth raising as a question about the unit, separately from the question about one individual.\n\nWith thanks,\n[name]"}
 ],
 "debrief": ("South Wales asks in interview what the written task was assessing. The honest answer: whether the pull of "
             "loyalty, hierarchy and self-protection deflects you from a safeguarding duty, and whether you can be "
             "reflective without becoming paralysed. Notice the structure of the model answer — it separates observation "
             "from inference, states the discomfort rather than resolving it prematurely, and still arrives at a "
             "concrete next step. That is the shape of a strong reflective answer in any interview.")
})

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "trainer", "data", "written.json")
json.dump({"version": 1, "exercises": EX}, open(OUT, "w"), indent=1, ensure_ascii=False)
tot = sum(len(e["questions"]) for e in EX)
pts = sum(sum(len(q["rubric"]) for q in e["questions"]) for e in EX)
print(f"{len(EX)} written exercises, {tot} questions, {pts} rubric points -> {OUT}")
for e in EX:
    print(f"  {e['id']:16s} {e['minutes']:3d}min  {len(e['questions'])}q  {sum(len(q['rubric']) for q in e['questions'])} rubric pts")
