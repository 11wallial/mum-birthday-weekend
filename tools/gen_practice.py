# -*- coding: utf-8 -*-
"""Formulation vignettes (one case, many lenses) and branching role-plays.

Vignettes are drawn from the scenarios that actually appear in the corpus, so the
material is the material the panels use. Each model entry gives the mechanism, the
formulation, what the lens adds, what it misses, the intervention that FOLLOWS from
it, and a falsification test -- because a formulation that cannot be wrong is not a
formulation.
"""
import json, os

V = []
def vignette(id, title, source, text, ask, models, compare, difficulty=3):
    V.append(dict(id=id, title=title, source=source, text=text, ask=ask,
                  models=[dict(model=m[0], mech=m[1], form=m[2], adds=m[3],
                               misses=m[4], intervention=m[5], test=m[6]) for m in models],
                  compare=compare, difficulty=difficulty))

vignette("v_asylum", "Unaccompanied child seeking asylum", "Birmingham 2019, clinical interview (verbatim scenario)",
 "You have picked up a referral to work with a 14-year-old unaccompanied child seeking asylum, who has been placed "
 "in a foster home. The foster family have expressed concerns as the child is behaving aggressively — shouting, "
 "slamming doors, and on one occasion pushing past a foster carer to leave the house at night. He has been in the "
 "placement eleven weeks. He speaks some English. He has not talked about his journey or his family.",
 "Formulate. Then formulate again from a different model. What does each lens illuminate, and what does it miss?",
 [("Trauma / PTMF",
   "Threat responses that were adaptive in the original context persist in a context that resembles it. The question is not what is wrong with him but what happened to him, what he had to do to survive, and what power was operating.",
   "Aggression here is most parsimoniously read as a threat response in a hyper-aroused nervous system, in a young person who has survived events he has not been able to speak about and who remains in a situation of profound ongoing threat — an unresolved asylum claim, no family, no control over where he lives or with whom. Slamming doors and leaving at night may be attempts to restore some agency and escape routes in a house where he cannot predict what happens next. Not speaking about the journey may be protective rather than avoidant: disclosure has consequences in an asylum process, and he may have been instructed not to speak.",
   "Puts the behaviour in its context, makes it intelligible rather than pathological, and foregrounds that his powerlessness is real and current, not merely remembered.",
   "Can under-specify the mechanism, and risks explaining everything by trauma so that ordinary adolescence, cultural difference and the specific dynamics of this household become invisible.",
   "Stabilisation and safety before any processing: predictability, agency over small daily decisions, psychoeducation about threat responses shared with the foster carers, and advocacy on the asylum claim — which may be the single most therapeutic act available.",
   "If this is threat-driven, arousal should track proximity to reminders and to asylum process events, and aggression should reduce as predictability and control increase — without any processing of the trauma itself. If aggression is unrelated to those, look elsewhere."),
  ("Attachment / developmental",
   "Internal working models built in one caregiving environment govern expectation and help-seeking in the next. A child who has learned that adults cannot be relied upon will test rather than trust.",
   "He has lost every attachment figure and is being asked to accept care from strangers, in a language he half-speaks, at an age when identity and belonging are the central developmental tasks. Accepting care carries risk: if he lets these people matter and they too disappear, the loss compounds. Aggression may function to keep the foster carers at a manageable distance, and to test whether they will reject him — which, if they do, confirms the model and is at least predictable.",
   "Explains the specific target of the behaviour — it is directed at the carers, not at school or peers — and predicts the placement breakdown risk that everyone is worried about.",
   "Risks locating the difficulty inside the child's history and minimising the current, entirely real threat of the asylum process, or reading culturally normative independence as avoidant attachment.",
   "Work with the foster carers on holding the relationship through rejection without withdrawing, understanding the behaviour as a test rather than as a verdict on them; keep the placement stable; build one predictable relationship at a time.",
   "If this is relational testing, the aggression should be most intense with the carers he is beginning to depend on, and should intensify around separations, absences and changes of routine, rather than being uniform across settings."),
  ("Systemic",
   "The problem is in the pattern between people, not inside one of them. Each response is both a reaction to and a stimulus for the other's.",
   "A loop is plausible here: he leaves the house at night; the carers become frightened and impose more restriction; restriction reduces his already minimal control and increases his need to demonstrate agency; he escalates; they restrict further. Both parties are acting reasonably from their own position — they are responsible for a vulnerable minor, he is trying to survive — and the pattern maintains itself. There is a wider system too: social care, the Home Office, school and the interpreter each carry a position, and the foster carers may be receiving contradictory instructions about what they can permit.",
   "Locates the problem where the intervention can actually reach it, and stops the referral question ('fix the child') from being accepted uncritically.",
   "Can miss the individual's internal experience, and — if applied naively — risks a symmetry that is inappropriate when one party has vastly less power than the other.",
   "Work with the household, not the child alone: map the sequence with the carers, find the point in the loop that is easiest to interrupt, negotiate what agency he can genuinely be given, and convene the wider network so it speaks with one voice.",
   "If this is a maintaining loop, changing the carers' response at one point should shift the sequence without any direct work with him. If the behaviour is unchanged by that, the loop is not carrying it."),
  ("CBT",
   "Appraisal drives response, and the behavioural consequence feeds back to confirm the appraisal.",
   "A specific cognitive-behavioural account would be: an appraisal of imminent threat or of being trapped ('if I stay I cannot get out'), producing intense arousal and an escape or fight response; leaving the house terminates the arousal, which negatively reinforces it; the carers' subsequent restriction confirms the appraisal that he is not safe and not in control, strengthening the belief. Any safety behaviours — sleeping dressed, staying near the door, not eating with the family — would maintain the belief by preventing disconfirmation.",
   "Names a precise mechanism and generates testable predictions, which makes it the most falsifiable of these accounts.",
   "Requires shared language, a degree of trust and a capacity for meta-cognitive work that may be unavailable at eleven weeks in a second language; and it can look like locating the problem in his thinking when the danger is real.",
   "Not formal cognitive work yet. Arousal management and psychoeducation about the body's threat response, delivered concretely; then, only once safety and language allow, graded testing of specific predictions about the household.",
   "If this account holds, arousal should be preceded by identifiable triggers and appraisals that he can eventually report, and reducing safety behaviours should reduce belief conviction. If he cannot identify any triggers and the arousal is continuous, a trauma or attachment account fits better."),
  ("ACT",
   "Suffering is compounded by struggle against internal experience; the aim is workable action in the direction of what matters, with discomfort present.",
   "He may be spending most of his available energy on controlling unbearable internal states — memories, grief, terror, guilt about those left behind — and aggression and leaving may both be forms of experiential avoidance that work in the short term and cost him the placement in the long term. The question is what he wants his life here to be for, which is nearly impossible to ask of someone whose future is being decided by someone else.",
   "Sidesteps the need to process trauma content, which may be premature and unsafe, and moves toward what he wants rather than what is wrong with him.",
   "Values work presupposes a degree of agency over one's future that an unaccompanied minor in the asylum system does not have; asking about values while his claim is undecided may be experienced as absurd or cruel.",
   "Small, concrete committed actions in domains he can actually control — education, football, learning English, contact with a community — held as valued directions rather than as coping.",
   "If avoidance is central, then any increase in willingness to have difficult internal experience should widen his behavioural repertoire even before distress reduces. If distress reduces but behaviour does not change, the account is incomplete.")],
 "Notice that all five accounts predict aggression, and that they differ chiefly in WHERE they locate the "
 "mechanism — in the nervous system, in the relationship, in the pattern between people, in appraisal, or in "
 "avoidance. In interview, the strong answer does not choose the 'right' one; it says what each buys you and "
 "what would distinguish them. Here the trauma and systemic accounts have the strongest immediate claim, "
 "because both point to interventions that do not require him to talk, and because the powerlessness in his "
 "situation is real rather than perceived. Note also the safeguarding thread: a 14-year-old leaving the house "
 "at night is at risk of exploitation, and that has to be held alongside the formulation, not after it.", 4)

vignette("v_protective_parent", "The protective parent", "The brief's own example; the pattern behind Exeter 2012 and Cardiff research vignettes",
 "A 9-year-old girl has become increasingly anxious about school over two terms. She now refuses two or three "
 "mornings a week. Her mother has reduced her own working hours to be available, drives her in rather than letting "
 "her take the bus with friends, and stays in the car park for the first hour. The mother says she cannot bear to "
 "see her daughter distressed. The school has started sending work home. The girl says she feels sick in the "
 "mornings and that her mother worries too much.",
 "Formulate this from a CBT perspective and then from a systemic perspective. What does the systemic lens add?",
 [("CBT",
   "Threat appraisal drives avoidance; avoidance is negatively reinforced and prevents disconfirmation.",
   "She appraises school as threatening — the content matters and is not yet known, whether social, performance or separation-related. Anticipation produces autonomic arousal that she experiences as nausea, which she then reads as evidence that she is ill and cannot go, confirming the appraisal. Not going terminates the arousal immediately, which negatively reinforces refusal. Her mother's accommodation — the lift, the presence in the car park, the work sent home — functions as a family-level safety behaviour: each removes an opportunity to discover that she could have coped, and the more effectively it relieves distress today the more strongly it is reinforced for both of them.",
   "Names the precise mechanism by which help maintains the problem, and generates a graded intervention with testable predictions.",
   "Treats the mother's behaviour as an accommodation variable rather than as meaningful in its own right, and can leave the family feeling blamed for having tried to help.",
   "Graded return to school with a hierarchy negotiated with school and family, systematic reduction of accommodations one at a time, behavioural experiments testing specific predictions ('if I go in on the bus, I will be sick and have to come home'), and psychoeducation for the mother on why relief today costs tomorrow.",
   "If avoidance is maintaining it, anxiety should reduce across repeated exposures without avoidance, and reducing one accommodation should not produce catastrophic deterioration. If distress escalates and stays escalated, something else is operating — bullying, a learning difficulty, something at home."),
  ("Systemic",
   "Circular causality: each person's response is both a reaction to and a trigger for the other's, so the pattern maintains itself without a first cause.",
   "The sequence is recursive: the girl shows distress; her mother, who cannot bear it, moves closer and takes over; her proximity communicates that the situation is genuinely dangerous and that her daughter cannot manage it alone; the daughter's confidence falls and her distress rises; her mother moves closer still. Each is behaving lovingly and each escalates the other. Beyond the dyad: what does the mother's own history make of a distressed child, is there a father or partner with a different view producing a split between a 'soft' and a 'firm' parent, what is the school communicating by sending work home, and what has changed in the family in the last two terms that nobody has mentioned?",
   "Explains why the intervention will fail if directed only at the child, and makes the mother's behaviour meaningful — she is not an obstacle, she is in a loop that makes sense from where she stands.",
   "Can under-specify the individual mechanism that CBT names precisely, and can lose the girl's own internal experience in a description of the system.",
   "Work with the pattern in the room: map the sequence with both of them, ask circular questions ('when your mum waits in the car park, what does your daughter conclude?'; 'who worries most, and who notices first?'), find the smallest change to the sequence that either could make, and convene school so it is not a third party acting on its own theory.",
   "If the loop is carrying it, changing the mother's response alone should shift the daughter's behaviour without any direct work with the daughter. That is a strong and testable prediction — and it is the one that distinguishes the systemic account from the CBT one."),
  ("ACT",
   "Struggle with internal experience narrows life; the mother's agenda has become the elimination of her daughter's distress.",
   "The mother's stated position — 'I cannot bear to see her distressed' — is the formulation. Her behaviour is organised around the removal of an internal experience of her own, and each accommodation works briefly and costs her working hours, her daughter's independence and her own life. The daughter is learning the same rule: that discomfort is intolerable and must be removed rather than carried.",
   "Reframes the target from the child's anxiety to the family's relationship with discomfort, which is often the more workable target and lands less blamefully.",
   "May be too abstract for a 9-year-old, and risks sounding like an instruction to tolerate distress that has not yet been understood.",
   "Work with the mother on willingness — what kind of parent she wants to be, and whether protecting her daughter from all distress serves that — while building the daughter's willingness through play-based defusion and small valued actions.",
   "If experiential avoidance is central, then the mother's willingness to tolerate her own distress should permit accommodation reduction, and the daughter's functioning should improve before her anxiety does."),
  ("Attachment / developmental",
   "Proximity-seeking under threat is the system working as designed; the question is what has activated it and whether it can be deactivated.",
   "At nine, autonomy from parents and belonging with peers are the central developmental tasks, and this pattern is arresting both. Something may have activated the attachment system two terms ago — an illness, a loss, a separation, a frightening event — and the mother's hypervigilance may reflect her own experience of loss or of being unprotected. The nausea may be genuine somatic distress rather than a cognition.",
   "Directs attention to what changed two terms ago, which nobody in the referral has explained, and to the mother's own history.",
   "Risks a historical explanation that does not generate a next step, and can pathologise a proportionate parental response to a real problem at school.",
   "Understand the activating event; work with the mother on her own experience separately from the joint work; support graded separation with a secure base rather than by removing support abruptly.",
   "If the attachment system has been activated by a specific event, there should be an identifiable point of change, and the pattern should extend to other separations — sleepovers, being left with relatives — not only to school.")],
 "This is the exact pairing the brief flags and the highest-yield preparation you can do, because CBT and "
 "systemic accounts of the same case are what Cardiff, Birmingham and Southampton all ask for. The clean answer "
 "to 'what does the systemic lens add?' is: it makes the mother's behaviour meaningful rather than merely "
 "unhelpful, and it predicts that changing HER response alone will shift the daughter's behaviour — a "
 "prediction the CBT account does not make in the same form. What it loses is the precision of the "
 "accommodation mechanism and the girl's own appraisal, which is what the CBT account names best. Say both, "
 "and say what would distinguish them empirically.", 3)

vignette("v_lowmood", "Low mood, anger and rejection", "Coventry & Warwick 2018, recorded therapy session used in the written exercise",
 "You watch a ten-minute recorded session. A woman in her thirties describes feeling low, angry, and rejected. She "
 "says people judge her, that her family have 'given up' on her, and that she sometimes thinks about hurting "
 "herself when it gets bad. She is dismissive of previous therapy — 'I've done all this before' — and at one point "
 "says the therapist probably thinks she is difficult too.",
 "What is the client experiencing? What is the therapist experiencing? Write a formulation a layperson would understand.",
 [("CBT",
   "Core beliefs about the self and others generate appraisals that are confirmed by the interpersonal behaviour they produce.",
   "A belief of the order 'I am unacceptable / people will reject me' generates hypervigilance to signs of rejection, so ambiguous behaviour from others is read as judgement. Anger is both a response to perceived rejection and a form of protection: it gets in first. But the anger and the pre-emptive dismissal ('you probably think I'm difficult too') tend to produce distance in others, which she then experiences as the rejection she expected. The belief is confirmed by its own consequences.",
   "Names a self-fulfilling cycle precisely, including how it will operate in the therapy room.",
   "Individualises what may be a proportionate response to real and repeated experiences of being dismissed, including by services.",
   "Make the cycle explicit and collaborative, including its live operation between the two of you; behavioural experiments testing predictions about others' responses; work at belief level once the alliance can hold it.",
   "If this is belief-driven, she should predict rejection in specific situations in advance, and disconfirming evidence should reduce conviction. If she can accurately identify who has actually dismissed her, the belief may be well calibrated rather than distorted."),
  ("CFT",
   "Shame and self-criticism arise from a chronically activated threat system and an underdeveloped soothing system; self-criticism feels safe and compassion feels threatening.",
   "Shame about the self as fundamentally unacceptable is the affect underneath both the anger and the withdrawal. Her threat system is dominant: she scans for judgement, and attacks first because attack is safer than exposure. Anger is a threat-system protective strategy that works — it keeps people at a distance where they cannot confirm the shame. Warmth from a therapist is not neutral here; it is threatening, because it invites the exposure she is defended against, which may be why she is dismissive of therapy.",
   "Explains the specific texture of the presentation — the anger, the pre-emptive dismissal, the resistance to warmth — better than a purely cognitive account, and predicts the alliance difficulty.",
   "Requires a longer arc and can feel abstract early on; risks the therapist offering compassion that is experienced as threat.",
   "Psychoeducation about the three systems, delivered non-blamefully ('this is not your fault, and it is how brains work'); careful attention to fear of compassion; soothing rhythm and safe-place work before any self-compassion practice.",
   "If shame is central, warmth should reliably increase distress or dismissal in the short term, and the fear-of-compassion pattern should be identifiable and nameable with her."),
  ("Psychodynamic",
   "Relational templates are re-enacted in the therapeutic relationship, and the therapist's response is data.",
   "'You probably think I'm difficult too' brings the pattern into the room and invites the therapist to take a position. If the therapist becomes defensive, over-reassuring or subtly rejecting, the template is confirmed and the enactment complete. Her countertransference pull is likely to be toward feeling deskilled, criticised, or wanting to prove she is different from everyone else — and noticing that pull is more informative than any history she reports.",
   "Uses the live relationship as the richest data available, and explains why the previous therapies failed in a way the other models do not.",
   "Risks over-interpretation and, delivered clumsily, can feel like being told her reaction is about someone else.",
   "Attend to the relationship above content; notice and think about the pull rather than acting on it; name the process tentatively ('I notice I want to convince you I'm different — I wonder if that happens with others'); take countertransference to supervision.",
   "If a template is being re-enacted, the same dynamic should be traceable across her account of family, services and previous therapists, and naming it in the room should shift something."),
  ("PTMF / contextual",
   "What has happened to you, how did it affect you, what sense did you make of it, and what did you have to do to survive.",
   "Rather than asking what is wrong with her, ask what happened. 'People judge me' may be an accurate report: she may have been judged, by family, by services, and by previous therapists who found her difficult. Anger is then an entirely intelligible response to repeated invalidation and to the operation of power, including the power of professionals to define her as the problem. Her dismissal of therapy may be well-earned experience rather than resistance. Self-harm may function as regulation of unbearable affect, or as communication where words have not been heard.",
   "Reframes 'difficult' as a description of what services have done to her rather than of who she is — and 'difficult patient' is precisely the attribution the recorded session is likely to elicit in candidates.",
   "Offers less immediate purchase on mechanism, and cannot on its own tell you what to do next session.",
   "Validate first and at length; be explicit about power and about what you can and cannot offer; give her control over pace and content; be honest about what previous services got wrong rather than defending them.",
   "If invalidation is central, then sustained validation should reduce the anger before any technique is introduced — which is a strong, observable and quickly testable prediction.")],
 "For the therapist's experience — which Coventry asks explicitly — the honest answer is likely to include "
 "feeling deskilled, mildly criticised, and pulled toward either defending previous therapy or over-promising "
 "that this time will be different. Saying that plainly, and saying that you would take it to supervision as "
 "information rather than acting on it, is a strong answer. Note that Coventry then asks for a formulation a "
 "layperson would understand: that means her words, no jargon, a cycle described in ordinary language, "
 "something that makes her response understandable rather than faulty, and an explicit 'does that fit?'.", 4)

vignette("v_id_residential", "Behaviour that challenges in residential care", "Cardiff 2016 written task setting; Birmingham 2018 population",
 "You are the psychologist for a residential home for adults with intellectual disabilities. Staff have referred "
 "a 34-year-old man who has begun hitting out at staff during personal care. It started about six weeks ago. Staff "
 "describe him as 'attention-seeking' and say he 'knows exactly what he is doing'. He has limited verbal "
 "communication. Two long-standing staff left the home two months ago and agency staff are covering. Incident "
 "records show most incidents occur in the morning, and three different staff have been involved.",
 "Formulate. What would you do, and what would you not do?",
 [("Behavioural / functional analysis",
   "Behaviour is maintained by its consequences; topographically identical behaviours may serve different functions.",
   "The behaviour is communication, and the analysis has to establish what it achieves. Morning clustering and the personal care context point toward escape from an aversive event as the most likely function — negative reinforcement, since hitting out ends or delays the care. Alternatives to test: pain (dental, constipation, musculoskeletal — very commonly missed in this population and consistent with a six-week onset), a sensory aversion to a specific aspect of care, or a change in how care is delivered by unfamiliar agency staff who do not know his routine or his signals.",
   "Generates a precise, testable account and directs assessment before intervention.",
   "Says nothing about his experience or his relationships, and in unskilled hands 'function' becomes a way of talking about a person as a system of contingencies.",
   "ABC recording across settings and staff before any intervention; medical review to exclude pain FIRST; antecedent-level change — same staff, predictable sequence, communication of each step, offering control over order and timing.",
   "If escape-maintained, incidents should reduce when care is made predictable and he is given control over its sequence, without any consequence-based programme. If they persist unchanged, look harder at pain."),
  ("Systemic / staff-team",
   "The unit of analysis is the home, not the man. Staff attributions drive staff behaviour, which drives his.",
   "Two familiar staff left; agency staff arrived who do not know him, his signals or his routine; care became less predictable and less attuned; he protested in the only way available; staff — being unfamiliar and anxious — became more task-focused and quicker, which made care more aversive; he escalated. The attribution 'attention-seeking' and 'knows what he is doing' is doing work in this loop: it licenses a response that is firmer and less curious, and it protects staff from the more painful thought that he is distressed and they are the cause.",
   "Explains the timing, which the individual formulation alone does not, and identifies the intervention target that will actually move — the staff group.",
   "Can be experienced as blaming staff, who are under-resourced and frightened, and who need containment before they can hear a reformulation.",
   "Team formulation as the primary intervention; support the staff group's own distress before challenging their attributions; consistency of staffing as a clinical prescription; supervision and reflective practice for the team.",
   "If staff-mediated, incidents should cluster by staff member and by shift pattern, and should reduce with consistency of staffing alone. The incident records already contain the data to check this."),
  ("Attachment / trauma-informed",
   "Loss and unpredictability activate threat; personal care is a context of profound vulnerability.",
   "Two people who knew him well disappeared two months ago, and nobody appears to have thought about that as a bereavement. He may have had no explanation he could understand and no way to ask. Personal care requires him to permit strangers to touch his body — with a plausible history of institutional care, and a population with markedly elevated rates of abuse. Hitting out during intimate care in a man who cannot say no verbally has an obvious alternative reading.",
   "Raises the safeguarding question that a purely behavioural formulation can miss entirely, and dignifies the loss.",
   "Speculative without evidence, and can lead to trauma explanations that are unfalsifiable and unactionable.",
   "Safeguarding consideration held explicitly and appropriately; work on the loss in accessible ways — photographs, a goodbye that did not happen; consent and choice built into every step of care as a matter of routine.",
   "If loss or threat is central, distress should be evident beyond care contexts — sleep, appetite, withdrawal, seeking the departed staff — not confined to personal care."),
  ("PBS / contextual",
   "Behaviour change is achieved by changing the environment and teaching skills, not by managing consequences; quality of life is the outcome.",
   "The formulation integrates the above into a plan whose primary outcome is his quality of life, not the incident count. The risk in this referral is that success gets defined as fewer incidents, which can be achieved by restricting him — and that is a worse outcome achieved more quickly.",
   "Keeps the outcome honest and guards against restrictive practice being adopted as a solution.",
   "Requires organisational commitment that a single psychologist may not be able to secure.",
   "A PBS plan built with staff and, as far as possible, with him and his family: antecedent strategies, teaching a functionally equivalent communication response, and reactive strategies that are least restrictive and explicitly time-limited.",
   "Track quality of life and engagement alongside incidents. If incidents fall while engagement and activity also fall, the plan is restricting him rather than helping him.")],
 "What you would NOT do is the part that distinguishes candidates. You would not accept the referral question "
 "as framed. 'Attention-seeking' is an attribution, not a formulation, and it predicts a staff response that "
 "makes things worse — the strong move is to say that curiously rather than correctingly, because the staff "
 "group is frightened and under-resourced. You would not intervene before excluding pain, which is the single "
 "most commonly missed cause of new behaviour change in this population. And you would not deliver "
 "individual therapy as your primary response: this is Cardiff's non-1:1 question in clinical form, and the "
 "leverage is in the environment and the team.", 4)

vignette("v_dementia_carer", "The carer who calls", "Cardiff 2012 and 2013 (both years put a version of this to candidates)",
 "A woman rings your service. Her husband, who has early signs of a degenerative dementia, is refusing to attend "
 "the neurology appointment for diagnostic testing. She is distressed and says she does not know what to do. She "
 "asks you to talk to him, or to tell her what to say. Her husband is not open to your service and has not "
 "consented to you discussing him.",
 "How would you handle this? What are the issues?",
 [("Capacity and ethics",
   "Capacity is decision-specific and presumed; an unwise decision is not evidence of its absence.",
   "He is refusing a diagnostic appointment. Unless there is reason to think he cannot understand, retain, weigh or communicate this specific decision, that refusal is his to make and must be respected, however distressing for his wife and however much earlier diagnosis might help. Even if capacity were in question for this decision, the route is assessment and best-interests process — not persuasion arranged by a third party. Confidentiality also constrains you: you cannot discuss him without consent. But it does not stop you listening to her, giving general information, or supporting her in her own right, because none of those require disclosure.",
   "Prevents the most common error — being recruited into managing him on her behalf.",
   "Risks sounding legalistic to a frightened person if it is the first thing you say.",
   "Support her, explicitly and in her own right; be clear and kind about what you can and cannot do and why; offer general information about the condition, about the value of assessment, and about carers' rights including a statutory carer's assessment.",
   "The test of whether you have got this right: has anything been done TO him without his knowledge or consent as a result of this call?"),
  ("Systemic",
   "The referral is from one part of the system about another; the pattern between them is the material.",
   "She is asking you to join a coalition. Her fear is entirely understandable — she is watching her husband change and losing control of a future she cannot alter, and getting a diagnosis is one of the few actions available to her. But the more she pushes, the more he may need to refuse in order to retain some authorship over what is happening to him. There is a loop here, and joining her side of it will strengthen it. Worth asking: what does he think is happening? What does a diagnosis mean to each of them — for her, a plan; for him, perhaps the loss of driving, of work, of standing?",
   "Reframes his refusal as meaningful rather than obstructive, and identifies why persuasion will fail.",
   "Requires care not to imply she is at fault when she is frightened and exhausted.",
   "Be curious with her about the pattern: how it goes when she raises it, what he says, what he might be protecting. Explore what would happen if she stopped raising it for a period.",
   "If the loop is operating, reducing the pressure should change his response — which is a suggestion you can make to her and she can test this week."),
  ("Carer-focused",
   "The carer has needs and rights of her own, independent of the person she cares for.",
   "She is a person in distress who has contacted a service, and she is entitled to a response in her own right. She has a statutory right to a carer's assessment. She may be experiencing anticipatory grief, isolation, fear about the future, and guilt about her own frustration with him — none of which require his consent to address.",
   "Turns a call you cannot act on into a piece of work you can do, and is the answer Cardiff is listening for, given how heavily that course weights carer involvement.",
   "Does not resolve the presenting request, and she may initially experience it as a deflection.",
   "Acknowledge the difficulty of the position she is in; offer or signpost carer support and a carer's assessment; give general information; agree what she will do if his safety becomes a concern.",
   "She should end the call with something concrete for herself, not only an explanation of what you cannot do.")],
 "The trap is the request itself: 'talk to him' or 'tell me what to say'. Answering it directly breaches "
 "confidentiality and treats a capacitous adult as an object of management. The strong answer holds three "
 "things at once — his autonomy, her real distress and her own entitlement to support, and the loop between "
 "them that persuasion is feeding. Cardiff asks carer questions in every year sampled, and a carer sits on the "
 "panel, so this is a high-frequency scenario for you specifically. If a carer asks it, answer to them.", 3)

vignette("v_stuck", "Twelve sessions and stuck", "Birmingham 2018 clinical interview, verbatim question",
 "You have been seeing a man in his forties for twelve sessions for depression. He attends reliably and is polite. "
 "He completes what you ask between sessions. His scores have not moved. When you ask how he found the last "
 "session he says it was helpful. You leave sessions feeling flat and slightly bored, and you have noticed you "
 "check the clock.",
 "What factors might you consider?",
 [("Formulation review",
   "Stuckness is most often a signal that the formulation is wrong or incomplete.",
   "Twelve sessions of compliance without change suggests the hypothesised mechanism may not be the operative one. Is this depression at all, or grief, or an untreated physical cause, or the appropriate response to circumstances that have not changed — an unbearable job, a dying parent, debt, a marriage he has not mentioned? Is something maintaining it that is not in the formulation: alcohol, chronic pain, a partner who is undermining, a secret?",
   "Directs you back to the highest-yield explanation rather than to a new technique.",
   "Can become an endless reformulation that avoids the relational question.",
   "Reformulate from scratch WITH him, explicitly, including the possibility that you have got it wrong.",
   "If the formulation is wrong, a genuinely open reformulation should produce material that was not previously available."),
  ("Alliance and process",
   "Compliance is not engagement, and the therapist's boredom is data.",
   "Politeness, reliable attendance and 'it was helpful' can be a form of accommodation — he may be being a good patient rather than doing the work, possibly because disagreeing with professionals is not safe or not permitted for him. Your flatness and clock-watching are the most useful information you have: if he is producing an interaction that is agreeable and empty, you are experiencing something about how he manages relationships, and quite possibly what others experience with him.",
   "Uses countertransference as data rather than as a personal failing, which is exactly the move Birmingham's question invites.",
   "Requires care in how it is raised — clumsily done, it can shame him.",
   "Name the process tentatively and non-blamefully: 'I've been wondering whether we've been having quite a polite conversation, and whether there are things that have felt hard to say to me.' Take the boredom to supervision first.",
   "If this is a relational pattern, naming it should produce a live shift in the room — either genuine contact or a visible increase in politeness, and both are informative."),
  ("Model and fit",
   "The intervention may be wrong, the timing wrong, or the goal not his.",
   "Whose goal is symptom reduction? He may have come because his GP sent him, or because his wife asked, and may be complying with a task he did not choose. A behavioural account would ask whether the homework is actually being done in a way that contacts reinforcement, or completed as paperwork. It is also worth asking whether a different model — ACT, if the issue is a life narrowed by avoidance, or something interpersonal — fits better than continuing.",
   "Opens the possibility that continuing is the wrong answer, which candidates rarely say.",
   "Risks abandoning a workable approach too early.",
   "Renegotiate goals from the beginning; consider a change of model, a break, or an honest ending; ask directly what he would want to be different if therapy could not give him anything else.",
   "If the goal is not his, asking directly what HE wants should produce a different answer from the referral question."),
  ("Outside the room",
   "Therapy cannot resolve what is being generated outside it.",
   "If his circumstances are genuinely depressing — insecure work, debt, caring, isolation, discrimination — then the absence of change may be an accurate reflection of reality rather than a failure of technique. Twelve sessions of cognitive work will not move a score that is tracking his housing situation.",
   "Guards against the individualising error and points toward material and social intervention.",
   "Can become a reason not to look at the relationship.",
   "Ask what has and has not changed in his circumstances; consider social prescribing, welfare advice, debt support, or advocacy as legitimate psychological interventions.",
   "If circumstances are driving it, the pattern of scores should track life events rather than therapy content.")],
 "The move that lifts this answer is treating your own boredom as the primary data. Most candidates list "
 "techniques; the strong answer says 'the most useful information I have is my own flatness, and I would take "
 "that to supervision before I did anything else, because it probably tells me something about how he manages "
 "relationships.' Then: reformulate, name the process with him, check whose goal we are pursuing, and look "
 "outside the room. Note that 'consider ending' belongs in the answer — knowing when to stop is a competence, "
 "not a failure.", 4)

# =====================================================================
# ROLE-PLAY: branching, scored on process moves
# =====================================================================
RP = []
def roleplay(id, title, source, brief, setting, character, opening, turns, debrief, difficulty=3):
    RP.append(dict(id=id, title=title, source=source, brief=brief, setting=setting,
                   character=character, opening=opening, turns=turns, debrief=debrief,
                   difficulty=difficulty))

# scoring dimensions used by every role-play turn
DIMS = {"open": "Opening space", "reflect": "Reflecting", "validate": "Validating",
        "explore": "Staying with experience", "fix": "Advising too early",
        "close": "Closing down", "self": "Managing own agenda"}

roleplay("rp_timekeeping", "The colleague and the timekeeping feedback",
 "Glasgow 2018 — one of four scenarios given to candidates a week in advance, verbatim",
 "Your colleague approaches you to discuss a work-related problem. They are of equal status, so there is no power "
 "relationship. There is NO expectation that you resolve the problem. Your aim is (a) to establish the "
 "circumstances leading to the problem and (b) to establish and understand your colleague's reaction to those "
 "circumstances.",
 "An office in your workplace. Mid-afternoon. You have about eight minutes.",
 "Sam, a colleague of equal status, who has just come from a meeting with your shared line manager.",
 "Have you got a minute? Sorry — I know you're busy. I've just come out of a meeting with Jo and I'm… I don't really know what to do with it, to be honest.",
 [
  {"says": "She's had a go at me about my timekeeping. Apparently I've been late 'a number of times'. She wouldn't even say who'd mentioned it.",
   "options": [
     {"t": "Have you been late, though?", "d": "close", "s": -2, "f": "This puts them on trial in the first thirty seconds. Whether they were late is not the task — the brief asks you to establish the circumstances and understand their reaction."},
     {"t": "That sounds like it landed pretty hard. What happened?", "d": "open", "s": 3, "f": "Names the impact and opens the space. This is exactly what the brief asks for."},
     {"t": "Jo does that with everyone. I wouldn't take it personally.", "d": "close", "s": -2, "f": "Reassurance that dismisses the feeling and closes the topic. It also aligns you against a manager on no evidence."},
     {"t": "Do you want to make a formal complaint?", "d": "fix", "s": -3, "f": "Solving a problem you have not yet understood, and escalating something they have not asked to escalate."}]},
  {"says": "It was just… she called me in, sat me down, and said it had been 'raised'. Passive voice, you know? Like I'm supposed to guess who. And I have been late — a few times. My mum's been ill and I've been doing her mornings before work. I didn't want to make a thing of it.",
   "options": [
     {"t": "You should have told her about your mum. She'd have to make allowances.", "d": "fix", "s": -2, "f": "Advice, and slightly blaming — 'you should have'. They have just told you something vulnerable and this steps straight over it."},
     {"t": "So you've been getting your mum up in the mornings, and you didn't tell anyone at work — and now it's come back to you as a complaint.", "d": "reflect", "s": 3, "f": "Reflects both the circumstance and its sting, and holds them together. It also gently makes visible the choice they made without judging it."},
     {"t": "How is your mum?", "d": "explore", "s": 1, "f": "Kind, and human. Slightly risks moving away from the work problem they came with, but a brief version of this is warm rather than diverting."},
     {"t": "That's really unfair of her then.", "d": "validate", "s": 0, "f": "Sympathetic, but it takes a side on facts you do not have, and it closes off exploring their own mixed feelings — which are the interesting part."}]},
  {"says": "Yeah. And the thing is, I'm annoyed with her, but I'm mostly annoyed with myself. I should have just said something. Now it looks like I've been getting away with something.",
   "options": [
     {"t": "You've got nothing to feel guilty about. You were caring for your mum.", "d": "close", "s": -1, "f": "Well-meant, but it argues them out of a feeling instead of understanding it, and it can leave them feeling unheard."},
     {"t": "There's something about how it looks that's bothering you more than the lateness itself.", "d": "reflect", "s": 3, "f": "Picks up the real thread — this is about being seen as someone who gets away with things. This is understanding their reaction, which is what the brief asks for."},
     {"t": "What do you think stopped you from saying something at the time?", "d": "explore", "s": 3, "f": "Curious, non-judgemental, and goes to the heart of it without telling them what to think."},
     {"t": "I'd have done the same thing, honestly.", "d": "self", "s": 0, "f": "Normalising, but it turns the conversation toward you. Use sparingly and briefly, if at all."}]},
  {"says": "I suppose I didn't want to be the person with the problem. Everyone's stretched. And if I'm honest I thought if I said it out loud I might not be able to keep doing it — the job and mum, I mean.",
   "options": [
     {"t": "That sounds like a lot to be carrying on your own.", "d": "validate", "s": 3, "f": "Validation at the right moment, after they have disclosed the thing underneath. Not agreement, not reassurance — recognition."},
     {"t": "Do you think you can keep doing both?", "d": "explore", "s": 2, "f": "A real question that follows what they said. Slightly early — the validation lands better first — but it does not close anything down."},
     {"t": "Have you looked into carer's leave? I think there's a policy.", "d": "fix", "s": -2, "f": "The information may be useful later. Offered here, it steps over the thing they have just risked saying and turns it into an admin problem."},
     {"t": "Right, so the practical issue is the mornings.", "d": "close", "s": -2, "f": "Reduces a personal disclosure to a logistics problem, and misses everything they just told you about not wanting to be the person with the problem."}]},
  {"says": "I don't know. Probably not forever. [pause] Sorry, I didn't mean to dump all this on you. I just wanted to moan about Jo really.",
   "options": [
     {"t": "You haven't dumped anything on me. It sounds like there's quite a lot going on beyond Jo.", "d": "validate", "s": 3, "f": "Declines the retreat without pushing, and names what has actually happened in the conversation."},
     {"t": "No problem. So what are you going to do about Jo?", "d": "fix", "s": -2, "f": "Accepts the retreat and heads for a solution. The brief explicitly says you are not expected to resolve the problem."},
     {"t": "Was there something you were hoping to get out of talking it through?", "d": "open", "s": 2, "f": "A good closing move — asking rather than prescribing what would help. Slightly early here, since they have just pulled back."},
     {"t": "It's fine, everyone needs to vent.", "d": "close", "s": -1, "f": "Minimises what they said and lets the retreat stand."}]},
 ],
 "Glasgow's brief is unusually explicit and worth taking literally: establish the circumstances, understand the "
 "reaction, and do NOT resolve the problem. Almost every negative score above is an attempt to fix, reassure or "
 "advise. The other thing to notice is the shape of the conversation — it starts as a complaint about a manager "
 "and, if you stay with it, becomes about a caring responsibility and a fear of not coping. That movement only "
 "happens if you resist the first three opportunities to solve it. If you find yourself offering the carer's "
 "leave policy in minute two, you have taken the role of manager rather than colleague.")

roleplay("rp_examstress", "The student with exam stress",
 "Southampton 2015 — verbatim role-play brief",
 "You are playing a college counsellor. You are about to see a student who is struggling with exam stress. No "
 "intervention as such is expected — the purpose is to see how you engage with the client and your brief "
 "assessment and formulation skills. About eight minutes.",
 "A small counselling room at a further education college. First appointment.",
 "Aisha, 19, first year, referred by her tutor after missing two mock exams.",
 "Hi. Um. My tutor said I had to come. I don't really know what I'm supposed to say.",
 [
  {"says": "I mean, it's just exams, isn't it. Everyone's stressed. I don't know why she made a big deal of it.",
   "options": [
     {"t": "Your tutor was worried enough to refer you. What do you think she noticed?", "d": "open", "s": 3, "f": "Acknowledges the referral route honestly and invites her perspective on it rather than defending the tutor."},
     {"t": "Exam stress is really common. Let's talk about some techniques.", "d": "fix", "s": -3, "f": "Accepts her minimisation, skips assessment entirely, and starts intervening in the first minute."},
     {"t": "It sounds like you'd rather not be here.", "d": "reflect", "s": 3, "f": "Names the elephant in the room, which almost always improves engagement in a mandated referral."},
     {"t": "Well, you missed two mocks — that's not nothing.", "d": "close", "s": -2, "f": "Confronts with the evidence before any relationship exists. She will comply or withdraw; neither helps."}]},
  {"says": "I don't know. I suppose I didn't go to the mocks. I got there — I was outside the hall — and I just couldn't go in. I walked home. I didn't tell anyone.",
   "options": [
     {"t": "What was happening for you, standing outside that hall?", "d": "explore", "s": 3, "f": "Goes straight to the moment with an open question. This is where the formulation lives."},
     {"t": "That must have been frightening.", "d": "validate", "s": 2, "f": "Warm and probably accurate, though it names the feeling for her rather than asking. Better after she has described it."},
     {"t": "Have you had panic attacks before?", "d": "close", "s": 0, "f": "A reasonable question that arrives too soon and in closed form. It hands her a label rather than eliciting her account."},
     {"t": "OK. So we need to get you back in that hall.", "d": "fix", "s": -3, "f": "Jumps to the goal before understanding anything, and is likely to be experienced as exactly what she feared."}]},
  {"says": "My heart was going really fast and I felt sick and I thought I was going to be sick in front of everyone. And then I thought if I go in and I can't do it, that's worse, because then everyone knows.",
   "options": [
     {"t": "So going in risked everyone seeing you fail — and walking away meant nobody saw.", "d": "reflect", "s": 3, "f": "Reflects the appraisal precisely and hands her the beginning of a formulation in her own terms."},
     {"t": "Those are physical symptoms of anxiety — your body's alarm system.", "d": "fix", "s": 1, "f": "Accurate psychoeducation, but it arrives before she has finished, and explaining can shut down disclosure."},
     {"t": "What would 'everyone knowing' mean?", "d": "explore", "s": 3, "f": "Goes underneath the appraisal to the meaning. This is the question that finds the belief."},
     {"t": "Did you feel better once you'd left?", "d": "explore", "s": 3, "f": "Elegant — establishes the negative reinforcement without any jargon, and she will say yes."}]},
  {"says": "[quietly] My parents came here so I could do this. My brother didn't finish. If I mess it up… I don't know. It's not really about the exam.",
   "options": [
     {"t": "It's not really about the exam.", "d": "reflect", "s": 3, "f": "Simple reflection of her own words at the moment they matter most. Says nothing, does everything."},
     {"t": "That's a lot of pressure to be carrying at nineteen.", "d": "validate", "s": 3, "f": "Validation that names the weight without interpreting it for her."},
     {"t": "Have you talked to your parents about how you're feeling?", "d": "fix", "s": -1, "f": "A reasonable question eventually, but here it moves away from her at the exact moment she has moved toward you."},
     {"t": "So it's about letting your family down.", "d": "close", "s": 0, "f": "Probably right, but stated as a conclusion. She has just said 'I don't know' — she needs room, not an interpretation."}]},
  {"says": "[looks at the clock] Is that it, then? Do I have to come back?",
   "options": [
     {"t": "That's yours to decide. What was it like, saying that out loud?", "d": "open", "s": 3, "f": "Gives her control — which matters enormously in a mandated referral — and closes by checking the experience of the session."},
     {"t": "I think it would really help if you did.", "d": "close", "s": -1, "f": "Well-intentioned, but it takes the choice from someone whose difficulty is partly about things being decided for her."},
     {"t": "Yes, we should book six sessions.", "d": "fix", "s": -3, "f": "Imposes a contract she has not agreed to at the moment she is asking whether she has any choice."},
     {"t": "You don't have to. But I'd be glad to see you again if you wanted.", "d": "validate", "s": 3, "f": "Autonomy plus an honest offer. Clear, warm, and leaves the door open without pushing her through it."}]},
 ],
 "Southampton then asks three questions: what was the presenting issue, how could the intervention move forward, "
 "and what about your performance could be improved. Prepare all three. The presenting issue is not exam stress — "
 "it is avoidance maintained by immediate relief, with a fear of visible failure carrying family meaning. For the "
 "third question, name something real and specific: 'I explained the physiology slightly too early and she stopped "
 "talking for a moment' is a much stronger answer than 'I could have been more empathic'. The candidate who wrote "
 "this paper up added a reassurance worth keeping: 'once the conversation started I actually forgot I was being "
 "observed'.")

roleplay("rp_carer_call", "The carer who wants you to intervene",
 "Cardiff 2012 and 2013 — a version of this appears in both years",
 "You take a call from the wife of a man with early signs of a degenerative dementia. He is refusing to attend a "
 "neurology appointment for diagnostic testing. He is not open to your service and has not consented to you "
 "discussing him. Establish what is happening, be clear about what you can and cannot do, and respond to her as "
 "someone with needs of her own.",
 "A telephone call, taken at your desk. You have about seven minutes.",
 "Margaret, 68, married for forty-one years.",
 "I'm sorry to ring out of the blue. I got your number from the memory clinic. It's about my husband — he won't go to his appointment and I don't know what else to do.",
 [
  {"says": "They've booked him in twice now and both times he's refused to get in the car. I've tried everything. Can you talk to him? Or tell me what to say to him?",
   "options": [
     {"t": "I can't discuss him without his consent, I'm afraid.", "d": "close", "s": -2, "f": "Correct, and delivered as a door closing on a frightened person in the first minute. The content is right; the timing and framing are wrong."},
     {"t": "It sounds like you've been trying very hard on your own. Can you tell me a bit about what's been happening?", "d": "open", "s": 3, "f": "Acknowledges her effort and opens the space. You can be clear about the limits shortly — but not before she feels heard."},
     {"t": "Of course. What would you like me to say to him?", "d": "self", "s": -3, "f": "Agrees to something you cannot do. He is a capacitous adult who has not consented to your involvement."},
     {"t": "Has he been assessed as lacking capacity?", "d": "close", "s": -1, "f": "The right concept, asked in a way that will mean nothing to her and signals you are processing rather than listening."}]},
  {"says": "He's just being stubborn. He's always been stubborn. He says there's nothing wrong with him and he doesn't need doctors poking about. But there IS something wrong — he got lost coming back from the shop last month.",
   "options": [
     {"t": "That must have been frightening for you both.", "d": "validate", "s": 3, "f": "Picks up the thing underneath the frustration. She is frightened, and 'stubborn' is easier to say."},
     {"t": "What do you think it would mean to him, to go and be told?", "d": "explore", "s": 3, "f": "Beautifully placed — invites her to consider his position, which is the beginning of a systemic shift, without asking her to give up her own."},
     {"t": "Getting lost is a significant sign. He really does need that assessment.", "d": "fix", "s": -2, "f": "Recruits you onto her side of the very argument that is stuck, and increases the pressure on him."},
     {"t": "Has he always refused medical appointments?", "d": "explore", "s": 1, "f": "Useful history, but it moves to fact-gathering just as feeling appeared."}]},
  {"says": "[pause] I hadn't thought about it like that. I suppose he'd have to stop driving. That's his freedom, that is. He drives everywhere. [pause] But I can't just leave it, can I?",
   "options": [
     {"t": "You're caught between respecting what he wants and being frightened about what happens if nothing's done.", "d": "reflect", "s": 3, "f": "Names the dilemma precisely and does not resolve it for her. This is the heart of the call."},
     {"t": "No, you can't leave it. There are things that can help if it's caught early.", "d": "fix", "s": -1, "f": "True, and it takes a side in a dilemma she is only just beginning to hold — and pushes her back into persuading him."},
     {"t": "What do you think would happen if you stopped raising it for a few weeks?", "d": "explore", "s": 3, "f": "A genuinely systemic intervention offered as a question. It interrupts the loop and gives her something she can actually test."},
     {"t": "Ultimately it's his decision to make.", "d": "close", "s": 0, "f": "Legally accurate and, said alone at this point, it can land as abandonment. Pair it with something she can do."}]},
  {"says": "I don't know. I'd feel like I was giving up on him. [quietly] I'm so tired. I'm sorry. I didn't mean to go on.",
   "options": [
     {"t": "You're not going on. You've been holding this by yourself for a while, by the sound of it.", "d": "validate", "s": 3, "f": "Declines the apology and names her exhaustion. This is the moment the call turns from being about him to being about her."},
     {"t": "It's completely understandable. Now, about the appointment —", "d": "close", "s": -3, "f": "A sympathetic noise followed by a return to business. She has just told you she is exhausted."},
     {"t": "Have you had any support for yourself in all this?", "d": "explore", "s": 3, "f": "Moves to what you can actually offer, at exactly the right moment, and treats her as someone with needs of her own."},
     {"t": "You should look after yourself too.", "d": "fix", "s": -1, "f": "An instruction rather than an offer. It sounds caring and gives her one more thing to fail at."}]},
  {"says": "Not really. My daughter rings. There's not much she can do from Leeds. What can you actually do, then?",
   "options": [
     {"t": "Let me be honest about that. I can't approach him or discuss him without his agreement — that's his right. But I can talk with you, and you're entitled to support in your own right, including a carer's assessment. Shall I explain what that is?", "d": "open", "s": 3, "f": "Honest, clear, kind, and lands on something concrete for HER. This is the answer Cardiff is listening for."},
     {"t": "Not a great deal without his consent, I'm afraid.", "d": "close", "s": -3, "f": "Accurate and useless. She ends the call with nothing."},
     {"t": "I could see if a GP would do a home visit.", "d": "fix", "s": -1, "f": "Arranging something about him without his knowledge — the same breach in a different coat."},
     {"t": "I can send you some information about dementia and about carers' services, and we can talk again.", "d": "validate", "s": 2, "f": "Genuinely useful and appropriate. Slightly less strong than naming the carer's assessment and her entitlement explicitly."}]},
 ],
 "Two things are being tested at once: whether you protect the autonomy of a man who is not your patient, and "
 "whether you can nonetheless respond to a distressed woman who is. Candidates tend to fail in one of two "
 "directions — being recruited into managing him, or reciting confidentiality at someone who is frightened. The "
 "resolution is that listening, giving general information and supporting her in her own right require no "
 "disclosure at all. Note the systemic move in turn three: asking what would happen if she stopped raising it is "
 "both a real intervention and something she can test this week. Cardiff weights carers heavily and puts a carer "
 "on the panel — expect a version of this.")

OUT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
p1 = os.path.join(OUT, "trainer", "data", "formulation.json")
p2 = os.path.join(OUT, "trainer", "data", "roleplay.json")
json.dump({"version": 1, "vignettes": V}, open(p1, "w"), indent=1, ensure_ascii=False)
json.dump({"version": 1, "dims": DIMS, "scenarios": RP}, open(p2, "w"), indent=1, ensure_ascii=False)
print(f"{len(V)} vignettes ({sum(len(v['models']) for v in V)} model formulations) -> formulation.json")
print(f"{len(RP)} role-plays ({sum(len(r['turns']) for r in RP)} turns, {sum(len(t['options']) for r in RP for t in r['turns'])} options) -> roleplay.json")
