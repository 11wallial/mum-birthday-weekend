## Names of the systems a run can be given.
##
## Each floor hands the player one new verb, and the verb stays for the rest of
## the run: the game is not seven variations on a slot machine, it is a slot
## machine that becomes six other games while you are still playing the first
## one. Naming them in one place keeps a floor's grant, the simulation's gate
## and the interface's affordance from ever drifting apart.
class_name Systems
extends RefCounted

## Hold reels between spins, and spend nudges to pull the band onto the payline.
const HOLD: StringName = &"hold"
## Reroll the draft, sell hardware back, and buy on the slate.
const MARKET: StringName = &"market"
## Raise the stake per spin.
const STAKE: StringName = &"stake"
## Double or nothing on a winning spin.
const GAMBLE: StringName = &"gamble"
## Bank cash where it earns interest and cannot pay an ante.
const VAULT: StringName = &"vault"
## Sign a house contract that rewrites one floor's rules.
const CONTRACTS: StringName = &"contracts"
## Bolt extra reels and extra scoring rows onto the machine.
const EXPANSION: StringName = &"expansion"
## The House counts your wins and answers them.
const HEAT: StringName = &"heat"

## Every system, in the order the floors hand them out.
const ORDER: Array[StringName] = [
	HOLD, MARKET, STAKE, GAMBLE, VAULT, CONTRACTS, EXPANSION, HEAT,
]

## Short name shown when a floor grants the system.
const TITLES: Dictionary = {
	HOLD: "HOLD & NUDGE",
	MARKET: "THE MARKET",
	STAKE: "THE STAKE",
	GAMBLE: "THE GAMBLE",
	VAULT: "THE VAULT",
	CONTRACTS: "HOUSE CONTRACTS",
	EXPANSION: "THE WORKS",
	HEAT: "THE COUNT",
}

## One line telling the player what they just gained the ability to do.
const BRIEFS: Dictionary = {
	HOLD: "Hold reels between spins. Land a pair and the machine owes you a nudge.",
	MARKET: "Reroll the draft, sell hardware back, or buy it on the slate.",
	STAKE: "Raise the stake. It costs more per spin and pays the same multiple.",
	GAMBLE: "A win can be doubled. Four times, if your nerve holds.",
	VAULT: "Cash left in the vault earns interest — and cannot pay an ante.",
	CONTRACTS: "Sign for the floor. Every contract gives and every contract takes.",
	EXPANSION: "Bolt on reels and rows. The machine gets bigger from here.",
	HEAT: "The House is counting. Win too well and it answers.",
}


static func title(id: StringName) -> String:
	return String(TITLES.get(id, String(id).to_upper()))


static func brief(id: StringName) -> String:
	return String(BRIEFS.get(id, ""))
