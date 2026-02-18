# Coqui API Improvement Suggestions

Observations from building the Flutter client against the Coqui HTTP API.

## Session Management

### PATCH /api/sessions/{id}

Allow updating session metadata without deleting and recreating. The client currently generates titles by truncating the first message to 50 characters. A PATCH endpoint would let the client set or update the title (and potentially the model_role) on an existing session.

```
PATCH /api/sessions/{id}
{
    "title": "Weather in Paris",
    "model_role": "coder"
}
```

### Server-Side Title Generation

Consider adding an optional `generate_title` flag on `POST /api/sessions/{id}/messages` that triggers server-side title generation after the first prompt. The server already has LLM access and could produce a better title than the client's 50-char truncation. Return the generated title in the `complete` SSE event or as a field on the session.

## Streaming

### Stream Cancellation

The current SSE stream is read-only (server to client). When the user cancels mid-stream, the client simply stops reading events, but the agent continues running server-side until it finishes. Consider:

- A `DELETE /api/sessions/{id}/current-turn` endpoint to abort the running agent
- Or a WebSocket upgrade path for bidirectional control

### Heartbeat Events

Long-running agent turns (multi-tool, child agents) can take 30+ seconds. Some proxies and mobile clients may time out. Consider periodic `heartbeat` SSE events (every ~15s) to keep the connection alive and signal the client that work is still in progress.

## Messages

### Pagination

`GET /api/sessions/{id}/messages` returns all messages. For long-running sessions this could grow large. Add pagination:

```
GET /api/sessions/{id}/messages?limit=50&before=<message_id>
```

### Message Metadata

Include the turn_id on each message so the client can group messages by turn without a separate API call. This would allow showing turn boundaries (iterations, tools used) inline in the chat.

## Health Endpoint

### Consistent Auth Behavior

The API docs state `GET /api/health` doesn't require authentication, but the client benefits from always sending the key to validate it's correct during connection testing. Consider:

- Accepting (but not requiring) the auth header on health
- Returning an `authenticated: true/false` field in the response so the client can verify the key works in the same call

### Version Compatibility

Include a `min_client_version` or `api_version` field in the health response so clients can warn users if their app version is too old for the server.

```json
{
    "status": "ok",
    "version": "0.2.0",
    "api_version": 1,
    "min_client_version": "0.1.0"
}
```

## Configuration

### Role Descriptions

`GET /api/config/roles` returns role names and model mappings. Consider adding a `description` field to each role so the client can show meaningful labels instead of just the role name (e.g., "orchestrator" could show "General-purpose assistant that delegates to specialized agents").

## Error Handling

### Structured Error Codes

Current errors return `{"error": "Human-readable string"}`. Consider adding a machine-readable error code for programmatic handling:

```json
{
    "error": "Session not found",
    "code": "SESSION_NOT_FOUND"
}
```

This lets clients show localized error messages or handle specific errors differently (e.g., auto-creating a new session when `SESSION_NOT_FOUND`).

## Rate Limiting

### Rate Limit Headers

For multi-user deployments, include standard rate limit headers:

```
X-RateLimit-Limit: 60
X-RateLimit-Remaining: 58
X-RateLimit-Reset: 1700000000
```

The client could use these to show a cooldown indicator or queue requests.
