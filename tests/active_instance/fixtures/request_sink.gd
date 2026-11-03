extends RelayPeer

# Transport-only spy: the production coordinator still creates, correlates,
# times out and cancels requests. No authorization or results are faked here.
var sent: Array = []

func request_instance(value: Dictionary):
	sent.append(value.duplicate(true))
