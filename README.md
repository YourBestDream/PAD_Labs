# FAFCab Microservices Architecture

Description of the architecture of a microservices-based system for the FAFCab, designed to support internal operations through modular, scalable services. The system uses an event-driven model with RabbitMQ as the message broker and an API Gateway for external access.

---

## Services Overview

| ID | Service Name            | Primary Function |
|----|-------------------------|------------------|
| 1  | User Management         | Manage user profiles, roles, and identity synchronization with Discord |
| 2  | Notification  | Centralized delivery of real-time alerts and notifications |
| 3  | Communication            | Enable public/private chats with moderation and censorship |
| 4  | Tea Management          | Centralized delivery of real-time alerts |
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
- **Responsibility**: Monitor tea, sugar, cups, paper, and markers consumption.
- **Dependencies**:
  - User Service: For identifying users who consume resources.
  - Notification Service: To send low-stock alerts.
- **Event Emitted**:
  - `stock_pings`: Triggered when stock levels fall below threshold → sent to Notification Service.

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
- **Responsibility**: Support public and private messaging with moderation.
- **Features**:
  - Censorship based on banned words.
  - Role-based access control.
  - Reporting and sanctioning (mute, ban).
- **Integrations**:
  - User Service: For user identification and role checks.
  - Notification Service: Deliver message notifications.
- **Events Emitted**:
  - `new_message`, `ban_applied`.
- **Events Received**:
  - `banned_words_list` from admin configuration.

### 10. Notification Service
- **Responsibility**: Centralized delivery of alerts and messages.
- **Functionality**:
  - Subscribes to events from all services.
  - Routes notifications to appropriate channels (Discord, email, etc.).
  - Uses RabbitMQ queues filtered by audience: ALL, Admins, Students, Teachers.
- **Events Received**:
  - From all services: `stock_pings`, `booking_confirmed`, `unknown_user`, `post_updated`, `donation_success`, `item_taken`, `new_message`, `ban`, `low_funds`.

---

