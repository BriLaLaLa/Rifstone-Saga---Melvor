class_name DebugTimeSkip
extends RefCounted
## Tester tool (M25-07): "Avanza il tempo" passes N hours of game time through the real offline path (same blocks,
## same summary as a real absence), capped at `offline.cap_ms`. The hours chosen live in user://settings.cfg
## (GameSettings.KEY_DEBUG_SKIP_HOURS), never in a slot; the skip itself only advances the session like any absence.

const HOUR_MS: int = 3600000


## Largest whole number of hours allowed by the offline cap.
static func max_hours(session: GameSession) -> int:
	return maxi(1, int(session.data.balance_value(OfflineSimulator.CAP_KEY)) / HOUR_MS)


## Milliseconds actually simulated for `hours` (clamped to the offline cap; <= 0 hours gives 0).
static func elapsed_ms(session: GameSession, hours: int) -> int:
	var cap_ms: int = int(session.data.balance_value(OfflineSimulator.CAP_KEY))
	return clampi(hours * HOUR_MS, 0, cap_ms)


## Skips `hours` of play (coroutine: call with await). From offline.min_ms on it runs the simulator (events on
## session.events, summary returned); below it the same blocks run silently and null is returned.
func run(session: GameSession, hours: int, yield_frames: bool = true) -> OfflineSummary:
	var cap_ms: int = int(session.data.balance_value(OfflineSimulator.CAP_KEY))
	var elapsed: int = elapsed_ms(session, hours)
	if elapsed <= 0:
		return null
	if elapsed < int(session.data.balance_value(OfflineSimulator.MIN_KEY)):
		OfflineSimulator.advance_silently(session, elapsed)
		return null
	return await OfflineSimulator.new().run(session, elapsed, hours * HOUR_MS > cap_ms, yield_frames)
