# FAFCab Microservices Architecture

Description of the architecture of a microservices-based system for the FAFCab, designed to support internal operations through modular, scalable services. The system uses an event-driven model with RabbitMQ as the message broker and an API Gateway for external access.

---

## Services Overview

| ID | Service Name            | Primary Function |
|----|-------------------------|------------------|
| 1  | User Management         | Manage user profiles, roles, and identity synchronization with Discord |
| 2  | Notification  | Centralized delivery of real-time alerts and notifications |
| 3  | Communication            | Enable public/private chats with moderation and censorship |
| 4  | Tea Management          | Monitor tea, sugar, cups, paper, and markers consumption |
| 5  | Cab Booking             | Schedule room bookings; integrate with Google Calendar |
| 6  | Check-in                | Monitor entry/exit via facial recognition; detect unknown visitors |
| 7  | Lost & Found            | Post and track lost/found items with comments and resolution status |
| 8  | Budgeting               | Track income, expenses, donations, debts, and generate reports |
| 9  | Fund Raising            | Launch campaigns, collect donations, manage goals |
| 10 | Sharing                 | Manage shared equipment and rental tracking |
---

## Core Architecture Components

- **API Gateway**: Entry point for all client requests.
- **RabbitMQ (RMQ)**: Message broker enabling asynchronous communication between services.
- **Notification Service**: Central hub for sending alerts via email, push, or Discord.
- **User Service**: Identity provider used across all services.

All services communicate either directly via REST APIs or asynchronously using events over RMQ.

---

## Service Boundaries and Interactions

### 1. User Management Service
- **Responsibility**: Store and manage user data including roles (`admin`, `student`, `teacher`, `executor`).
- **Integrations**:
  - Syncs user data from Discord.
  - Provides `user_id` and role information to all other services.
- **Events Received**:
  - New user detection from Check-in.
  - Ban actions from Communication Service.

### 2. Tea Management Service
- **Responsibility**: Track inventory & consumption for consumables (tea, sugar, cups, paper, markers) and evaluate low-stock thresholds.
- **Dependencies**:
  - User Service: For identifying users who consume resources.
  - Notification Service: To send low-stock alerts.
- **Event Emitted**:
  - `low_stock`: Triggered when stock levels fall below threshold → sent to Notification Service.
  - `restocked`: Triggered when stock is being renewed → sent to Notification Service.

### 3. Cab Booking Service
- **Responsibility**: Handle room and kitchen space reservations.
- **Integrations**:
  - Google Calendar: Synchronize booking schedules.
  - User Service: Validate booker identity.
  - Notification Service: Send reminders about upcoming bookings.
- **Event Emitted**:
  - `booking_confirmed`: Sent to Notification Service upon confirmation.

### 4. Check-in Service
- **Responsibility**: Record entries and exits using facial recognition.
- **Integrations**:
  - User Service: Verify known users.
  - Notification Service: Alert admins if unknown individuals are detected.
- **Events Emitted**:
  - `entry/exit`: Logs user presence.
  - `unknown_user_detected`: Triggers alert to Notification Service.
  - Sends `user_id` to Tea Management, Sharing, and other services on entry.

### 5. Lost & Found Service
- **Responsibility**: Allow posting of lost or found items with comment threads.
- **Dependencies**:
  - User Service: Authenticate posters.
  - Notification Service: Notify users of updates.
- **Events Emitted**:
  - `post_created`, `comment_added`, `resolved`: Sent to Notification Service.

### 6. Budgeting Service
- **Responsibility**: Maintain financial records including income, expenses, donations, and debts.
- **Integrations**:
  - Fund Raising: Receives final purchase records.
  - Sharing: Updates debt log when items are damaged.
  - User Service: Links debts to users.
- **Events Emitted**:
  - `low_balance`: Alerts admins via Notification Service.
- **Events Received**:
  - `donation`, `expense`, `debt_update` from Fund Raising, Sharing, and Tea Management.

### 7. Fund Raising Service
- **Responsibility**: Create fundraising campaigns and process donations.
- **Integrations**:
  - Budgeting Service: Check available funds before launching campaigns.
  - User Service: Validate donors.
  - Notification Service: Inform contributors and admins.
- **Events Emitted**:
  - `campaign_started`, `donation_received`, `campaign_completed`.
- **Events Received**:
  - `budget_check` request from Budgeting Service.

### 8. Sharing Service
- **Responsibility**: Track shared assets such as games, cords, and kettles.
- **Integrations**:
  - User Service: Identify owners and renters.
  - Budgeting Service: Update debt if item is broken.
  - Notification Service: Alert owners when items are taken or returned.
- **Events Emitted**:
  - `item_taken`, `item_returned`, `damage_reported`.

### 9. Communication Service
- **Responsibility**: Public/private chats, message storage, search, and moderation (filters, reports, sanctions)
- **Features**:
  - Censorship based on banned words.
  - Role-based access control.
  - Reporting and sanctioning (mute, ban).
- **Integrations**:
  - User Service: For user identification and role checks.
  - Notification Service: Deliver message notifications.
- **Events Emitted**:
  - `new_message`: Triggered when new message received in any of the chat type → sent to Notification Service.
  - `message_flagged`: Triggered when message hit the banword and/or get filtered → sent to Notification Service.
  - `sanction_applied`: Triggered when mute/ban placed on user → sent to Notification Service.
  - `member_joined`: Triggered when user joins the group chat → sent to Notification Service.
  - `member_left`: Triggered when user leaves the group chat → sent to Notification Service.
- **Events Received**:
  - `banned_words_list` from admin configuration.

### 10. Notification Service
- **Responsibility**: Centralized delivery of alerts and messages.
- **Functionality**:
  - Subscribes to events from all services.
  - Routes notifications to appropriate channels (Discord, email, etc.).
  - Uses RabbitMQ queues filtered by audience: ALL, Admins, Students, Teachers.
- **Events Received**:
  - From all services: `low_stock`, `restocked`, `booking_confirmed`, `unknown_user`, `post_updated`, `donation_success`, `item_taken`, `new_message`, `message_flagged`, `sanction_applied`, `member_joined`, `member_left`,`low_funds`.

---

## Communication Contract

### 2. TEA MANAGEMENT SERVICE

#### POST `/items` — Create item 
  Request JSON:
  ```
    {
      "name": "Tea Bags",
      "unit": "bag",
      "category": "beverage",
      "sku": "TEA-001",
      "active": true,
      "track_expiry": false,
      "min_stock_qty": 50,
      "tags": ["kitchen", "green"]
    }
  ```
  Response 201 JSON:
  ```
    {
      "id": "9b2f1b53-3f8a-4e5a-93d7-4a7a5b1f8f0e",
      "name": "Tea Bags",
      "unit": "bag",
      "category": "beverage",
      "sku": "TEA-001",
      "active": true,
      "track_expiry": false,
      "min_stock_qty": 50,
      "tags": ["kitchen","green"],
      "stock_qty": 0,
      "soon_expiring": [],
      "created_at": "2025-09-11T10:00:00Z",
      "updated_at": "2025-09-11T10:00:00Z"
    }
  ```
  Errors:
  - 409 CONFLICT (duplicate name/sku)
  - 422 VALIDATION_ERROR

#### GET `/items` — List items
  Query: q, category, low_stock (bool), active (bool), limit, cursor
  Response 200 JSON:
  ```
    {
      "items": [
        {
          "id": "9b2f1b53-3f8a-4e5a-93d7-4a7a5b1f8f0e",
          "name": "Tea Bags",
          "unit": "bag",
          "category": "beverage",
          "sku": "TEA-001",
          "active": true,
          "track_expiry": false,
          "min_stock_qty": 50,
          "tags": ["kitchen"],
          "stock_qty": 120,
          "soon_expiring": [],
          "created_at": "2025-09-11T10:00:00Z",
          "updated_at": "2025-09-11T10:05:00Z"
        }
      ],
      "next_cursor": null
    }
  ```

#### GET `/items/{item_id}` — Item details + live stock
  Path: item_id (uuid) \
  Response 200 JSON:
  ```
    {
      "id": "9b2f1b53-3f8a-4e5a-93d7-4a7a5b1f8f0e",
      "name": "Tea Bags",
      "unit": "bag",
      "category": "beverage",
      "sku": "TEA-001",
      "active": true,
      "track_expiry": false,
      "min_stock_qty": 50,
      "tags": ["kitchen"],
      "stock_qty": 120,
      "soon_expiring": [
        { "batch_id": "b1", "expiry_date": "2025-10-01", "qty_remaining": 20 }
      ],
      "created_at": "2025-09-11T10:00:00Z",
      "updated_at": "2025-09-11T10:05:00Z"
    }
  ```
  Errors: 
  - 404 NOT_FOUND

#### PATCH `/items/{item_id}` — Update metadata
  Request JSON (partial):
  ```
    { "name": "Tea Bags (Jasmine)", "min_stock_qty": 80, "tags": ["kitchen","jasmine"] }
  ```
  Response 200 JSON: (same shape as GET /items/{id})\
  Errors: 
  - 404 NOT_FOUND
  - 422 VALIDATION_ERROR

#### POST `/items/{item_id}/batches` — Add stock lot
  Request JSON:
  ```
    {
      "batch_code": "PO-9876",
      "supplier_ref": "SUP-1",
      "expiry_date": "2025-12-31",
    }
    ```
  Response 201 JSON:
  ```
    {
      "id": "b1",
      "item_id": "9b2f1b53-3f8a-4e5a-93d7-4a7a5b1f8f0e",
      "batch_code": "PO-9876",
      "supplier_ref": "SUP-1",
      "expiry_date": "2025-12-31",
      "qty_received": 200,
      "qty_remaining": 200,
      "currency": "USD",
      "cost_total": 49.90,
      "received_at": "2025-09-11T11:00:00Z"
    }
    ```
  Side-effect events: `inventory.restocked`\
  Errors: 
  - 404 NOT_FOUND
  - 422 VALIDATION_ERROR

#### GET `/items/{item_id}/batches` — List lots
  Response 200 JSON:
  ```
    {
      "batches": [
        { "id": "b1", "item_id": "…", "batch_code": "PO-9876", "expiry_date": "2025-12-31", "qty_received": 200, "qty_remaining": 200, "currency": "USD", "cost_total": 49.90, "received_at": "2025-09-11T11:00:00Z" }
      ],
      "next_cursor": null
    }
  ```

#### POST `/items/{item_id}/consume` — Record consumption (append-only)
  Request JSON:
  ```
    {
      "qty": 3,
      "batch_id": null,              // optional; FIFO selection if null
      "user_id": "u_42",
      "source": "self_service",      // self_service | event | admin
      "notes": "afternoon tea",
      "consumed_at": "2025-09-11T12:00:00Z"
    }
    ```
  Response 201 JSON:
  ```
    {
      "id": "ce1",
      "item_id": "9b2f1b53-3f8a-4e5a-93d7-4a7a5b1f8f0e",
      "batch_id": "b1",
      "qty": 3,
      "user_id": "u_42",
      "source": "self_service",
      "notes": "afternoon tea",
      "consumed_at": "2025-09-11T12:00:00Z",
      "created_at": "2025-09-11T12:00:01Z"
    }
    ```
  Side-effect events: possibly `inventory.low_stock` if threshold crossed\
  Errors: 
  - 404 NOT_FOUND (item/batch) 
  - 409 CONFLICT (insufficient stock)
  - 422 VALIDATION_ERROR

#### GET `/consumption` — Query usage
  Query: 
  - item_id, 
  - user_id, 
  - from, 
  - to, 
  - aggregate=[day|week|month], 
  - limit, 
  - cursor\
  Response 200 JSON:
  ```
    {
      "events": [
        { "id":"ce1","item_id":"…","qty":2,"user_id":"u_1","source":"self_service","consumed_at":"2025-09-11T12:00:00Z" }
      ],
      "totals": { "qty": 2, "by_item": { "…": 2 }, "by_user": { "u_1": 2 } },
      "next_cursor": null
    }
```

#### POST `/thresholds` — Upsert low-stock rule
  Request JSON:

    {
      "item_id": "9b2f1b53-3f8a-4e5a-93d7-4a7a5b1f8f0e",
      "min_qty": 50,
      "notify_config": { "channels": ["tea-room"], "notify_roles": ["inventory_admin"] }
    }

  Response 201 JSON:
  ```
    {
      "id": "th1",
      "item_id": "9b2f1b53-3f8a-4e5a-93d7-4a7a5b1f8f0e",
      "min_qty": 50,
      "notify_config": { "channels": ["tea-room"], "notify_roles": ["inventory_admin"] },
      "created_at": "2025-09-11T10:10:00Z",
      "updated_at": "2025-09-11T10:10:00Z"
    }
```

#### GET `/thresholds` — List thresholds
  Response 200 JSON:
  ```
    {
      "thresholds": [
        { "id":"th1","item_id":"…","min_qty":50,"notify_config":{"channels":["tea-room"],"notify_roles":["inventory_admin"]},"created_at":"…","updated_at":"…" }
      ],
      "next_cursor": null
    }
  ```

#### POST `/announcements` — Create announcement
  Request JSON:

    {
      "title": "New tea arrived!",
      "body": "Try jasmine.",
      "effective_from": "2025-09-12T09:00:00Z",
      "item_ids": ["9b2f1b53-3f8a-4e5a-93d7-4a7a5b1f8f0e"]
    }

  Response 201 JSON:

    {
      "id":"an1",
      "title":"New tea arrived!",
      "body":"Try jasmine.",
      "published_by":"u_admin",
      "effective_from":"2025-09-12T09:00:00Z",
      "created_at":"2025-09-11T12:15:00Z",
      "item_ids":["9b2f1b53-3f8a-4e5a-93d7-4a7a5b1f8f0e"]
    }


#### GET `/announcements` — List announcements
  Response 200 JSON:

    {
      "announcements": [ { "id":"an1", "...": "..." } ],
      "next_cursor": null
    }

#### GET `/reports/stock` — Current stock snapshot
  Query: 
  - format=json|csv

  Response 200 (application/json):
```
    {
      "generated_at": "2025-09-11T13:00:00Z",
      "items": [
        {
          "item_id":"9b2f1b53-3f8a-4e5a-93d7-4a7a5b1f8f0e",
          "name":"Tea Bags",
          "unit":"bag",
          "on_hand":120,
          "soon_expiring":[{"batch_id":"b1","expiry_date":"2025-10-01","qty":20}]
        }
      ]
    }
```

#### GET `/reports/consumption` — Summarized usage
  Query: 
  - group_by=item|user|day
  - from
  - to

  Response 200 JSON:
  ```
    {
      "generated_at":"2025-09-11T13:00:00Z",
      "group_by":"item",
      "rows":[ { "key":"Tea Bags","qty":42 } ]
    }
  ```

#### GET `/health` — Liveness/readiness
  Response 200 JSON:

    {
      "status":"ok",
      "version":"1.0.0",
      "checks": { "db":"ok","events":"ok" },
      "time":"2025-09-11T13:37:00Z"
    }

#### GET `/admin/metrics` — Prometheus metrics
  Response 200 (text/plain):

    # HELP app_requests_total ...
    app_requests_total{route="/items",method="GET"} 123

#### **Event Envelopes** (emmited via bus)

`Generic envelope` (CloudEvents-like):
```
  {
    "id": "evt-123",
    "type": "<domain.event>",            // e.g., inventory.low_stock
    "source": "tea-svc",                 // or "chat-svc"
    "time": "2025-09-11T12:00:01Z",
    "specversion": "1.0",
    "data": { ... }                      // event-specific payload
  }
```
Examples:
```
  inventory.low_stock
    {
      "id": "evt-001",
      "type": "inventory.low_stock",
      "source": "tea-svc",
      "time": "2025-09-11T12:00:01Z",
      "specversion": "1.0",
      "data": {
        "item_id": "9b2f1b53-3f8a-4e5a-93d7-4a7a5b1f8f0e",
        "current_qty": 12,
        "threshold": 50
      }
    }
```
```
  inventory.restocked
    {
      "id": "evt-002",
      "type": "inventory.restocked",
      "source": "tea-svc",
      "time": "2025-09-11T11:00:00Z",
      "specversion": "1.0",
      "data": {
        "item_id": "9b2f1b53-3f8a-4e5a-93d7-4a7a5b1f8f0e",
        "batch_id": "b1",
        "qty": 200,
        "currency": "USD",
        "cost_total": 49.90,
        "expiry_date": "2025-12-31"
      }
    }
```


### 9. Communication Service

#### GET `/users/search?q={nickname}` — Fuzzy search by nickname
  Query: 
  - q
  - limit
  - cursor

  Response 200 JSON:

    {
      "profiles": [
        { "user_id":"u_1","nickname":"alice","avatar_url":"https://…","roles":["member"] }
      ],
      "next_cursor": null
    }

#### GET `/profiles/{user_id}` — Public profile preview
  Response 200 JSON:

    { "user_id":"u_1","nickname":"alice","avatar_url":"https://…","roles":["member"],"presence":"online" }
  Errors: 
  - 404 NOT FOUND

#### POST `/chats` — Create chat (dm/group/channel)
  Request JSON:

    {
      "type": "group",               // dm | group | channel
      "name": "kitchen-talk",
      "slug": null,                  // for channels only
      "is_private": true,
      "member_ids": ["u_1","u_2","u_3"]
    }
  Response 201 JSON:

    {
      "id":"c_123",
      "type":"group",
      "name":"kitchen-talk",
      "slug":null,
      "is_private":true,
      "created_by":"u_1",
      "created_at":"2025-09-11T10:20:00Z",
      "updated_at":"2025-09-11T10:20:00Z",
      "member_count":3,
      "settings": { "retention_days": 90, "post_policy":"any", "extra":{} }
    }
  Errors: 
  - 422 VALIDATION_ERROR

#### GET `/chats` — List my chats
  Query: 
  - type, 
  - member, 
  - q, 
  - limit, 
  - cursor

  Response 200 JSON:

    { "chats": [ { "id":"c_123","type":"group","name":"kitchen-talk","is_private":true, "member_count":3, "settings":{"retention_days":90,"post_policy":"any","extra":{}} } ], "next_cursor": null }

#### GET `/chats/{chat_id}` — Metadata + membership
  Response 200 JSON:

    {
      "id":"c_123","type":"group","name":"kitchen-talk","slug":null,"is_private":true,
      "created_by":"u_1","created_at":"2025-09-11T10:20:00Z","updated_at":"2025-09-11T10:25:00Z",
      "member_count":3,
      "settings": { "retention_days": 90, "post_policy":"any", "extra":{} }
    }
  Errors:
  - 404 NOT FOUND

#### PATCH `/chats/{chat_id}` — Rename / toggle privacy
  Request JSON:

    { "name": "kitchen", "is_private": false }

  Response 200 JSON: (chat object as above)
  Errors: 
  - 404 NOT FOUND
  - 422 VALIDATION ERROR

#### POST `/chats/{chat_id}/members` — Add member
  Request JSON:

    { "user_id": "u_99", "role": "member" }     // owner|moderator|member
  Response 201 JSON:

    { "id":"m_1","user_id":"u_99","role":"member","joined_at":"2025-09-11T10:30:00Z","left_at":null }
  Errors: 
  - 404 NOT_FOUND 
  - 409 CONFLICT
  - 422 VALIDATION_ERROR

#### DELETE `/chats/{chat_id}/members/{user_id}` — Remove member / leave
  Response 204 No Content\
  Errors: 
   - 404 NOT FOUND

#### POST `/chats/{chat_id}/messages` — Send message (async, event-driven)
  Headers: 
  - Idempotency-Key

  Request JSON:
  ```
    {
      "text": "tea's out, restock pls",
      "type": "normal",                       // normal | notice
      "attachments": [ { "url": "https://…/photo.jpg", "content_type":"image/jpeg", "size_bytes": 12345, "extra": {} } ],
      "metadata": { "mentions": ["u_1"], "client":"web" }
    }
```

  Response 202 JSON:

    {
      "operation_id": "op-abc",
      "status": "accepted",
      "poll": "/operations/op-abc"
    }

  Headers:
  ```
    Operation-Id: op-abc
    Location: /operations/op-abc
  ```
  Notes:
  ```
    The message will be persisted by a worker; clients poll `/operations/{id}` or receive a websocket event.
  ```
  Errors: 
  - 404 NOT FOUND
  - 422 VALIDATION ERROR

#### GET `/chats/{chat_id}/messages` — Paginate messages
  Query: 
  - before (datetime), 
  - after (datetime), 
  - limit, 
  - cursor\
  Response 200 JSON:
  ```
    {
      "messages": [
        {
          "id":"msg_1",
          "chat_id":"c_123",
          "type":"normal",
          "author_id":"u_2",
          "text":"tea's out, restock pls",
          "metadata":{"mentions":["u_1"],"client":"web"},
          "created_at":"2025-09-11T11:00:00Z",
          "edited_at":null,
          "deleted_at":null,
          "filtered":false,
          "filter_matches":[],
          "flagged_at":null,
          "attachments":[
            {"id":"att_1","url":"https://…/photo.jpg","content_type":"image/jpeg","size_bytes":12345,"extra":{}}
          ],
          "reactions":[
            {"id":"r_1","user_id":"u_1","emoji":"👍","created_at":"2025-09-11T11:01:00Z"}
          ]
        }
      ],
      "next_cursor": null
    }
  ```
#### DELETE `/chats/{chat_id}/messages/{msg_id}` — Moderator delete (soft)
  Response 204 No Content
  Errors: 
  - 404 NOT FOUND

#### GET `/moderation/filters` — Current banned words/phrases
  Response 200 JSON:

    { "phrases": ["badword", "regex:^foo.*$"], "version": 7 }

####  PUT `/moderation/filters` — Replace banned words/phrases (admin)
  Request JSON:

    { "phrases": ["badword", "regex:^foo.*$"], "version": 8 }
  Response 200 JSON:

    { "phrases": ["badword", "regex:^foo.*$"], "version": 8 }

#### POST `/moderation/filters/test` — Dry-run a message against filters
  Request JSON:

    { "text": "hello world" }
  Response 200 JSON:

    { "filtered": false, "matches": [] }

#### POST `/moderation/actions/ban` — Apply ban

  Request JSON:

    {
      "user_id": "u_99",
      "type": "ban",                  // ban | mute (for /mute use type= "mute" or omit)
      "scope": "chat",                // chat | global
      "chat_id": "c_123",
      "reason": "abuse",
      "until": "2025-09-12T10:00:00Z" // optional
    }

  Response 201 JSON:

    {
      "id":"s_1",
      "user_id":"u_99",
      "type":"ban",
      "scope":"chat",
      "chat_id":"c_123",
      "reason":"abuse",
      "applied_by":"u_mod",
      "applied_at":"2025-09-11T10:40:00Z",
      "until":"2025-09-12T10:00:00Z",
      "revoked_at": null,
      "revoked_by": null
    }

#### POST `/moderation/actions/mute` — Apply mute
  Request/Response: same schema as `/moderation/actions/ban` with `type="mute"`

#### GET `/moderation/sanctions` — List active sanctions
  Query: 
  - user_id (optional)

  Response 200 JSON:

    {
      "sanctions": [
        { "id":"s_1","user_id":"u_99","type":"ban","scope":"chat","chat_id":"c_123","reason":"abuse","applied_by":"u_mod","applied_at":"2025-09-11T10:40:00Z","until":"2025-09-12T10:00:00Z","revoked_at":null,"revoked_by":null }
      ]
    }

#### POST `/reports` — Report message/user
  Request JSON:

    { "reason": "spam", "message_id": "msg_1", "reported_user_id": "u_99", "evidence": ["https://…"] }
  Response 201 JSON:

    {
      "id":"rep_1",
      "reporter_id":"u_2",
      "message_id":"msg_1",
      "reported_user_id":"u_99",
      "reason":"spam",
      "evidence":["https://…"],
      "status":"open",
      "resolution_notes": null,
      "created_at":"2025-09-11T10:45:00Z",
      "updated_at":"2025-09-11T10:45:00Z"
    }

#### GET `/reports` — List & triage (admin)
  Query: status (open|triaged|resolved|rejected), limit, cursor
  Response 200 JSON:
    { "reports": [ { "id":"rep_1","...":"..." } ], "next_cursor": null }

#### POST `/notices` — Broadcast admin notices
  Request JSON:

    { "title":"Kitchen closed", "body":"Cleaning 14:00-15:00", "chat_ids":["c_123"], "roles":["member"] }
  Response 201 JSON:

    { "id":"n_1","title":"Kitchen closed","body":"Cleaning 14:00-15:00","created_by":"u_admin","chat_ids":["c_123"],"roles":["member"],"created_at":"2025-09-11T11:10:00Z" }

#### GET `/retention` — Read retention policy (per chat)
  Query: 
  - chat_id

  Response 200 JSON:

    { "chat_id":"c_123", "retention_days": 90, "post_policy": "any", "extra": {} }

#### PUT `/retention` — Update retention policy (per chat)
  Request JSON:

    { "chat_id":"c_123", "retention_days": 60, "post_policy": "mods", "extra": {} }
  Response 200 JSON:
  
    { "chat_id":"c_123", "retention_days": 60, "post_policy": "mods", "extra": {}, "updated_at":"2025-09-11T11:20:00Z" }

#### WS `/ws` — WebSocket for live events (messages, typing, read receipts)
  Client → Server frames (JSON examples):
  ```
    { "op": "subscribe", "chat_id": "c_123" }
    { "op": "typing", "chat_id": "c_123", "state": "on" }
    { "op": "read", "chat_id": "c_123", "message_id": "msg_1" }
  ```
  Server → Client frames (JSON examples):
  ```
    { "event": "chat.message.created", "data": { "chat_id": "c_123", "msg_id": "msg_1", "author_id":"u_2", "created_at":"2025-09-11T11:00:00Z" } }
    { "event": "chat.read.update", "data": { "chat_id":"c_123", "user_id":"u_1", "last_read_message_id":"msg_1", "last_read_at":"2025-09-11T11:02:00Z" } }
  ```

#### **Event Envelopes** (emmited via bus)

`Generic envelope` (CloudEvents-like):
```
  {
    "id": "evt-123",
    "type": "<domain.event>",            // e.g., inventory.low_stock
    "source": "tea-svc",                 // or "chat-svc"
    "time": "2025-09-11T12:00:01Z",
    "specversion": "1.0",
    "data": { ... }                      // event-specific payload
  }
```
Examples:
```
  chat.message.created
    {
      "id": "evt-101",
      "type": "chat.message.created",
      "source": "chat-svc",
      "time": "2025-09-11T11:00:00Z",
      "specversion": "1.0",
      "data": {
        "chat_id": "c_123",
        "msg_id": "msg_1",
        "author_id": "u_2",
        "created_at": "2025-09-11T11:00:00Z"
      }
    }
```
```
  chat.moderation.sanction.applied
    {
      "id": "evt-102",
      "type": "chat.moderation.sanction.applied",
      "source": "chat-svc",
      "time": "2025-09-11T10:40:00Z",
      "specversion": "1.0",
      "data": {
        "user_id": "u_99",
        "type": "ban",
        "scope": "chat",
        "chat_id": "c_123",
        "until": "2025-09-12T10:00:00Z",
        "applied_by": "u_mod"
      }
    }
```
