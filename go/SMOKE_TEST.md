# Smoke Test Procedure

Manual steps to verify the relayd stack end-to-end.

## Prerequisites

- Go 1.25+
- `grpcurl` installed and on PATH
- Ports 5353 (DNS), 9876 (gRPC) free

## Steps

### Terminal 1: Start relay server

```bash
cd go
go run ./cmd/relayd/ server --addr :5353 --zone msg.local-domain
```

### Terminal 2: Start client daemon

```bash
cd go
go run ./cmd/relayd/ client --relay 127.0.0.1:5353 --force-blackout --data-dir /tmp/relayd-client
```

### Terminal 3: Query identity via gRPC

```bash
grpcurl -plaintext 127.0.0.1:9876 relaypb.RelayClient/GetIdentity
```

Expected: returns public key JSON.

## Verification

1. Client daemon starts without errors.
2. `GetIdentity` returns a valid public key.
3. Relay server logs incoming queries.
4. Client and relay communicate over DNS on the configured zone.
