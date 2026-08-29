# -*- coding: utf-8 -*-
"""Concept graph for the DClinPsy trainer.

Each node carries a `precision` string (the exact, defensible formulation) and a
`notThis` list (the near-miss statements that lose marks). This is the mechanism
behind the engine's precision correction: when an answer is directionally right
but technically loose, the engine can name the exact imprecision.
"""
import json, os

# id, label, cluster, tier(1=core,2=important,3=extending), precision, notThis[], parents[], related[]
R = "research"; C = "clinical"; P = "professional"

N = []
def n(id, label, domain, cluster, tier, precision, notThis=(), parents=(), related=()):
    N.append(dict(id=id, label=label, domain=domain, cluster=cluster, tier=tier,
                  precision=precision, notThis=list(notThis),
                  parents=list(parents), related=list(related)))

# ---------------------------------------------------------------- INFERENCE
n("null_hypothesis", "Null hypothesis", R, "inference", 1,
  "The formal proposition of no effect or no difference in the population, held as true for the purpose of calculating how surprising the observed data would be.",
  ["the hypothesis you expect to be false", "the opposite of what you predict", "a statement that the effect cannot be observed"],
  [], ["p_value", "type1", "type2"])

n("p_value", "p-value", R, "inference", 1,
  "The probability of obtaining data at least as extreme as those observed, IF the null hypothesis were true.",
  ["the probability that the null hypothesis is true",
   "the probability the result occurred by chance",
   "the probability the finding will replicate",
   "the size or the importance of the effect"],
  ["null_hypothesis"], ["alpha", "type1", "confidence_interval", "effect_size", "clinical_significance"])

n("alpha", "Alpha / significance level", R, "inference", 1,
  "The pre-set threshold for the long-run false-positive rate the researcher is willing to accept, conventionally .05.",
  ["the probability the study is wrong", "a measure of how large the effect is"],
  ["p_value"], ["type1", "multiple_comparisons"])

n("type1", "Type I error", R, "inference", 1,
  "Rejecting a null hypothesis that is in fact true — concluding there is an effect when there is none. Its long-run rate is set by alpha.",
  ["missing a real effect", "a mistake in the data entry", "the same thing as a small p-value"],
  ["alpha"], ["type2", "multiple_comparisons", "power"])

n("type2", "Type II error", R, "inference", 1,
  "Failing to reject a null hypothesis that is in fact false — missing a real effect. Its rate is beta; power = 1 − beta.",
  ["finding an effect that is not there", "a biased sample"],
  ["null_hypothesis"], ["power", "type1", "sample_size"])

n("power", "Statistical power", R, "inference", 1,
  "The probability that a study will detect an effect of a specified size, given the sample size and alpha, if that effect genuinely exists. Conventionally targeted at .80 or above.",
  ["the strength of the effect", "how convincing the study is", "the number of participants"],
  ["type2"], ["sample_size", "effect_size", "underpowered"])

n("underpowered", "Under-powered study", R, "inference", 2,
  "A study with too few participants to reliably detect the effect of interest: it inflates Type II error, and among the significant results it does produce, effect sizes are systematically over-estimated (the winner's curse).",
  ["a study with a small effect", "a study that failed"],
  ["power"], ["type2", "effect_size", "pilot_feasibility"])

n("confidence_interval", "Confidence interval", R, "inference", 1,
  "A range constructed so that, over repeated sampling, 95% of such intervals would contain the true population parameter. Its width indexes precision; whether it crosses the null value maps onto significance.",
  ["a 95% chance the true value is in this interval", "the range in which 95% of participants scored"],
  ["p_value"], ["effect_size", "precision_estimate", "sample_size"])

n("effect_size", "Effect size", R, "inference", 1,
  "A standardised index of the magnitude of a difference or association that is independent of sample size — e.g. Cohen's d, r, odds ratio.",
  ["whether the result was significant", "how important the finding is clinically"],
  [], ["clinical_significance", "meta_analysis", "confidence_interval", "p_value"])

n("clinical_significance", "Clinical vs statistical significance", R, "inference", 1,
  "Statistical significance says an effect is unlikely under the null; clinical significance asks whether the change is large enough to matter in the person's life. They are independent: a trivial change can be significant in a large sample, and an important change non-significant in a small one.",
  ["clinical significance is just a large p-value", "they are different words for the same idea"],
  ["effect_size"], ["reliable_change", "mcid", "p_value"])

n("reliable_change", "Reliable change index", R, "inference", 2,
  "A statistic testing whether an individual's pre-post change exceeds what would be expected from measurement error alone, computed from the measure's standard error of difference.",
  ["any improvement on the score", "a group-level effect size"],
  ["clinical_significance"], ["mcid", "measurement_error"])

n("mcid", "Minimal clinically important difference", R, "inference", 3,
  "The smallest change in an outcome that patients or clinicians would identify as meaningful, established empirically rather than assumed.",
  ["the smallest statistically detectable change"],
  ["clinical_significance"], ["reliable_change"])

n("multiple_comparisons", "Multiple comparisons", R, "inference", 2,
  "Running many tests inflates the family-wise probability of at least one false positive; corrections (Bonferroni, Holm, FDR) or pre-specification of a primary outcome control this.",
  ["a problem only when the sample is small"],
  ["alpha", "type1"], ["p_hacking", "preregistration"])

n("p_hacking", "p-hacking & researcher degrees of freedom", R, "inference", 3,
  "Analytic flexibility exploited, knowingly or not, until a result crosses threshold — optional stopping, outcome switching, subgroup fishing.",
  ["deliberate fraud only"],
  ["multiple_comparisons"], ["preregistration", "publication_bias"])

n("preregistration", "Pre-registration", R, "inference", 3,
  "Public, time-stamped specification of hypotheses, outcomes and analysis before data collection, which converts exploratory analyses into declared ones.",
  ["ethics approval"],
  [], ["p_hacking", "publication_bias"])

# ---------------------------------------------------------------- VARIABLES & TESTS
n("variable_types", "Levels of measurement", R, "tests", 1,
  "Nominal (unordered categories), ordinal (ranked without equal intervals), interval (equal intervals, arbitrary zero), ratio (equal intervals, true zero). The level constrains which analyses are legitimate.",
  ["all numbers are continuous data", "Likert items are always interval"],
  [], ["test_selection", "nonparametric"])

n("iv_dv", "Independent vs dependent variable", R, "tests", 1,
  "The independent variable is manipulated or classified by the researcher; the dependent (outcome) variable is measured and predicted. In non-experimental work the parallel terms are predictor and outcome.",
  ["the IV is the one you measure", "predictor and outcome imply causation"],
  [], ["variable_types", "experiment_vs_observation"])

n("test_selection", "Test selection logic", R, "tests", 1,
  "The chain that determines analysis: research question → outcome variable type → number of groups or time points → independent or related samples → assumptions met → test → what it can and cannot establish.",
  ["memorising which test goes with which name", "choosing the test after seeing the data"],
  ["variable_types", "iv_dv"], ["ttest_independent", "ttest_paired", "anova", "chi_square", "correlation", "regression", "nonparametric", "assumptions"])

n("ttest_independent", "Independent-samples t-test", R, "tests", 1,
  "Compares the means of one continuous outcome between two unrelated groups.",
  ["compares two measurements from the same people", "compares more than two groups"],
  ["test_selection"], ["ttest_paired", "mann_whitney", "assumptions"])

n("ttest_paired", "Paired-samples t-test", R, "tests", 1,
  "Compares two related measurements — the same participants at two time points, or matched pairs — by testing whether the mean of the difference scores departs from zero.",
  ["compares two separate groups", "is used whenever there are two conditions"],
  ["test_selection"], ["ttest_independent", "wilcoxon", "rm_anova"])

n("anova", "ANOVA", R, "tests", 1,
  "Compares means across three or more levels of a factor, or across factors simultaneously, by partitioning variance. A significant omnibus F indicates a difference somewhere, not where.",
  ["tells you which groups differ", "can only handle one factor"],
  ["test_selection"], ["rm_anova", "interaction", "post_hoc", "kruskal_wallis"])

n("rm_anova", "Repeated-measures / mixed ANOVA", R, "tests", 2,
  "Handles designs where the same participants are measured repeatedly; a mixed design combines a within-subjects factor (time) with a between-subjects factor (group).",
  ["the same as a one-way ANOVA", "requires independent observations"],
  ["anova"], ["interaction", "sphericity", "ttest_paired"])

n("interaction", "Interaction effect", R, "tests", 1,
  "Occurs when the effect of one factor depends on the level of another. In a pre-post by group trial, the group-by-time interaction — not either main effect — is the test of differential change.",
  ["a main effect of group", "the average difference between groups"],
  ["rm_anova"], ["moderation", "anova"])

n("post_hoc", "Post-hoc tests", R, "tests", 2,
  "Follow-up comparisons after a significant omnibus test, with correction for the number of comparisons made.",
  ["planned contrasts specified in advance"],
  ["anova"], ["multiple_comparisons"])

n("chi_square", "Chi-square", R, "tests", 1,
  "Tests association between categorical variables by comparing observed against expected cell frequencies; requires adequate expected counts.",
  ["compares means", "works on continuous outcomes"],
  ["test_selection"], ["variable_types", "fisher_exact"])

n("fisher_exact", "Fisher's exact test", R, "tests", 3,
  "The exact alternative to chi-square when expected cell counts are small.", [],
  ["chi_square"], [])

n("correlation", "Correlation", R, "tests", 1,
  "Quantifies the strength and direction of a linear (Pearson) or monotonic (Spearman) association between two variables, on a scale from −1 to +1.",
  ["shows that one variable causes the other", "a correlation of 0 means no relationship of any kind"],
  ["test_selection"], ["causation", "regression", "confounding"])

n("regression", "Regression", R, "tests", 1,
  "Models an outcome from one or more predictors, giving the change in outcome per unit change in a predictor while holding the others constant. Logistic regression models a binary outcome as log-odds.",
  ["establishes causation because it uses the word predictor", "requires an experimental design"],
  ["correlation"], ["mediation", "moderation", "confounding", "multicollinearity"])

n("multicollinearity", "Multicollinearity", R, "tests", 3,
  "High intercorrelation among predictors, which destabilises individual coefficients without necessarily harming overall prediction.", [],
  ["regression"], [])

n("nonparametric", "Non-parametric alternatives", R, "tests", 2,
  "Rank-based tests used when distributional assumptions fail or data are ordinal: Mann-Whitney for two independent groups, Wilcoxon signed-rank for paired data, Kruskal-Wallis for three or more independent groups, Friedman for repeated measures.",
  ["tests that make no assumptions at all", "always the safer choice"],
  ["assumptions"], ["mann_whitney", "wilcoxon", "kruskal_wallis"])

n("mann_whitney", "Mann-Whitney U", R, "tests", 2, "Rank-based comparison of two independent groups.", [], ["nonparametric"], ["ttest_independent"])
n("wilcoxon", "Wilcoxon signed-rank", R, "tests", 2, "Rank-based comparison of two related measurements.", [], ["nonparametric"], ["ttest_paired"])
n("kruskal_wallis", "Kruskal-Wallis", R, "tests", 3, "Rank-based comparison of three or more independent groups.", [], ["nonparametric"], ["anova"])

n("assumptions", "Assumptions of parametric tests", R, "tests", 1,
  "Independence of observations, an approximately normal sampling distribution of the outcome, homogeneity of variance across groups, and — for repeated measures — sphericity. Independence is the assumption whose violation is least repairable.",
  ["the raw data must be perfectly normal", "assumptions matter only in small samples"],
  [], ["nonparametric", "sphericity", "test_selection"])

n("sphericity", "Sphericity", R, "tests", 3,
  "The requirement in repeated-measures designs that variances of the differences between all pairs of levels are equal; corrected with Greenhouse-Geisser when violated.", [],
  ["assumptions"], ["rm_anova"])

# ---------------------------------------------------------------- DESIGN
n("experiment_vs_observation", "Experimental vs observational", R, "design", 1,
  "In an experimental design the researcher manipulates the independent variable and controls allocation; in an observational design exposure is not assigned, so causal claims depend on assumptions that cannot be verified.",
  ["observational means qualitative", "experiments are always laboratory-based"],
  ["iv_dv"], ["rct", "cohort", "case_control", "cross_sectional", "causation"])

n("rct", "Randomised controlled trial", R, "design", 1,
  "Random allocation to conditions distributes both known and unknown confounders across arms in expectation, which is what licenses causal inference about the intervention.",
  ["the best design for every question", "randomisation guarantees the groups are identical"],
  ["experiment_vs_observation"], ["allocation_concealment", "blinding", "itt", "control_group", "cluster_rct"])

n("cluster_rct", "Cluster RCT", R, "design", 3,
  "Randomises intact groups — wards, schools, practices — rather than individuals, which controls contamination but requires analysis that accounts for clustering.",
  ["can be analysed as if individuals were randomised"],
  ["rct"], ["contamination"])

n("control_group", "Control and comparison conditions", R, "design", 1,
  "Treatment as usual controls for time and natural change but not for attention or expectancy; an active or attention-matched comparator additionally controls for non-specific factors; a waitlist controls for the least and inflates apparent effects.",
  ["control groups always receive no intervention", "TAU and placebo are equivalent"],
  ["rct"], ["common_factors", "blinding"])

n("allocation_concealment", "Allocation concealment", R, "design", 2,
  "Preventing those enrolling participants from knowing the upcoming allocation, which protects randomisation itself — distinct from blinding, which operates after allocation.",
  ["the same thing as blinding"],
  ["rct"], ["blinding", "selection_bias"])

n("blinding", "Blinding / masking", R, "design", 1,
  "Keeping participants, deliverers or assessors unaware of allocation. In psychological trials participants and therapists usually cannot be blinded, so blind outcome assessment is the achievable safeguard against detection bias.",
  ["impossible in psychological research so it does not matter", "double-blind is achievable in psychotherapy trials"],
  ["rct"], ["detection_bias", "control_group"])

n("itt", "Intention-to-treat analysis", R, "design", 2,
  "Analysing participants in the group to which they were randomised regardless of what they received, preserving the randomisation and giving an unbiased estimate of the effect of offering treatment.",
  ["analysing only those who completed treatment", "the same as per-protocol analysis"],
  ["rct"], ["attrition", "missing_data", "per_protocol"])

n("per_protocol", "Per-protocol analysis", R, "design", 3,
  "Restricting analysis to those who adhered, which breaks randomisation and typically flatters the intervention.",
  ["the more accurate estimate of true efficacy"],
  ["itt"], ["attrition"])

n("cohort", "Cohort study", R, "design", 2,
  "Follows a group defined by exposure status forward in time to observe incidence of outcomes.",
  ["the same as a case-control study", "can establish causation on its own"],
  ["experiment_vs_observation"], ["case_control", "longitudinal", "incidence"])

n("case_control", "Case-control study", R, "design", 2,
  "Starts from outcome status and looks backwards at exposure; efficient for rare outcomes but vulnerable to recall and selection bias, and cannot yield incidence.",
  ["follows people forwards", "gives relative risk directly"],
  ["experiment_vs_observation"], ["cohort", "recall_bias"])

n("cross_sectional", "Cross-sectional design", R, "design", 1,
  "Collects data at a single time point, giving prevalence and association but no information about temporal order.",
  ["the same as a within-subjects design", "can establish which variable came first"],
  ["experiment_vs_observation"], ["longitudinal", "prevalence", "causation"])

n("longitudinal", "Longitudinal design", R, "design", 1,
  "Measures the same participants on more than one occasion, establishing temporal precedence but exposed to attrition and testing effects.",
  ["any study with more than one group"],
  ["experiment_vs_observation"], ["cross_sectional", "attrition", "cohort"])

n("single_case", "Single-case experimental design", R, "design", 2,
  "Uses the individual as their own control with repeated measurement across phases — ABA, ABAB, multiple baseline across settings or behaviours — to demonstrate experimental control without a group.",
  ["a case study", "cannot support causal claims"],
  ["experiment_vs_observation"], ["case_study", "baseline"])

n("case_study", "Case study", R, "design", 3,
  "A detailed uncontrolled description of one case; hypothesis-generating rather than hypothesis-testing.",
  ["the same as a single-case experimental design"],
  [], ["single_case"])

n("pilot_feasibility", "Pilot and feasibility studies", R, "design", 1,
  "Test whether a definitive trial can be run — recruitment, retention, acceptability, procedures — rather than whether the intervention works. They are not powered for efficacy, so a significance test on outcome is not their purpose.",
  ["a small study of effectiveness", "a study that failed to recruit enough people"],
  [], ["power", "underpowered", "acceptability"])

n("qualitative_designs", "Qualitative methodologies", R, "design", 1,
  "Thematic analysis (patterns across accounts), IPA (idiographic lived experience of a homogeneous sample), grounded theory (theory generation from data with theoretical sampling), framework analysis (applied policy questions), discourse analysis (how language constructs the object).",
  ["qualitative research is unstructured", "thematic analysis and IPA are interchangeable"],
  [], ["saturation", "reflexivity", "trustworthiness", "epistemology"])

n("mixed_methods", "Mixed methods", R, "design", 3,
  "Combines quantitative and qualitative strands with an explicit rationale for sequence and integration, rather than simply doing both.",
  ["adding a few open questions to a survey"],
  [], ["qualitative_designs", "triangulation"])

n("service_evaluation", "Audit vs service evaluation vs research", R, "design", 1,
  "Audit compares current practice against an existing standard; service evaluation describes what a service is achieving without generating transferable knowledge; research aims to derive generalisable new knowledge and requires ethics committee review. The distinction governs governance route, not rigour.",
  ["service evaluation is just weaker research", "all three need NHS REC approval"],
  [], ["practice_based_evidence", "ethics_approval"])

n("systematic_review", "Systematic review", R, "design", 1,
  "A review with a pre-specified question and protocol, an exhaustive reproducible search, explicit inclusion criteria, duplicate screening, formal quality appraisal and structured synthesis — distinguished from a narrative review by reproducibility.",
  ["a thorough literature review", "always includes a meta-analysis"],
  [], ["prisma", "meta_analysis", "quality_appraisal", "publication_bias"])

n("prisma", "PRISMA", R, "design", 2,
  "The reporting standard for systematic reviews, including the flow diagram accounting for every record from identification to inclusion.",
  ["a quality appraisal tool"],
  ["systematic_review"], ["quality_appraisal"])

n("quality_appraisal", "Quality appraisal tools", R, "design", 2,
  "Structured instruments for rating study quality — CASP checklists, Cochrane RoB 2 for trials, GRADE for certainty of a body of evidence.",
  ["a score that determines whether to include a study"],
  ["systematic_review"], ["prisma", "risk_of_bias"])

n("meta_analysis", "Meta-analysis", R, "design", 2,
  "Statistical pooling of effect sizes across studies, weighted by precision, with heterogeneity quantified (I²) and explored rather than ignored.",
  ["averaging the p-values", "valid regardless of how different the studies are"],
  ["systematic_review"], ["effect_size", "heterogeneity", "publication_bias"])

n("heterogeneity", "Heterogeneity", R, "design", 3,
  "Variation in true effects across studies beyond chance, quantified by I² and addressed by random-effects models, subgroup analysis or meta-regression.", [],
  ["meta_analysis"], [])

n("publication_bias", "Publication bias", R, "design", 2,
  "The systematic over-representation of positive findings in the literature, inflating pooled estimates; assessed with funnel plots and related tests.",
  ["bias introduced by the journal's editor only"],
  [], ["meta_analysis", "preregistration", "p_hacking"])

# ---------------------------------------------------------------- BIAS & VALIDITY
n("reliability", "Reliability", R, "measurement", 1,
  "The consistency of a measure — internal consistency across items (Cronbach's alpha), stability over time (test-retest), agreement between raters (Cohen's kappa). Reliability is necessary but not sufficient for validity.",
  ["whether the measure captures the right construct", "the same thing as validity"],
  [], ["validity", "cronbach", "kappa", "measurement_error"])

n("cronbach", "Cronbach's alpha", R, "measurement", 1,
  "An index of internal consistency, conventionally acceptable from about .70; it rises with the number of items and a very high value can indicate redundancy rather than quality.",
  ["a measure of validity", "a measure of test-retest stability"],
  ["reliability"], ["measurement_error"])

n("kappa", "Cohen's kappa", R, "measurement", 2,
  "Inter-rater agreement corrected for agreement expected by chance; values around .41–.60 are moderate, .61–.80 substantial.",
  ["a percentage agreement", "a correlation between raters"],
  ["reliability"], ["reliability"])

n("validity", "Validity", R, "measurement", 1,
  "The extent to which a measure captures the construct it claims to — face (looks right), content (covers the domain), construct (behaves as theory predicts), criterion (agrees with a standard, concurrently or predictively).",
  ["whether the measure gives the same answer twice", "whether the study was well conducted"],
  [], ["reliability", "internal_validity", "external_validity"])

n("internal_validity", "Internal validity", R, "measurement", 1,
  "The degree to which the design supports the claim that the intervention, rather than something else, produced the observed change.",
  ["whether the findings apply elsewhere"],
  ["validity"], ["external_validity", "confounding", "rct"])

n("external_validity", "External validity / generalisability", R, "measurement", 1,
  "The degree to which findings extend beyond the sampled participants, settings and procedures; governed principally by whether the sample is representative of the population of interest, not by its size.",
  ["achieved by having a large sample", "the same as ecological validity"],
  ["validity"], ["internal_validity", "sampling", "ecological_validity"])

n("ecological_validity", "Ecological validity", R, "measurement", 3,
  "Whether the conditions of measurement resemble the real-world context to which inference is intended.", [],
  ["external_validity"], [])

n("measurement_error", "Measurement error", R, "measurement", 1,
  "The discrepancy between an observed score and the true score; random error attenuates observed associations, systematic error biases them in a direction.",
  ["a mistake made by the researcher", "always random"],
  ["reliability"], ["regression_to_mean", "reliable_change", "attenuation"])

n("attenuation", "Attenuation", R, "measurement", 3,
  "The downward bias in an observed correlation produced by unreliability in either measure.", [],
  ["measurement_error"], ["correlation"])

n("floor_ceiling", "Floor and ceiling effects", R, "measurement", 2,
  "Compression of scores at the bottom or top of a scale's range, which conceals real change and truncates variance.",
  ["a small sample problem"],
  [], ["measurement_error"])

n("sampling", "Sampling and recruitment", R, "bias", 1,
  "How participants come to be in the study determines to whom the findings can apply; convenience and self-selected samples systematically differ from the target population.",
  ["a large sample removes sampling problems"],
  [], ["selection_bias", "external_validity"])

n("selection_bias", "Selection bias", R, "bias", 1,
  "Systematic difference between those included and the population, or between arms at baseline, such that the comparison is confounded from the outset.",
  ["choosing the wrong statistical test", "the same as attrition"],
  ["sampling"], ["allocation_concealment", "attrition", "confounding"])

n("attrition", "Attrition / dropout", R, "bias", 1,
  "Loss of participants after entry. It matters not because numbers fall but because those who leave differ systematically from those who remain, so the completed sample is no longer the randomised one.",
  ["a problem only if the sample becomes small", "solved by recruiting more people"],
  ["selection_bias"], ["itt", "missing_data", "longitudinal"])

n("missing_data", "Missing data", R, "bias", 2,
  "Handled by understanding the mechanism — missing completely at random, at random, or not at random; last-observation-carried-forward assumes no further change and biases toward the null, multiple imputation is generally preferable.",
  ["deleting incomplete cases is neutral"],
  ["attrition"], ["itt"])

n("performance_bias", "Performance bias", R, "bias", 3,
  "Systematic differences in the care or attention provided to arms beyond the intended intervention.", [],
  ["blinding"], ["detection_bias"])

n("detection_bias", "Detection bias", R, "bias", 2,
  "Systematic difference in how outcomes are ascertained between arms, most often when assessors know allocation; self-report by unblinded participants is especially exposed.",
  ["the same as performance bias"],
  ["blinding"], ["performance_bias", "blinding"])

n("recall_bias", "Recall bias", R, "bias", 3,
  "Differential accuracy of retrospective reporting between those with and without the outcome.", [],
  ["case_control"], [])

n("demand_characteristics", "Demand characteristics & expectancy", R, "bias", 2,
  "Participants' inference about what is wanted, and their expectation of benefit, shaping responses independently of the active ingredient.",
  ["deliberate faking"],
  [], ["common_factors", "blinding"])

n("confounding", "Confounding", R, "bias", 1,
  "A third variable associated with both exposure and outcome, and not on the causal path, which generates or distorts an apparent association.",
  ["any variable you did not measure", "the same as a mediator"],
  [], ["causation", "mediation", "covariate", "rct"])

n("covariate", "Covariates and statistical control", R, "bias", 3,
  "Measured variables adjusted for in analysis; adjustment can only address confounders that were measured, and measured imperfectly it under-adjusts.",
  ["adjustment makes an observational study equivalent to a trial"],
  ["confounding"], ["regression"])

n("regression_to_mean", "Regression to the mean", R, "bias", 1,
  "The statistical tendency for extreme scores, selected because they are extreme, to be closer to the mean on re-measurement — because part of the original extremity was measurement error or transient state. It creates apparent improvement in any group selected for high scores, with no intervention at all.",
  ["people naturally get better over time", "a real treatment effect that is small"],
  ["measurement_error"], ["control_group", "natural_history"])

n("natural_history", "Natural history / spontaneous remission", R, "bias", 2,
  "The course a condition takes without intervention, which an uncontrolled pre-post design cannot separate from treatment effect.",
  ["the same as regression to the mean"],
  [], ["regression_to_mean", "control_group"])

n("causation", "Causal inference", R, "bias", 1,
  "Supported by temporal precedence, association, and elimination of plausible alternative explanations. Design, not statistical sophistication, is what licenses a causal claim.",
  ["a strong correlation shows causation", "regression establishes causation"],
  ["correlation"], ["confounding", "rct", "experiment_vs_observation", "bradford_hill"])

n("bradford_hill", "Bradford Hill considerations", R, "bias", 3,
  "Viewpoints used to weigh causality from observational evidence — strength, consistency, temporality, dose-response, plausibility, coherence, experiment, analogy, specificity.", [],
  ["causation"], [])

n("mediation", "Mediation", R, "bias", 1,
  "A mediator lies on the causal pathway and explains HOW or WHY an effect occurs: X changes M, and M changes Y.",
  ["a variable that changes the strength of an effect", "the same as a moderator", "any variable that correlates with both"],
  ["regression"], ["moderation", "confounding", "mechanism"])

n("moderation", "Moderation", R, "bias", 1,
  "A moderator changes the strength or direction of the relationship between X and Y — it answers FOR WHOM or UNDER WHAT CONDITIONS, and is tested as an interaction.",
  ["a variable on the causal pathway", "the same as a mediator"],
  ["regression"], ["mediation", "interaction"])

n("incidence", "Incidence", R, "epi", 1,
  "The rate of NEW cases arising in a defined population over a defined period.",
  ["the total number of people with the condition", "the same as prevalence"],
  [], ["prevalence", "cohort"])

n("prevalence", "Prevalence", R, "epi", 1,
  "The proportion of a population with the condition at a point or over a period — existing and new cases together. It is a function of incidence and duration, so a treatment that prolongs life raises prevalence.",
  ["the number of new cases", "the same as incidence"],
  [], ["incidence", "cross_sectional"])

n("absolute_relative_risk", "Absolute vs relative risk", R, "epi", 2,
  "Relative risk expresses the ratio between groups and can look dramatic when baseline risk is tiny; absolute risk difference expresses the change in actual events and drives clinical relevance. NNT is its reciprocal.",
  ["relative risk is the more clinically useful figure"],
  [], ["effect_size", "clinical_significance"])

n("saturation", "Data saturation", R, "qualitative", 2,
  "The point in qualitative sampling at which further data generate no new codes or dimensions; a claim requiring evidence, not an assertion, and contested in IPA where sample size is set idiographically.",
  ["the point where you have enough participants for power"],
  ["qualitative_designs"], ["reflexivity"])

n("reflexivity", "Reflexivity", R, "qualitative", 1,
  "The researcher's systematic examination of how their position, assumptions and relationship to the data shape what is produced — recorded and evidenced, not merely declared.",
  ["being objective", "acknowledging bias in one sentence"],
  ["qualitative_designs"], ["trustworthiness", "epistemology"])

n("trustworthiness", "Trustworthiness criteria", R, "qualitative", 2,
  "Credibility, transferability, dependability and confirmability — the qualitative counterparts to validity and reliability, evidenced through audit trail, triangulation, credibility checks and thick description.",
  ["reliability and validity applied unchanged"],
  ["qualitative_designs"], ["triangulation", "reflexivity"])

n("triangulation", "Triangulation", R, "qualitative", 3,
  "Convergence across data sources, methods, analysts or theories used to strengthen interpretation, not to prove a single truth.", [],
  ["trustworthiness"], ["mixed_methods"])

n("epistemology", "Epistemological position", R, "qualitative", 2,
  "The stated assumption about what the data can represent — realist, critical realist, or social constructionist — which must be coherent with the method chosen and the claims made.",
  ["a methodological preference"],
  ["qualitative_designs"], ["reflexivity"])

# ---------------------------------------------------------------- CLINICAL MODELS
n("formulation", "Formulation", C, "formulation", 1,
  "A provisional, shared, theory-driven account of how a person's difficulties developed and what maintains them, which generates testable predictions and directs intervention — and is revised as evidence accumulates.",
  ["a summary of the person's history", "a diagnosis expressed in psychological language", "a fixed conclusion reached at assessment"],
  [], ["five_ps", "maintenance_cycle", "cbt_model", "systemic", "hypothesis_testing"])

n("five_ps", "The 5 Ps", C, "formulation", 1,
  "Predisposing, precipitating, perpetuating, protective and presenting factors — a structuring device for a formulation, not a formulation in itself, because it organises content without specifying mechanism.",
  ["a psychological model", "sufficient on its own as a formulation"],
  ["formulation"], ["maintenance_cycle"])

n("maintenance_cycle", "Maintenance mechanisms", C, "formulation", 1,
  "The self-perpetuating loops that keep a difficulty going in the present — most commonly short-term relief that reinforces a behaviour whose long-term consequence sustains the problem.",
  ["the cause of the problem", "the same as predisposing factors"],
  ["formulation"], ["safety_behaviours", "avoidance", "negative_reinforcement", "circular_causality"])

n("hypothesis_testing", "Formulation as hypothesis", C, "formulation", 1,
  "A formulation earns its status by making predictions that could prove it wrong — what should be observed if it is right, what would make it less plausible, and what would require revision.",
  ["a formulation is right if the client agrees", "the more comprehensive the formulation the better"],
  ["formulation"], ["scientist_practitioner", "formulation"])

n("cbt_model", "Cognitive behavioural model", C, "models", 1,
  "Appraisal of a situation drives emotional and physiological response and behaviour; the behaviour's consequences feed back to confirm the appraisal. Disorder-specific models specify which appraisal and which maintaining behaviour.",
  ["thinking positively", "challenging irrational thoughts"],
  ["formulation"], ["safety_behaviours", "avoidance", "behavioural_experiment", "core_beliefs", "exposure", "behavioural_activation"])

n("core_beliefs", "Core and intermediate beliefs", C, "models", 2,
  "Core beliefs are absolute statements about self, others and world; intermediate beliefs are the rules, attitudes and assumptions that translate them into everyday appraisals.",
  ["the same as automatic thoughts"],
  ["cbt_model"], ["schema"])

n("schema", "Schema-level work", C, "models", 3,
  "Longstanding, self-perpetuating patterns addressed when symptom-level intervention is insufficient, using experiential as well as cognitive methods.", [],
  ["core_beliefs"], [])

n("safety_behaviours", "Safety behaviours", C, "models", 1,
  "Actions taken to prevent a feared catastrophe which prevent disconfirmation of the feared appraisal, so the person attributes safety to the behaviour rather than to the absence of danger.",
  ["the same as avoidance", "coping strategies that should be encouraged"],
  ["cbt_model"], ["avoidance", "exposure", "behavioural_experiment"])

n("avoidance", "Avoidance and negative reinforcement", C, "models", 1,
  "Escape or avoidance reduces distress immediately, which negatively reinforces the behaviour and guarantees its repetition while removing the opportunity to learn that the feared outcome does not occur.",
  ["a character weakness", "removed by encouragement alone"],
  ["cbt_model"], ["negative_reinforcement", "exposure", "safety_behaviours"])

n("negative_reinforcement", "Negative reinforcement", C, "models", 1,
  "The strengthening of a behaviour by the removal of an aversive state — the mechanism behind avoidance, reassurance-seeking, self-harm as affect regulation, and much staff behaviour in services.",
  ["punishment", "a reward for good behaviour"],
  [], ["avoidance", "operant"])

n("operant", "Operant learning", C, "models", 2,
  "Behaviour is shaped by its consequences — positive and negative reinforcement increase it, punishment and extinction decrease it — with schedule and immediacy determining strength.",
  ["only relevant to children or learning disability"],
  [], ["negative_reinforcement", "functional_analysis"])

n("functional_analysis", "Functional analysis", C, "models", 2,
  "Analysis of antecedents, behaviour and consequences to identify the function a behaviour serves, on the premise that topographically identical behaviours may serve different functions.",
  ["describing the behaviour in detail", "identifying the diagnosis"],
  ["operant"], ["behaviour_chain", "pbs"])

n("exposure", "Exposure and inhibitory learning", C, "models", 1,
  "Repeated contact with feared stimuli without the feared outcome builds new safety learning that competes with the original fear memory; modern accounts prioritise expectancy violation and variability over habituation and anxiety reduction within a session.",
  ["getting used to it until anxiety drops", "flooding"],
  ["cbt_model"], ["safety_behaviours", "behavioural_experiment"])

n("behavioural_experiment", "Behavioural experiment", C, "models", 1,
  "A planned test in which a specific prediction derived from the formulation is stated in advance, tested in reality, and the result reviewed against the prediction — the most potent method of belief change in CBT.",
  ["an exposure task", "an activity assignment"],
  ["cbt_model"], ["exposure", "hypothesis_testing"])

n("behavioural_activation", "Behavioural activation", C, "models", 1,
  "Systematically re-engaging with activity guided by values and function rather than mood, on the rationale that withdrawal reduces access to positive reinforcement and so maintains low mood; activity precedes rather than follows motivation.",
  ["encouraging the person to keep busy", "doing things that feel pleasant"],
  ["cbt_model"], ["operant", "avoidance"])

n("act", "Acceptance and Commitment Therapy", C, "models", 1,
  "Targets psychological inflexibility through six processes — acceptance, defusion, present-moment contact, self-as-context, values and committed action — asking not whether a thought is accurate but what happens when it governs behaviour.",
  ["a mindfulness intervention", "accepting that things cannot change"],
  [], ["defusion", "values", "experiential_avoidance", "cbt_model"])

n("defusion", "Cognitive defusion", C, "models", 2,
  "Changing the relationship to a thought so it is experienced as a thought rather than as a literal truth, without attempting to change its content.",
  ["thought challenging", "distraction"],
  ["act"], ["act"])

n("experiential_avoidance", "Experiential avoidance", C, "models", 2,
  "Attempts to alter the form or frequency of unwanted internal experiences, which narrow behaviour and restrict valued living even when momentarily effective.",
  ["behavioural avoidance only"],
  ["act"], ["avoidance", "values"])

n("values", "Values and committed action", C, "models", 2,
  "Chosen qualities of ongoing action that give direction — distinguished from goals, which can be completed — used to organise behaviour in the presence of discomfort.",
  ["goals", "things the person enjoys"],
  ["act"], ["behavioural_activation"])

n("dbt", "Dialectical Behaviour Therapy", C, "models", 1,
  "Built on a biosocial theory in which emotional vulnerability transacts over time with an invalidating environment; treatment holds the dialectic of radical acceptance and change across skills, individual therapy, coaching and consultation.",
  ["skills training for emotion regulation", "a treatment for personality disorder"],
  [], ["validation", "behaviour_chain", "distress_tolerance", "biosocial"])

n("biosocial", "Biosocial theory", C, "models", 2,
  "Pervasive emotion dysregulation arises from the transaction between biological emotional vulnerability and an environment that invalidates the communication of private experience — a transaction, not an additive risk model.",
  ["a diathesis-stress model", "blaming the family"],
  ["dbt"], ["validation"])

n("validation", "Validation", C, "models", 1,
  "Communicating that a response makes sense given the person's history and current context, at increasing levels up to radical genuineness — which is not agreement, and not reassurance.",
  ["telling the person they are right", "being sympathetic"],
  ["dbt"], ["biosocial", "therapeutic_alliance"])

n("behaviour_chain", "Chain analysis", C, "models", 2,
  "Second-by-second reconstruction of vulnerability factors, prompting event, links and consequences around a target behaviour, to locate solvable points in the chain.",
  ["asking why the person did it"],
  ["dbt"], ["functional_analysis"])

n("distress_tolerance", "Distress tolerance", C, "models", 3,
  "Skills for surviving crisis without making it worse, distinguished from emotion regulation skills that aim to change the emotion.", [],
  ["dbt"], [])

n("cft", "Compassion Focused Therapy", C, "models", 1,
  "Addresses shame and self-criticism using an evolutionary model of three affect-regulation systems — threat, drive and soothing — where a chronically activated threat system and an underdeveloped soothing system make self-criticism feel safe and compassion feel threatening.",
  ["being kind to yourself", "positive self-talk"],
  [], ["shame", "therapeutic_alliance"])

n("shame", "Shame and self-criticism", C, "models", 2,
  "Shame concerns the self as globally defective and drives concealment and withdrawal; guilt concerns an action and drives repair. The distinction changes what the intervention must target.",
  ["shame and guilt are interchangeable"],
  ["cft"], ["cft"])

n("systemic", "Systemic practice", C, "models", 1,
  "Locates difficulty in patterns of interaction and meaning between people rather than within an individual, attending to circularity, feedback, roles, alliances, boundaries and wider context.",
  ["family therapy", "involving the family in the session"],
  [], ["circular_causality", "hypothesising", "reflecting_team", "narrative", "context"])

n("circular_causality", "Circular vs linear causality", C, "models", 1,
  "Linear causality asks what caused what; circular causality describes recursive sequences in which each person's response is both a reaction to and a stimulus for the other's, so the pattern maintains itself without a first cause.",
  ["mutual blame", "saying everyone is equally responsible"],
  ["systemic"], ["maintenance_cycle", "systemic"])

n("hypothesising", "Systemic hypothesising and neutrality", C, "models", 2,
  "The team generates multiple provisional relational hypotheses and holds curiosity across all positions, using circular and reflexive questions to introduce difference rather than to gather facts.",
  ["staying neutral about abuse or risk", "having no view"],
  ["systemic"], ["circular_causality"])

n("reflecting_team", "Reflecting processes", C, "models", 3,
  "Making the team's thinking audible to the family so that multiple descriptions become available and the family can select what fits.", [],
  ["systemic"], [])

n("narrative", "Narrative practice", C, "models", 2,
  "Separates the person from the problem through externalising language and thickens alternative accounts by tracing unique outcomes into a preferred story.",
  ["positive reframing", "denying the problem"],
  ["systemic"], ["systemic"])

n("context", "Contextual levels", C, "models", 2,
  "Individual, family, service, community and societal levels each carry constraints and resources; a formulation that omits the level at which the problem is generated will misdirect the intervention.",
  ["adding a sentence about culture"],
  ["systemic"], ["social_determinants", "ptmf"])

n("psychodynamic", "Psychodynamic thinking", C, "models", 1,
  "Attends to processes outside awareness, early relational templates and defensive manoeuvres, using the relationship in the room as data about relationships outside it.",
  ["blaming the mother", "interpreting dreams"],
  [], ["transference", "defence", "attachment"])

n("transference", "Transference and countertransference", C, "models", 1,
  "Transference is the patterning of the therapeutic relationship by earlier relational templates; countertransference is the therapist's total emotional response, which when noticed and thought about becomes information rather than interference.",
  ["the therapist's personal problems", "liking or disliking the client"],
  ["psychodynamic"], ["use_of_self", "supervision"])

n("defence", "Defences", C, "models", 2,
  "Automatic mental operations that manage unbearable affect or conflict — denial, projection, splitting, intellectualisation, reaction formation — understood as protective in origin.",
  ["deliberate resistance", "lying"],
  ["psychodynamic"], ["transference"])

n("attachment", "Attachment", C, "models", 1,
  "Repeated experience of caregiver availability builds internal working models of self and others that shape expectation, affect regulation and help-seeking, including from services — organised strategies (secure, avoidant, ambivalent) being adaptations to particular caregiving environments rather than deficits.",
  ["a fixed childhood type that determines adult relationships", "a diagnosis"],
  ["psychodynamic"], ["developmental", "trauma"])

n("ptmf", "Power Threat Meaning Framework", C, "models", 2,
  "An alternative to diagnostic classification asking what has happened to you, how it affected you, what sense you made of it, and what you had to do to survive — foregrounding the operation of power and reframing symptoms as threat responses.",
  ["a therapy model", "a rejection of all biological factors"],
  [], ["context", "social_determinants", "trauma", "formulation"])

n("trauma", "Trauma-informed practice", C, "models", 1,
  "Organises services and interventions around the likelihood of trauma histories, prioritising safety, trustworthiness, choice, collaboration and empowerment, and asking what happened rather than what is wrong.",
  ["delivering trauma-focused therapy", "asking everyone about abuse"],
  [], ["ptmf", "attachment", "retraumatisation"])

n("retraumatisation", "Re-traumatisation in systems", C, "models", 3,
  "The reproduction of dynamics of powerlessness and coercion by services themselves — restriction, unpredictability, being disbelieved.", [],
  ["trauma"], [])

n("developmental", "Developmental perspective", C, "models", 2,
  "Reading presentation against expected developmental tasks and capacities, so that the same behaviour carries different meaning at different ages and in different developmental contexts.",
  ["only relevant to child services"],
  [], ["attachment", "cyp"])

n("cyp", "Children & young people context", C, "models", 2,
  "Work is nested in family, school and statutory systems, the referrer is rarely the client, and consent, confidentiality and goals must be negotiated across several parties at once.",
  ["therapy with a smaller adult"],
  ["developmental"], ["systemic", "safeguarding", "gillick"])

n("common_factors", "Common factors", C, "models", 2,
  "Alliance, expectancy, therapist effects and structure account for a substantial share of outcome variance across models — which is why an active comparator, not TAU, is required to attribute change to a specific technique.",
  ["proof that models do not matter"],
  [], ["therapeutic_alliance", "control_group"])

n("therapeutic_alliance", "Therapeutic alliance", C, "clinical_skills", 1,
  "The bond, plus agreement on goals and on tasks. Rupture is expected rather than exceptional, and repair — noticing, naming and exploring it without defensiveness — predicts outcome more than the absence of rupture.",
  ["rapport", "the client liking the therapist"],
  [], ["rupture_repair", "common_factors", "validation"])

n("rupture_repair", "Rupture and repair", C, "clinical_skills", 2,
  "Withdrawal or confrontation markers in the relationship, addressed directly and metacommunicatively, converting a threat to the work into the work itself.",
  ["apologising"],
  ["therapeutic_alliance"], ["use_of_self"])

n("use_of_self", "Use of self", C, "clinical_skills", 2,
  "Deliberate deployment of one's own responses — noticing what the interaction evokes and using it as hypothesis about the person's wider relational world, rather than acting on it.",
  ["self-disclosure", "being warm"],
  ["transference"], ["reflective_practice", "rupture_repair"])

# ---------------------------------------------------------------- RISK, ETHICS, LAW
n("risk_assessment", "Risk assessment", C, "risk", 1,
  "Structured professional judgement combining static and dynamic factors, current thoughts, intent, plan, means, timeframe and protective factors into a formulation of when and under what circumstances risk rises — not a prediction, and not a score.",
  ["predicting who will harm themselves", "completing a risk tool", "counting risk factors"],
  [], ["risk_formulation", "safety_plan", "static_dynamic", "suicide_risk"])

n("static_dynamic", "Static vs dynamic risk factors", C, "risk", 1,
  "Static factors (history of attempts, age, sex, past violence) index long-run base rate and cannot change; dynamic factors (hopelessness, intoxication, access to means, isolation, recent loss) are the intervention targets.",
  ["dynamic factors are the ones that are hard to measure"],
  ["risk_assessment"], ["risk_formulation"])

n("risk_formulation", "Risk formulation", C, "risk", 1,
  "A narrative account of the circumstances under which this person's risk escalates and what interrupts it, which converts a list of factors into a plan.",
  ["a risk rating of low, medium or high"],
  ["risk_assessment"], ["safety_plan", "formulation"])

n("suicide_risk", "Suicidality", C, "risk", 1,
  "Assessed by asking directly and specifically about ideation, intent, plan, means, preparatory acts, timeframe and previous attempts; asking does not increase risk, and denial of intent in the presence of high dynamic risk does not exclude it.",
  ["asking about suicide plants the idea", "no plan means low risk"],
  ["risk_assessment"], ["safety_plan", "self_harm"])

n("self_harm", "Self-harm", C, "risk", 1,
  "Most often functions as affect regulation or communication rather than as an attempt to die, though it is among the strongest predictors of eventual suicide; function must be formulated before it can be addressed.",
  ["attention seeking", "always a suicide attempt"],
  ["risk_assessment"], ["suicide_risk", "functional_analysis", "dbt"])

n("safety_plan", "Safety planning", C, "risk", 1,
  "A collaboratively written, person-specific sequence — warning signs, internal coping, people and settings that distract, people to contact, professionals, and means restriction — replacing the no-suicide contract, which has no evidence base.",
  ["a contract not to self-harm", "giving crisis line numbers"],
  ["risk_formulation"], ["means_restriction"])

n("means_restriction", "Means restriction", C, "risk", 2,
  "Reducing access to lethal means during periods of elevated risk, effective because much suicidal crisis is short-lived and method-substitution is incomplete.",
  ["ineffective because people will find another way"],
  ["safety_plan"], [])

n("safeguarding", "Safeguarding", C, "ethics", 1,
  "The duty to act where a child or adult at risk may be experiencing abuse or neglect, which overrides ordinary confidentiality, follows local procedure, and is a referral for assessment rather than an accusation requiring proof.",
  ["only relevant when you are certain", "something to decide alone"],
  [], ["confidentiality", "cyp", "escalation"])

n("confidentiality", "Confidentiality and its limits", C, "ethics", 1,
  "Information is shared on a need-to-know basis with the minimum necessary disclosed; limits — risk to self or others, safeguarding, court order — should be stated at the outset rather than invoked as a surprise.",
  ["absolute unless the client agrees", "broken whenever risk is mentioned"],
  [], ["safeguarding", "capacity", "information_governance"])

n("information_governance", "Information governance", P, "ethics", 3,
  "Caldicott principles and data protection duties governing what is recorded, who may see it and how long it is kept.", [],
  ["confidentiality"], [])

n("capacity", "Mental capacity", C, "ethics", 1,
  "Decision-specific and time-specific: a person lacks capacity if an impairment of mind or brain means they cannot understand, retain, weigh, or communicate a decision. Capacity is presumed, unwise decisions do not indicate its absence, and all practicable support must be given first.",
  ["a global judgement about a person", "absent because the decision seems unwise", "determined by diagnosis"],
  [], ["best_interests", "mca", "dols"])

n("mca", "Mental Capacity Act 2005", C, "ethics", 1,
  "Five principles: presumption of capacity; all practicable steps to support decision-making; unwise decisions do not equal incapacity; acts for those lacking capacity must be in their best interests; and the least restrictive option must be chosen.",
  ["a mechanism for detaining people", "applies to all decisions once someone is judged to lack capacity"],
  ["capacity"], ["best_interests", "dols", "mha"])

n("best_interests", "Best interests", C, "ethics", 1,
  "A structured decision for someone lacking capacity that must consider their past and present wishes, beliefs and values, consult those close to them, avoid assumptions based on age or condition, and take the least restrictive route.",
  ["what the clinician judges medically best", "what the family wants"],
  ["mca"], ["dols", "capacity"])

n("dols", "Deprivation of liberty safeguards", C, "ethics", 2,
  "Authorisation required where a person who lacks capacity is under continuous supervision and control and not free to leave — the acid test — in a setting arranged by the state.",
  ["needed whenever someone is in hospital", "the same as detention under the Mental Health Act"],
  ["mca"], ["mha", "best_interests"])

n("mha", "Mental Health Act 1983/2007", C, "ethics", 1,
  "Governs detention and treatment for mental disorder: s2 for assessment up to 28 days, s3 for treatment up to 6 months, s5(2) doctor's holding power and s5(4) nurse's, s136 police power in a public place, s117 the joint duty to provide free aftercare following s3.",
  ["overrides the Mental Capacity Act in all situations", "requires the person to lack capacity"],
  [], ["mca", "dols", "least_restrictive"])

n("least_restrictive", "Least restrictive practice", C, "ethics", 2,
  "Choosing the option that achieves the purpose with the smallest interference with rights and freedom of action, and reviewing it as circumstances change.",
  ["avoiding restriction altogether"],
  [], ["mca", "mha", "positive_risk"])

n("gillick", "Gillick competence & Fraser guidelines", C, "ethics", 2,
  "Gillick competence is a child's capacity to consent to treatment where they have sufficient understanding and intelligence; Fraser guidelines specifically concern contraceptive and sexual health advice.",
  ["the two terms are interchangeable", "determined by age alone"],
  ["capacity"], ["cyp", "confidentiality"])

n("positive_risk", "Positive risk-taking", C, "ethics", 2,
  "Supporting a person to pursue valued activity with acknowledged risk, having assessed, formulated, documented and shared the reasoning — defensible practice rather than defensive practice.",
  ["accepting risk without a plan", "avoiding all risk"],
  ["least_restrictive"], ["risk_formulation", "documentation"])

n("dual_relationship", "Boundaries and dual relationships", P, "ethics", 2,
  "Role clarity protects the person and the work; boundary crossings are managed by naming them, thinking about function, and taking them to supervision rather than deciding alone.",
  ["never having any contact outside sessions"],
  [], ["supervision", "social_media_boundary"])

n("social_media_boundary", "Digital and social media boundaries", P, "ethics", 2,
  "Contact through personal channels is not a therapeutic medium, is not monitored, and cannot carry risk; the response is to acknowledge, redirect to the agreed route, ensure immediate safety, and address the frame in the next session.",
  ["ignoring the message", "responding clinically through the same channel"],
  ["dual_relationship"], ["risk_assessment", "documentation"])

n("documentation", "Record keeping", P, "ethics", 2,
  "Contemporaneous, factual, proportionate records that show the reasoning behind decisions — including risks considered and rejected — because the record is the evidence that judgement was exercised.",
  ["writing down everything the client said"],
  [], ["positive_risk", "information_governance"])

# ---------------------------------------------------------------- PROFESSIONAL
n("scientist_practitioner", "Scientist-practitioner model", P, "professional", 1,
  "The clinician applies research evidence to practice, uses empirical methods to evaluate their own work, and generates research from clinical questions — treating each case as a testable formulation rather than only consuming published evidence.",
  ["doing research as well as clinical work", "following NICE guidance"],
  [], ["reflective_practice", "practice_based_evidence", "hypothesis_testing", "evidence_based_practice"])

n("reflective_practice", "Reflective practice", P, "professional", 1,
  "Systematic examination of one's own responses, assumptions and contribution to what happened, resulting in a change that can be described — distinguished from description of events by the presence of that change.",
  ["thinking about how a session went", "describing what you learned"],
  [], ["scientist_practitioner", "supervision", "use_of_self"])

n("practice_based_evidence", "Practice-based evidence", P, "professional", 1,
  "Systematic data generated in routine services — outcome monitoring, session-by-session measures, service evaluation — used to inform practice, complementing evidence-based practice by addressing whether treatments work here, for these people.",
  ["clinical experience", "the opposite of evidence-based practice"],
  [], ["evidence_based_practice", "service_evaluation", "routine_outcome"])

n("evidence_based_practice", "Evidence-based practice", P, "professional", 1,
  "The integration of best available research evidence, clinical expertise, and the person's values and preferences — three components, not one.",
  ["following the manual", "doing what NICE recommends"],
  [], ["practice_based_evidence", "nice"])

n("routine_outcome", "Routine outcome monitoring", P, "professional", 2,
  "Session-by-session measurement used to detect non-response early and change course, which improves outcomes principally for those deteriorating.",
  ["collecting data for the service's targets"],
  ["practice_based_evidence"], ["reliable_change"])

n("nice", "NICE guidance", P, "professional", 2,
  "Recommendations derived from evidence of clinical and cost effectiveness which inform rather than dictate; deviation is legitimate when formulated, reasoned and documented.",
  ["mandatory rules", "a complete account of the evidence"],
  ["evidence_based_practice"], ["stepped_care"])

n("supervision", "Supervision", P, "professional", 1,
  "Serves normative, formative and restorative functions; used well it brings the difficult material — uncertainty, error, strong reactions — rather than a summary of what went well.",
  ["reporting on cases", "line management"],
  [], ["reflective_practice", "transference", "escalation"])

n("consultation", "Consultation", P, "professional", 1,
  "Indirect work in which psychological understanding is offered to those who hold the relationship with the person, extending reach beyond direct therapy and often changing the system rather than the individual.",
  ["giving advice", "supervision of another profession"],
  [], ["mdt", "team_formulation", "systemic"])

n("team_formulation", "Team formulation", P, "professional", 2,
  "Facilitated group development of a shared psychological account of a person's difficulties, which reliably shifts staff attributions and reduces blame independently of any change in the person.",
  ["presenting your formulation to the team"],
  ["consultation"], ["formulation", "mdt"])

n("mdt", "Multidisciplinary working", P, "professional", 1,
  "Distinct professional contributions coordinated around a shared plan, where the psychologist's specific contributions are formulation, evidence appraisal, and attention to process — held without constructing hierarchies between professions.",
  ["everyone doing a bit of everything", "psychology leading the team"],
  [], ["consultation", "leadership", "team_formulation"])

n("leadership", "Clinical leadership", P, "professional", 1,
  "Influence exercised without necessarily holding authority — shaping how a service thinks, advocating for the psychological perspective, developing others, and taking responsibility for the quality of care beyond one's own caseload.",
  ["being in charge", "managing staff"],
  [], ["service_development", "mdt", "advocacy"])

n("service_development", "Service development", P, "professional", 2,
  "Identifying an unmet need with data, designing a proportionate response with stakeholders, piloting, evaluating and building in sustainability from the outset.",
  ["setting up a new group"],
  ["leadership"], ["service_evaluation", "coproduction"])

n("coproduction", "Co-production", P, "professional", 1,
  "Sharing power with people with lived experience across design, delivery and evaluation, from the point where the question is framed — distinguished from consultation, where a plan already exists and views are sought on it.",
  ["asking service users for feedback", "having a service user on the panel"],
  [], ["service_user_involvement", "service_development", "power_relations"])

n("service_user_involvement", "Service user and carer involvement", P, "professional", 1,
  "Involvement in selection, teaching, service design and research, which changes what is asked as well as what is answered; done poorly it is tokenistic, unpaid and consultative after the fact.",
  ["good practice that improves satisfaction scores"],
  ["coproduction"], ["carers", "power_relations"])

n("carers", "Working with carers", C, "professional", 1,
  "Carers hold information, sustain the person, and have needs and rights of their own including a statutory assessment; supporting them is not a breach of the person's confidentiality, since listening and giving general information require no disclosure.",
  ["you cannot speak to a carer without consent", "the carer's needs are secondary"],
  [], ["confidentiality", "systemic", "context"])

n("advocacy", "Advocacy", P, "professional", 3,
  "Speaking to power on behalf of, or better alongside, those whose position in a system makes them unheard.", [],
  ["leadership"], ["power_relations"])

n("escalation", "Escalation and consultation of concern", P, "professional", 1,
  "Raising a concern through the agreed route — supervisor, safeguarding lead, duty, professional body — promptly, with the facts recorded, on the principle that the decision to act does not rest with one person alone.",
  ["reporting a colleague", "a last resort"],
  [], ["supervision", "safeguarding", "whistleblowing"])

n("whistleblowing", "Raising concerns about practice", P, "professional", 2,
  "Protected disclosure where patient safety is at stake, following the Freedom to Speak Up route, and required rather than optional when internal escalation fails.",
  ["disloyalty to the team"],
  ["escalation"], ["duty_of_candour"])

n("duty_of_candour", "Duty of candour", P, "professional", 3,
  "The obligation to be open with people when something has gone wrong in their care, including an apology and an account of what will be done.", [],
  ["whistleblowing"], [])

n("stepped_care", "Stepped care & NHS Talking Therapies", P, "systems", 2,
  "Least intensive appropriate intervention first with systematic review and stepping up on non-response; efficient at population level and criticised for step-one attrition, restricted access for complexity, and outcome targets that shape referral.",
  ["a waiting list system", "always starting with self-help regardless of presentation"],
  [], ["nice", "access_inequality"])

n("community_framework", "Community Mental Health Framework", P, "systems", 3,
  "The policy shift dissolving the CMHT/IAPT boundary into place-based, integrated primary and community provision organised around PCNs.", [],
  [], ["stepped_care"])

n("access_inequality", "Inequalities in access", P, "edi", 1,
  "Access is not equal across groups: referral pathways, detention rates, coercion, drop-out and outcome differ by ethnicity, deprivation and disability in ways not explained by need — a property of services, not of the people who use them.",
  ["some communities are harder to engage", "a matter of raising awareness"],
  [], ["social_determinants", "structural_racism", "equity_equality"])

n("structural_racism", "Racism and mental health services", P, "edi", 1,
  "Documented differentials — higher rates of detention and community treatment orders, lower rates of referral to talking therapy, more coercive pathways — arising from institutional processes rather than individual prejudice alone.",
  ["explained by different rates of illness", "solved by cultural awareness training"],
  ["access_inequality"], ["cultural_humility", "power"])

n("social_determinants", "Social determinants", P, "edi", 1,
  "Poverty, insecure housing, unemployment, debt, discrimination, adverse childhood experience and social isolation are causal contributors to distress, not background context — which places material and social intervention inside the psychologist's remit.",
  ["factors that make therapy harder", "outside the scope of psychology"],
  [], ["ptmf", "access_inequality", "context"])

n("equity_equality", "Equity vs equality", P, "edi", 1,
  "Equality distributes the same resource to everyone; equity distributes according to need in order to equalise outcome. Offering an identical service to unequal starting positions preserves the inequality.",
  ["two words for fairness"],
  [], ["access_inequality", "social_determinants"])

n("intersectionality", "Intersectionality", P, "edi", 2,
  "Positions of disadvantage interact rather than add, producing experiences that cannot be predicted from any single category considered alone.",
  ["having several protected characteristics"],
  [], ["power_relations", "cultural_humility"])

n("cultural_humility", "Cultural humility", P, "edi", 1,
  "A stance of lifelong self-examination and redress of power imbalance, in which the person is the authority on their own context — distinguished from cultural competence, which implies a body of knowledge about groups that can be acquired and completed.",
  ["knowing about different cultures", "asking about someone's background"],
  [], ["structural_racism", "power_relations", "intersectionality"])

n("power_relations", "Power in the therapeutic relationship", P, "edi", 1,
  "Operates through role, institutional authority, knowledge, language, access to records, and the capacity to define what counts as a problem — present whether or not it is acknowledged.",
  ["something to be given away", "not an issue if the therapist is warm"],
  [], ["cultural_humility", "coproduction", "ptmf"])

n("interpreters", "Working with interpreters", C, "edi", 3,
  "Briefed and debriefed, addressed as a third party in the room with implications for confidentiality and alliance, and never a family member for clinical content.", [],
  ["cultural_humility"], [])

n("adaptation", "Adapting interventions", C, "edi", 2,
  "Surface adaptation changes materials and examples; deep adaptation changes the model's explanatory framework to fit the person's understanding of distress — and the evidence favours the latter.",
  ["translating the worksheets"],
  [], ["cultural_humility", "cbt_model"])

n("pbs", "Positive behaviour support", C, "models", 3,
  "Function-led, values-based framework used particularly in intellectual disability, combining functional assessment with environmental redesign and skill teaching in place of restrictive practice.", [],
  ["functional_analysis"], ["least_restrictive"])

n("ethics_approval", "Research ethics governance", R, "design", 2,
  "Ethics committee review addresses consent, capacity, risk, confidentiality and burden; HRA approval governs NHS research. Genuine ethical issues in a study are specific to its design, not generic statements about anonymity.",
  ["anonymising the data", "getting people to sign a form"],
  [], ["service_evaluation", "consent"])

n("consent", "Informed consent in research", R, "design", 1,
  "Requires capacity, adequate information, voluntariness and the ability to withdraw; consent given by a proxy — a staff member, a relative — is not the participant's consent, and dependency on the person seeking it undermines voluntariness.",
  ["a signed form", "obtainable from a carer for a competent adult"],
  ["ethics_approval"], ["capacity", "ethics_approval"])

n("acceptability", "Acceptability and feasibility", R, "design", 2,
  "Whether people will take up, tolerate and complete an intervention — evidenced by uptake, attrition and qualitative account, and logically prior to efficacy.",
  ["whether the intervention works"],
  ["pilot_feasibility"], ["attrition"])

n("contamination", "Contamination", R, "design", 3,
  "Diffusion of the intervention into the control condition, which biases the estimate toward the null.", [],
  ["cluster_rct"], [])

n("risk_of_bias", "Risk of bias", R, "bias", 2,
  "The domain-by-domain judgement of how far a study's result may depart from the truth — randomisation, deviations from intervention, missing outcome data, measurement, selective reporting.",
  ["a study's overall quality score"],
  ["quality_appraisal"], ["selection_bias", "detection_bias", "attrition"])

n("precision_estimate", "Precision", R, "inference", 3,
  "How narrowly the effect is estimated, indexed by the confidence interval and driven by sample size and variability — distinct from accuracy, which concerns bias.", [],
  ["confidence_interval"], ["sample_size"])

n("sample_size", "Sample size determination", R, "inference", 2,
  "Set a priori by the smallest effect of interest, the desired power, alpha and expected attrition — not by convention or convenience.",
  ["the more participants the better regardless", "determined after seeing the data"],
  ["power"], ["underpowered", "precision_estimate"])

n("baseline", "Baseline and phases", R, "design", 3,
  "A stable pre-intervention series against which change is judged in single-case designs; instability at baseline undermines any subsequent inference.", [],
  ["single_case"], [])

n("mechanism", "Mechanism of change", R, "inference", 2,
  "The specified process through which an intervention produces its effect, tested by measuring the putative mediator and showing that change in it precedes and accounts for change in outcome.",
  ["the theory behind the therapy"],
  ["mediation"], ["mediation", "common_factors"])

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "trainer", "data", "concepts.json")
ids = [x["id"] for x in N]
assert len(ids) == len(set(ids)), "duplicate concept ids: " + str([i for i in ids if ids.count(i) > 1])
for x in N:
    for r in x["parents"] + x["related"]:
        assert r in ids, f"{x['id']} -> unknown ref {r}"
json.dump({"version": 1, "nodes": N}, open(OUT, "w"), indent=1, ensure_ascii=False)
print(f"{len(N)} concepts -> {OUT}")
from collections import Counter
print(Counter(x["domain"] for x in N))
print(Counter(x["cluster"] for x in N))
