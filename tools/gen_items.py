# -*- coding: utf-8 -*-
"""Drill item bank.

Levels form the depth ladder used by the mastery model:
  recognise < recall < apply < discriminate < transfer
A concept's depth can never exceed the highest level actually passed, so
recognition alone can never register as mastery.
"""
import json, os

IT = []

def add(**kw):
    kw.setdefault("difficulty", 3)
    kw.setdefault("time", 60)
    kw.setdefault("context", None)
    kw.setdefault("source", None)
    kw.setdefault("precision", None)
    IT.append(kw)

def mcq(id, concepts, level, stem, opts, teach, **kw):
    """opts: list of (text, correct, why)"""
    add(id=id, kind="mcq", concepts=concepts, level=level, stem=stem,
        options=[{"id": chr(97+i), "text": t, "correct": c, "why": w} for i, (t, c, w) in enumerate(opts)],
        teach=teach, **kw)

def multi(id, concepts, level, stem, opts, teach, **kw):
    add(id=id, kind="multi", concepts=concepts, level=level, stem=stem,
        options=[{"id": chr(97+i), "text": t, "correct": c, "why": w} for i, (t, c, w) in enumerate(opts)],
        teach=teach, **kw)

def contrast(id, concepts, level, prompt, left, right, probes, teach, **kw):
    """probes: list of (statement, 'L'|'R'|'B'|'N') -> which side it belongs to"""
    add(id=id, kind="contrast", concepts=concepts, level=level, stem=prompt,
        left=left, right=right,
        probes=[{"text": t, "side": s} for t, s in probes], teach=teach, **kw)

def rubric(id, concepts, level, stem, points, model, teach, traps=(), **kw):
    """points: list of (id, text, weight, [cues], tier)"""
    add(id=id, kind="rubric", concepts=concepts, level=level, stem=stem,
        rubric=[{"id": p[0], "text": p[1], "weight": p[2], "cues": p[3], "tier": p[4]} for p in points],
        traps=[{"cues": t[0], "msg": t[1]} for t in traps],
        model=model, teach=teach, **kw)

# ============================================================ REAL PAST PAPER: Surrey/CCCU 2016 Part 1
SRC16 = "University of Surrey & Canterbury Christ Church, Selection 2016 written test, Part 1"

mcq("pp16_1", ["p_value", "null_hypothesis"], "recall",
    "Which indicates the strongest evidence to reject the null hypothesis?",
    [("p = 0.027", False, "Below .05, so conventionally significant — but weaker evidence than .001."),
     ("p = 0.734", False, "No evidence against the null."),
     ("p = 0.001", True, "The smallest p-value: these data would be least likely under the null."),
     ("p = 1.000", False, "The data are exactly what the null predicts.")],
    "Smaller p means the observed data would be more surprising if the null were true. It does not mean a larger or more important effect — that is what effect size is for. A p of .001 from a trial of 4,000 people can accompany a change nobody would notice.",
    precision="The p-value is the probability of data at least this extreme IF the null were true.",
    source=SRC16, difficulty=1, time=30)

mcq("pp16_2", ["cross_sectional"], "recall",
    "Research that collects data at a single time-point is known as:",
    [("Cross-sectional design", True, "One time point, so prevalence and association but no temporal order."),
     ("Within-subjects design", False, "That describes participants contributing to more than one condition."),
     ("Repeated measures design", False, "The opposite — measurement on multiple occasions."),
     ("An ABA design", False, "A single-case design with phases across time.")],
    "The distractors are all repeated-measurement designs. The examiner is testing whether you hear 'single time-point' as the defining feature. Cross-sectional data cannot establish which variable came first, which is why cross-sectional evidence of association is so often over-read as causal.",
    source=SRC16, difficulty=1, time=30)

mcq("pp16_3", ["assumptions", "ttest_independent"], "recall",
    "Which assumption needs to be satisfied for a t-test to be valid?",
    [("All data were collected by the same researcher", False, "Not a statistical assumption."),
     ("The data are skewed", False, "The reverse of the requirement."),
     ("The data have an underlying normal distribution", True, "Strictly, the sampling distribution of the mean — which normality of the data secures."),
     ("There are more than 10 participants in the study", False, "No fixed threshold; a t-test is defined for small n.")],
    "Say 'approximately normal' and, if you want the precise version, 'normality of the sampling distribution of the mean'. With larger samples the central limit theorem makes the test robust to non-normal raw data — which is why 'the data must be perfectly normal' is a mark-losing overstatement. Independence of observations is the assumption whose violation cannot be repaired.",
    precision="Independence, approximate normality, and homogeneity of variance — with independence the least repairable.",
    source=SRC16, difficulty=2, time=40)

multi("pp16_4", ["causation", "clinical_significance", "control_group", "iv_dv"], "discriminate",
      "Which of the following statements are TRUE? (Select all that apply.)",
      [("Correlations do not determine causality", True, "Correct: association is necessary but not sufficient."),
       ("Clinical significance is no different than statistical significance", False, "They are independent. A trivial change can be statistically significant in a large sample."),
       ("Control groups always receive no interventions", False, "TAU, attention-matched and active comparators are all control conditions that involve intervention."),
       ("In an experiment, the independent variable is manipulated by the experimenter", True, "That manipulation is what distinguishes experimental from observational designs.")],
      "This is an all-or-nothing item in the real paper — you score only if you select every correct option and no incorrect one. Note that option C is the one candidates most often get wrong: in psychological trials the comparator is almost never 'nothing', and which comparator was used determines what the trial can claim.",
      source=SRC16, difficulty=2, time=50)

multi("pp16_5", ["variable_types"], "recall",
      "The outcome score on a standardised IQ test is an example of: (Select all that apply.)",
      [("Categorical data", False, "IQ is not an unordered category."),
       ("Interval data", True, "Equal intervals by construction, with no true zero."),
       ("Qualitative data", False, "It is numeric."),
       ("Quantitative data", True, "It is a numeric quantity.")],
      "Two answers. Level of measurement (interval) and data type (quantitative) are different classifications, and the item tests whether you hold both at once. Note the subtlety: IQ has no true zero, so it is interval rather than ratio — you cannot say one person has twice the intelligence of another.",
      source=SRC16, difficulty=2, time=40)

mcq("pp16_6", ["iv_dv"], "recognise",
    "In research the outcome variable is also known as:",
    [("The Independent Variable", False, "That is what is manipulated or classified."),
     ("The Dependent Variable", True, "It depends on the IV — it is what you measure."),
     ("The Predictor Variable", False, "A predictor sits on the IV side in non-experimental work."),
     ("The Extraneous Variable", False, "An uncontrolled variable that may affect the outcome.")],
    "Keep the two vocabularies apart. Experimental work: independent → dependent. Non-experimental work: predictor → outcome. Using 'predictor' does not license a causal claim, however much the word implies one.",
    source=SRC16, difficulty=1, time=25)

mcq("pp16_7", ["null_hypothesis"], "recognise",
    "Which of these is the null hypothesis?",
    [("There is an effect", False, "That is the alternative hypothesis."),
     ("There is no effect", True, "The formal proposition of no difference or no association."),
     ("The effect cannot be observed", False, "A statement about measurement, not about the population."),
     ("We don't know if there is an effect", False, "That is the state of ignorance the test addresses, not the hypothesis.")],
    "Note that we never 'accept' the null. Failure to reject it means the data were not sufficiently surprising — which is compatible with there being no effect and with the study being too small to detect one. 'No evidence of effect' is not 'evidence of no effect'.",
    precision="We reject or fail to reject the null; we never prove it.",
    source=SRC16, difficulty=1, time=25)

mcq("pp16_8", ["validity"], "recall",
    "Face validity is:",
    [("How much you agree with a response", False, "Not a psychometric property."),
     ("A way of making a diagnosis", False, "Unrelated."),
     ("The extent that a measure appears valid", True, "Whether it looks right, to a lay reader or respondent."),
     ("The level of agreement that exists between researchers", False, "That is inter-rater reliability.")],
    "Face validity is the weakest form — it concerns appearance only. It still matters practically, because a measure that looks irrelevant to respondents damages engagement and completion. Do not confuse it with content validity, which asks whether the items cover the whole construct.",
    source=SRC16, difficulty=2, time=35)

mcq("pp16_9", ["power", "sample_size"], "recall",
    "Statistical power is used to determine:",
    [("How many participants you need in a study", True, "An a priori power calculation converts the smallest effect of interest into a target sample size."),
     ("The correct statistical test", False, "That follows from the design and variable types."),
     ("The likelihood of a Type 1 Error", False, "That is alpha. Power concerns Type II error: power = 1 − beta."),
     ("The number of tests needed to get a significant result", False, "That describes p-hacking.")],
    "Power sits on the Type II side of the ledger. The four quantities — effect size, alpha, power, sample size — are locked together: fix any three and the fourth follows. That is the whole logic of a power calculation, and it is why 'we recruited as many as we could' is not a sample size justification.",
    source=SRC16, difficulty=2, time=40)

multi("pp16_10", ["consent", "ethics_approval"], "recall",
      "Participant information sheets should include: (Select all that apply.)",
      [("The purpose of the study", True, "Required for informed consent."),
       ("The researcher's personal mobile number", False, "A boundary violation; contact is through an institutional route."),
       ("A statement that participation is voluntary", True, "Voluntariness is a condition of valid consent."),
       ("The reasons why people have been asked to participate", True, "Participants must understand why they specifically were approached.")],
      "Informed consent has four components: capacity, adequate information, voluntariness, and the right to withdraw without consequence. The distractor tests professional boundaries, not statistics — selection tests routinely blend the two.",
      source=SRC16, difficulty=1, time=40)

# --- Q11-15: the RCT vignette
RCT_CTX = ("An RCT compared a new therapy for psychosis with a treatment-as-usual (TAU) control. Quality of life "
           "(QoL) was the primary outcome, higher scores indicating better QoL. The QoL data met the necessary "
           "assumptions and were analysed using ANOVA with the factors time (pre vs post) and group (new therapy "
           "vs TAU). Mean QoL before intervention was 35 (new therapy) and 34 (TAU). After intervention the "
           "new-therapy group scored 75 and the TAU group 33.")

mcq("pp16_11", ["interaction", "rm_anova"], "apply",
    "Which one of the following demonstrates that the change in QoL scores over time significantly differed between the two groups?",
    [("A significant main effect of group", False, "That says the groups differ on average across both time points — it could arise from a baseline difference alone."),
     ("A significant main effect of time", False, "That says scores changed overall, collapsing across groups — both groups improving would produce it."),
     ("A significant group by time interaction", True, "Differential change over time is, by definition, an interaction."),
     ("All of these effects being non-significant", False, "That would indicate no differential change.")],
    "This is the single highest-yield statistical idea in psychological trials. 'Did the groups change differently?' is always an interaction question. A main effect of time tells you everyone improved — which is exactly what regression to the mean, natural history and expectancy would also produce. The interaction is the only term that isolates differential change.",
    precision="Differential change over time between groups = the group × time interaction.",
    context=RCT_CTX, source=SRC16, difficulty=3, time=60)

mcq("pp16_12", ["ttest_independent", "post_hoc", "test_selection"], "apply",
    "Which follow-up test could you use to confirm that the QoL scores for the intervention group differ from those for the control group, at the post-intervention time point?",
    [("Cohen's kappa", False, "An index of inter-rater agreement, not a group comparison."),
     ("An independent samples t-test", True, "Two unrelated groups, one continuous outcome, at one time point."),
     ("A Wilcoxon signed rank test for matched pairs", False, "For related samples, and non-parametric — the stem states assumptions were met."),
     ("A paired sample t-test", False, "The two groups contain different people; they are not paired.")],
    "Walk the chain rather than pattern-matching: outcome is continuous → assumptions met → two groups → different people in each → independent-samples t-test. Candidates who reach for 'paired' are anchoring on the pre-post structure of the design instead of reading which comparison is actually being made.",
    context=RCT_CTX, source=SRC16, difficulty=3, time=60)

mcq("pp16_13", ["common_factors", "causation", "mechanism"], "discriminate",
    "Assuming that the correct test shows that this difference is significant, it is reasonable to conclude that:",
    [("The specific techniques used in the new therapy reduce QoL", False, "The direction is wrong — QoL rose — and specificity is not established."),
     ("The generic factors present in the new therapy (e.g. therapeutic alliance) reduce QoL", False, "Wrong direction again."),
     ("The new therapy seems effective, but it is not clear which components of it improve QoL", True, "A TAU comparator cannot separate specific technique from alliance, attention and expectancy."),
     ("The generic factors present in the new therapy improve QoL", False, "Attributes the effect to common factors specifically — equally unwarranted.")],
    "The comparator determines the claim. Against TAU you can say the package works; you cannot say which ingredient did the work. To attribute the effect to a specific technique you need an active comparator matched for attention, credibility and therapist contact. This single point converts an average interview answer into a strong one.",
    precision="TAU controls for time and natural change; only an active comparator isolates specific technique.",
    context=RCT_CTX, source=SRC16, difficulty=4, time=70)

mcq("pp16_14", ["effect_size", "meta_analysis"], "discriminate",
    "When presenting their findings the authors also report the 'effect size'. The main reason they include this is:",
    [("To allow the findings to be included in subsequent meta-analyses", True, "Of the four options, the only defensible one — pooling requires a standardised effect."),
     ("To indicate the direction of the effect", False, "Direction is already given by the means."),
     ("To highlight the level of statistical significance of the effect", False, "That is the p-value's job; effect size is deliberately independent of it."),
     ("To help tease apart the influence of generic and specific factors", False, "That is a design question, not an analysis one.")],
    "Worth noticing how this item behaves. The textbook reason to report an effect size is to convey magnitude independently of sample size — and that option is not offered. When no option matches your first answer, do not abandon your reasoning: eliminate. B, C and D are each demonstrably false, so A survives. That is the skill the item actually rewards, and it transfers directly to interview questions where the framing is not the one you prepared.",
    context=RCT_CTX, source=SRC16, difficulty=4, time=60)

mcq("pp16_15", ["external_validity", "sampling"], "discriminate",
    "In order for the findings of this study to be generalised to other people with psychosis, the most important thing is that:",
    [("A sufficiently large sample has been used to provide adequate power", False, "Size buys precision, not representativeness. A large biased sample is still biased."),
     ("The sample is sufficiently representative of people with psychosis", True, "Generalisability is governed by who was sampled, not how many."),
     ("The measure of QoL has good test re-test reliability", False, "A measurement property; necessary but not what limits generalisation."),
     ("The participants were not taking medication during the RCT", False, "Would reduce representativeness, since most people with psychosis take medication.")],
    "Sample size and sample representativeness answer different questions, and candidates conflate them constantly. Size → precision and power → internal statistical conclusion validity. Composition → external validity. A trial of 2,000 self-selected, medication-free, English-speaking volunteers generalises worse than a well-sampled trial of 200.",
    precision="Generalisability is a property of who was sampled, not of how many.",
    context=RCT_CTX, source=SRC16, difficulty=3, time=60)

# ============================================================ CONTRAST PAIRS
contrast("c_med_mod", ["mediation", "moderation"], "discriminate",
         "Sort each statement into the column where it belongs.",
         "Mediator (HOW / WHY)", "Moderator (FOR WHOM / WHEN)",
         [("Lies on the causal pathway between X and Y", "L"),
          ("Changes the strength or direction of the X–Y relationship", "R"),
          ("Tested statistically as an interaction term", "R"),
          ("Must be measured after X and before Y in time", "L"),
          ("Rumination explains why loneliness leads to low mood", "L"),
          ("Therapy works better for people with higher baseline motivation", "R"),
          ("Answers: through what process does the effect occur?", "L"),
          ("Answers: under what conditions does the effect hold?", "R"),
          ("Is a target for intervention if you want to change the mechanism", "L"),
          ("Is a basis for deciding who should be offered the intervention", "R")],
         "The one-line discriminator: a mediator is a link in the chain, a moderator is a dial on the chain. Two consequences follow that interviewers probe. First, temporal order — a mediator must be measured between X and Y, so a cross-sectional 'mediation analysis' cannot establish mediation whatever the software reports. Second, a variable can only mediate an effect that exists, so mediation analysis presupposes the effect.",
         precision="Mediator = mechanism, on the pathway. Moderator = condition, interacts with the pathway.",
         difficulty=3, time=110)

contrast("c_rel_val", ["reliability", "validity"], "discriminate",
         "Sort each statement into the column where it belongs.",
         "Reliability (consistency)", "Validity (is it the right thing?)",
         [("Cronbach's alpha of .89 across the items", "L"),
          ("Scores correlate .81 with a diagnostic interview", "R"),
          ("Two raters agree on 85% of the codings", "L"),
          ("The scale predicts who is admitted within six months", "R"),
          ("Test-retest correlation of .90 over two weeks", "L"),
          ("The items look relevant to respondents", "R"),
          ("Can be high while the measure captures the wrong construct", "L"),
          ("Cannot exceed what the measure's consistency permits", "R"),
          ("The items cover every facet of the construct", "R")],
         "A bathroom scale that reads 4 kg heavy every time is perfectly reliable and invalid. The asymmetry is the examinable point: reliability is necessary but not sufficient for validity, and unreliability places a ceiling on the validity a measure can achieve. This is why a Cronbach's alpha of .40 — as in the Birmingham 2014 exercise — sinks any conclusion drawn from that measure before you even look at its scores.",
         precision="Reliability is necessary but not sufficient for validity; unreliability caps validity.",
         difficulty=2, time=100)

contrast("c_inc_prev", ["incidence", "prevalence"], "discriminate",
         "Sort each statement into the column where it belongs.",
         "Incidence", "Prevalence",
         [("New cases arising over a defined period", "L"),
          ("All existing cases at a point in time", "R"),
          ("Rises if a treatment keeps people alive longer without curing them", "R"),
          ("The natural output of a cohort study", "L"),
          ("What a single cross-sectional survey measures", "R"),
          ("Falls if a prevention programme works", "L"),
          ("Approximately incidence multiplied by average duration", "R"),
          ("Unaffected by how long the condition lasts", "L")],
         "The trap is 'a rise in prevalence means more people are becoming unwell'. It may instead mean people are staying unwell for longer, or surviving longer, or being identified more. Prevalence ≈ incidence × duration. To make a claim about whether a problem is genuinely growing, you need incidence — and that requires following people over time.",
         precision="Incidence = new cases per period. Prevalence = existing cases, a function of incidence and duration.",
         difficulty=3, time=90)

contrast("c_cbt_act", ["cbt_model", "act", "defusion"], "discriminate",
         "Sort each therapeutic move into the model it belongs to.",
         "CBT", "ACT",
         [("Examine the evidence for and against the thought", "L"),
          ("Notice the thought as a thought and let it be present", "R"),
          ("Design an experiment to test a specific prediction", "L"),
          ("Ask what happens to your life when this thought is in charge", "R"),
          ("Identify the cognitive distortion in the appraisal", "L"),
          ("Clarify what you want to stand for and act on it now", "R"),
          ("Target the accuracy or helpfulness of the belief", "L"),
          ("Target the person's relationship with the belief", "R"),
          ("Build willingness to have discomfort in service of a value", "R"),
          ("Drop safety behaviours so the feared outcome can disconfirm", "L")],
         "The clean contrast: CBT asks 'is this thought accurate or helpful?'; ACT asks 'what happens when this thought runs your behaviour?'. ACT does not dispute content at all. The overlap is real though — both are behavioural, both use exposure-like procedures, and modern CBT uses behavioural experiments rather than disputation. In interview, name the shared behavioural spine and then the divergence in target, and you will be ahead of most candidates.",
         precision="CBT targets the content or usefulness of cognition; ACT targets the person's relationship to it.",
         difficulty=3, time=110)

contrast("c_cbt_sys", ["cbt_model", "systemic", "circular_causality"], "discriminate",
         "A parent becomes increasingly protective as their child's anxiety increases. Sort each statement by the lens it comes from.",
         "CBT lens", "Systemic lens",
         [("The child's threat appraisal drives avoidance", "L"),
          ("Each person's response is both a reaction to and a trigger for the other's", "R"),
          ("Accommodation removes opportunities for disconfirmation", "L"),
          ("The pattern maintains itself with no identifiable first cause", "R"),
          ("The problem is located in the child's cognitive-behavioural cycle", "L"),
          ("The parent's protectiveness is meaningful given their own history and fears", "R"),
          ("Intervention: graded behavioural experiments for the child", "L"),
          ("Intervention: work with the interactional sequence in the room", "R"),
          ("Ask who else in the wider system is invested in the child staying safe", "R")],
         "What the systemic lens adds here is that the parent is not an obstacle to the child's treatment but a participant in a loop that makes sense from their position. What it can overlook is the specific mechanism — accommodation blocking disconfirmation — that CBT names precisely, and the individual's internal experience. Cardiff, UCL and UEA all ask for a formulation from a second, non-CBT model; this pair is the highest-frequency version of that question.",
         precision="Linear causality asks what caused what; circular causality describes a self-maintaining recursive sequence.",
         difficulty=4, time=120)

contrast("c_audit_eval_res", ["service_evaluation"], "discriminate",
         "Sort each description into the right governance category.",
         "Audit / service evaluation", "Research",
         [("Compares current practice against an existing standard", "L"),
          ("Aims to produce generalisable new knowledge", "R"),
          ("Requires NHS Research Ethics Committee review", "R"),
          ("Asks how well this service is doing what it already intends to do", "L"),
          ("Allocates people to conditions to test a hypothesis", "R"),
          ("Uses data already collected in routine care", "L"),
          ("Findings are intended to transfer beyond this service", "R"),
          ("Registered through local clinical governance", "L")],
         "This distinction is examinable because it is a real decision trainees must make. The test is intent: are you measuring against an existing standard or describing your own service (audit/evaluation), or generating knowledge intended to transfer (research)? Note that the distinction governs the governance route, not the rigour — a service evaluation should still be methodologically sound, and calling something an evaluation to avoid ethics review is a governance breach.",
         difficulty=3, time=95)

contrast("c_rtm_effect", ["regression_to_mean", "natural_history", "control_group"], "discriminate",
         "A service selects the 20 most distressed people on its waiting list, offers a workshop, and finds scores significantly improved at follow-up. Sort each statement.",
         "Explains the improvement WITHOUT the workshop working", "Requires the workshop to have worked",
         [("Those selected for extreme scores regress toward the mean on retest", "L"),
          ("Part of the original extremity was measurement error and transient state", "L"),
          ("Many conditions remit without intervention over the same period", "L"),
          ("Being offered help raised expectancy of improvement", "L"),
          ("Repeated completion of the measure changes how people respond", "L"),
          ("The specific skills taught produced the change", "R"),
          ("The change exceeded that seen in a matched untreated comparison", "R")],
         "Selecting on an extreme score guarantees apparent improvement — this is arithmetic, not psychology. Six of these seven alternatives are available to any uncontrolled pre-post evaluation, which is why the design cannot support a claim that the intervention worked. In interview the strong move is not to list these but to say what would settle it: a comparison group selected the same way and measured the same way.",
         precision="Regression to the mean is created by selection on extremity, not by the passage of time.",
         difficulty=4, time=110)

contrast("c_capacity_mha", ["mca", "mha", "capacity"], "discriminate",
         "Sort each situation into the legal framework that primarily applies.",
         "Mental Capacity Act", "Mental Health Act",
         [("A man with advanced dementia cannot weigh a decision about a feeding tube", "L"),
          ("A woman with psychosis is detained for assessment of her mental disorder", "R"),
          ("Deciding where someone who lacks capacity should live, in their best interests", "L"),
          ("Treatment for mental disorder given against the wishes of a person with capacity", "R"),
          ("An unwise but capacitous decision to leave hospital against advice", "L"),
          ("Continuous supervision and control of a person who lacks capacity, not free to leave", "L"),
          ("Section 117 aftercare following discharge from treatment detention", "R")],
         "The dividing line: the MCA is about decision-making ability, and only engages where capacity is absent; the MHA is about detention and treatment for mental disorder, and can apply to someone who retains capacity. Two precision traps interviewers use — an unwise decision is not evidence of incapacity, and capacity is decision-specific and time-specific rather than a global status.",
         precision="MCA engages on absence of capacity. MHA engages on mental disorder and risk, capacity notwithstanding.",
         difficulty=4, time=105)

contrast("c_equity", ["equity_equality", "access_inequality"], "discriminate",
         "Sort each service response.",
         "Equality (same for all)", "Equity (according to need)",
         [("Every referral is offered the same six-session package", "L"),
          ("Interpreter time is funded so appointment length is genuinely comparable", "R"),
          ("The leaflet is translated into the eight most common local languages", "R"),
          ("Appointments are offered 9–5 to everyone equally", "L"),
          ("Evening slots are protected for people who cannot take unpaid leave", "R"),
          ("The same self-referral website is available to the whole borough", "L"),
          ("Outreach clinics are placed in the two most deprived wards", "R")],
         "The examinable line: offering an identical service to unequal starting positions preserves the inequality and calls it fairness. Every item in the left column is defensible and none is neutral in effect. The strong candidate names the mechanism — who is actually excluded by this arrangement, and what does that predict about who reaches us.",
         difficulty=3, time=90)

# ============================================================ TEST-SELECTION LADDERS
def ladder(id, concepts, scenario, rungs, answer, teach, **kw):
    """rungs: list of dicts {q, options:[(text,correct,why)]}"""
    add(id=id, kind="ladder", concepts=concepts, level="transfer", stem=scenario,
        rungs=[{"q": r[0], "options": [{"id": chr(97+i), "text": t, "correct": c, "why": w}
                                       for i, (t, c, w) in enumerate(r[1])]} for r in rungs],
        answer=answer, teach=teach, **kw)

LADDER_NOTE = ("Walk the chain every time: question → outcome type → groups or time points → independent or "
               "related → assumptions → test → what it establishes → what it cannot.")

ladder("l_1", ["test_selection", "ttest_paired", "clinical_significance"],
       "Your service runs an eight-week CBT group for social anxiety. Everyone completes the SPIN (a continuous "
       "symptom measure) at session one and at session eight. There is no comparison group. The service manager "
       "asks you whether the group works.",
       [("What is the outcome variable's type?",
         [("Continuous", True, "SPIN total is a continuous score."),
          ("Categorical", False, "Not a category — it is a total score."),
          ("Ordinal only", False, "Treated as continuous by convention and by the measure's construction.")]),
        ("How many measurement occasions, and from whom?",
         [("Two occasions, same people", True, "Pre and post from each participant."),
          ("Two independent groups", False, "There is only one group here."),
          ("Three or more occasions", False, "Only session one and session eight.")]),
        ("So are the observations independent or related?",
         [("Related — each person contributes both scores", True, "This is what makes the comparison paired."),
          ("Independent — different scores are different data points", False, "The two scores come from the same person and are correlated.")]),
        ("Which test answers 'did scores change?'",
         [("Paired-samples t-test", True, "Two related measurements on a continuous outcome."),
          ("Independent-samples t-test", False, "Would treat the same people as two separate groups."),
          ("Repeated-measures ANOVA", False, "Defensible with three or more occasions; unnecessary for two."),
          ("Chi-square", False, "For categorical data.")]),
        ("What can a significant result establish?",
         [("That scores changed more than would be expected by chance", True, "That is all the design supports."),
          ("That the CBT group caused the improvement", False, "No comparator: regression to the mean, natural history and expectancy are all live."),
          ("That the change matters clinically", False, "That requires reliable change or an MCID, not a p-value.")])],
       "Paired-samples t-test — with the finding reported as 'scores improved' and explicitly not as 'the group worked'.",
       "The statistics here are the easy part; the answer that distinguishes candidates is the last rung. An "
       "uncontrolled pre-post design cannot separate the intervention from regression to the mean, natural history, "
       "expectancy or repeated testing. Say so, then say what you would add — a waiting-list comparison, a benchmarked "
       "comparison against published effect sizes, or reliable change indices at the individual level — and you have "
       "given a research-supervisor answer rather than a student one.",
       difficulty=2, time=180)

ladder("l_2", ["test_selection", "interaction", "rm_anova", "itt"],
       "A CAMHS service pilots a new parent-led anxiety intervention. Forty families are randomised to the new "
       "intervention or to the standard clinician-led pathway. Child anxiety (a continuous measure) is collected at "
       "baseline, at end of treatment, and at three-month follow-up. Six families in the new arm and two in the "
       "standard arm drop out before the end of treatment.",
       [("What is the primary question the design is built to answer?",
         [("Did the two arms change differently over time?", True, "Randomisation to two arms with repeated measurement."),
          ("Did anxiety fall overall?", False, "True but uninformative — both arms would be expected to fall."),
          ("Which families improved most?", False, "A secondary, exploratory question.")]),
        ("How many factors, and of what kind?",
         [("Two: group (between-subjects) and time (within-subjects)", True, "A mixed design."),
          ("One: time", False, "Ignores the randomisation, which is the point of the study."),
          ("Two, both between-subjects", False, "Time is measured within the same families.")]),
        ("Which term tests the study's actual question?",
         [("The group × time interaction", True, "Differential change is always an interaction."),
          ("The main effect of time", False, "Both arms improving would produce this."),
          ("The main effect of group", False, "Could reflect a baseline imbalance.")]),
        ("How should the eight dropouts be handled?",
         [("Intention-to-treat, analysing families in the arm they were randomised to", True, "Preserves randomisation and estimates the effect of offering the intervention."),
          ("Analyse only families who completed", False, "Per-protocol: breaks randomisation and typically flatters the intervention."),
          ("Exclude them and note it in the limitations", False, "Same problem, with the bias acknowledged but not addressed.")]),
        ("What does the differential attrition itself tell you?",
         [("It is a finding about acceptability, not only a nuisance", True, "Three times the dropout in the new arm is data about whether families can tolerate it."),
          ("Nothing, provided the analysis is ITT", False, "ITT handles the estimate; it does not make the pattern uninteresting."),
          ("That the new intervention is ineffective", False, "It speaks to acceptability, not efficacy.")])],
       "Mixed (2 × 3) ANOVA — or a linear mixed model, which handles missing occasions better — with the group × time interaction as the primary term, analysed by intention to treat.",
       "Two moves lift this answer. First, naming the interaction as the test of the actual question rather than "
       "reporting main effects. Second, treating differential attrition as a finding: in a pilot, whether families "
       "can tolerate the intervention is arguably more important than the effect estimate, because a pilot exists to "
       "establish feasibility and acceptability, not efficacy. If you want the advanced version, mention that a "
       "linear mixed model uses all available data under a missing-at-random assumption rather than discarding "
       "incomplete cases.",
       difficulty=4, time=240)

ladder("l_3", ["test_selection", "chi_square", "variable_types", "absolute_relative_risk"],
       "You are evaluating whether a new opt-out booking system changes whether people attend their first "
       "appointment. You have 600 referrals from the six months before the change and 640 from the six months after. "
       "For each referral you know whether the person attended, did not attend, or cancelled in advance.",
       [("What kind of outcome variable is 'attended / DNA / cancelled'?",
         [("Categorical with three unordered levels", True, "Nominal categories, not a quantity."),
          ("Ordinal", False, "There is no inherent rank order among these three."),
          ("Continuous", False, "It is not a measured quantity.")]),
        ("What kind of comparison is being made?",
         [("Two independent groups of referrals, before and after", True, "Different referrals in each period."),
          ("Paired — the same people before and after", False, "These are different referrals."),
          ("One group measured twice", False, "Same error.")]),
        ("Which test fits?",
         [("Chi-square test of association", True, "Categorical outcome by categorical group, independent observations."),
          ("Independent-samples t-test", False, "Requires a continuous outcome."),
          ("McNemar's test", False, "For paired categorical data — the right answer if the same people were followed."),
          ("Correlation", False, "Not a test of association between two nominal variables here.")]),
        ("What is the main threat to concluding the system caused the change?",
         [("Anything else that changed between the two periods", True, "A before-and-after design is confounded with time — staffing, season, referral criteria, publicity."),
          ("The sample is too small", False, "1,240 referrals is ample for this comparison."),
          ("Chi-square is not powerful enough", False, "Power is not the limiting issue here.")]),
        ("Beyond significance, what should you report?",
         [("The absolute difference in attendance rates, and what it means in appointments", True, "Absolute change drives service relevance and is what a manager can act on."),
          ("Only the p-value", False, "With 1,240 referrals, trivial differences reach significance."),
          ("The relative risk alone", False, "Relative figures can look dramatic on a small base rate.")])],
       "Chi-square test of association, reported with absolute attendance rates and the difference in appointments per year — and framed as a service evaluation with a time-confounded design, not a trial.",
       "Notice what makes this an interview answer rather than a statistics answer: the design is a before-and-after "
       "comparison, so the intervention is completely confounded with time. Everything else that changed in those six "
       "months rides along with the result. Say that, propose what would strengthen it — a stepped-wedge rollout "
       "across teams, or an interrupted time series with multiple pre-change data points — and translate the effect "
       "into appointments recovered per year, because that is the currency in which the finding will be used.",
       difficulty=4, time=240)

ladder("l_4", ["qualitative_designs", "epistemology", "saturation", "reflexivity"],
       "You want to understand why young Black men in your locality disengage from the early intervention in "
       "psychosis service after one or two appointments. Routine data show the differential clearly; nobody knows why.",
       [("What kind of question is this?",
         [("Exploratory — about meaning and experience", True, "The 'why' here concerns how disengagement is experienced and made sense of."),
          ("Confirmatory — testing a stated hypothesis", False, "No candidate mechanism is specified."),
          ("Descriptive — how many disengage", False, "Already known from routine data.")]),
        ("Which methodology fits best?",
         [("Reflexive thematic analysis across accounts", True, "Patterns of meaning across a group, allowing a diverse sample and a service-relevant output."),
          ("IPA", False, "Defensible, but IPA requires a homogeneous sample and yields idiographic depth rather than service-level patterns."),
          ("Grounded theory", False, "Appropriate only if you intend to generate a theory with theoretical sampling to saturation."),
          ("A survey with open comment boxes", False, "Will not reach the accounts of people who have already left.")]),
        ("What epistemological position should you state?",
         [("Critical realist — real experiences and real structures, accessed through interpretation", True, "Coherent with claiming that racism has real effects while treating accounts as interpreted."),
          ("Naive realist — the interviews reveal the truth directly", False, "Incoherent with interpretative analysis."),
          ("Radical constructionist", False, "Defensible, but sits awkwardly with making service recommendations about real differentials.")]),
        ("What is the most serious threat to the credibility of this study?",
         [("Who conducts the interviews, and the power relations in the encounter", True, "A service clinician asking why people left the service will get a curated answer."),
          ("The sample size", False, "Qualitative adequacy is about richness and information power, not n."),
          ("Lack of a control group", False, "Not a relevant concept for this design.")]),
        ("How should reflexivity be handled?",
         [("Documented systematically — positionality, reflexive journal, team discussion of interpretations", True, "Evidenced, not declared."),
          ("A sentence in the limitations acknowledging the researcher's background", False, "The most common weak version."),
          ("By the researcher striving to be objective", False, "Incoherent with a qualitative epistemology.")])],
       "Reflexive thematic analysis from a critical realist position, with peer or community interviewers, purposive sampling for information power, a documented reflexive process, and co-production with people who have used the service.",
       "The examinable insight is that the method is not the hard part — the power relations in data collection are. "
       "If the service asks people why they left the service, the design has built the answer into the encounter. "
       "Proposing peer researchers or community-based interviewers, and co-producing the topic guide, shows you "
       "understand that qualitative rigour is about the conditions of production, not just the analysis. Note too "
       "that 'saturation' is a grounded theory concept that sits uneasily in reflexive TA — using it loosely is a "
       "precision error interviewers notice.",
       difficulty=5, time=270)

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "trainer", "data", "items_research.json")
ids = [x["id"] for x in IT]
assert len(ids) == len(set(ids)), "dupes"
concepts = {c["id"] for c in json.load(open(os.path.join(os.path.dirname(OUT), "concepts.json")))["nodes"]}
for x in IT:
    for c in x["concepts"]:
        assert c in concepts, f"{x['id']} -> unknown concept {c}"
json.dump({"version": 1, "items": IT}, open(OUT, "w"), indent=1, ensure_ascii=False)
print(f"{len(IT)} research items -> {OUT}")
from collections import Counter
print(Counter(x["kind"] for x in IT), Counter(x["level"] for x in IT))
