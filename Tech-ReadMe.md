# TRACE — Smart Mobility & Food Delivery Platform

## Overview

TRACE is a full-stack mobile platform that combines **cab booking** and **food ordering** into a single app, built around a unique concept: passengers riding in a cab can order food from restaurants along their route, and the cab picks it up mid-trip at a discounted delivery fee. The platform also features a **food resale system** where cancelled food orders are listed at 50% off for nearby users — reducing waste and creating a secondary marketplace.

### What the project actually does

A user opens the app, books a cab ride by selecting pickup/drop on a map, and gets a fare calculated server-side. During or after the ride, they can also order food for delivery. Payments go through Razorpay (currently test mode). Push notifications via Firebase keep the user updated on ride/order status. An admin panel allows managing drivers, rides, and restaurants.

### Architecture

```
┌─────────────────────┐          HTTPS/REST           ┌──────────────────────┐
│   Flutter Mobile App │  ◄──────────────────────────►  │   Node.js / Express  │
│   (frontend/)        │                                │   (backend/)         │
│                      │                                │                      │
│  • 23 screens        │     POST /api/auth/login       │  • 9 route files     │
│  • Razorpay SDK      │     POST /api/cabride/create   │  • JWT auth          │
│  • Firebase FCM      │     POST /api/payment/verify   │  • Razorpay server   │
│  • Riverpod state    │     GET  /api/food/restaurants  │  • FCM push notifs   │
│  • OpenStreetMap     │     POST /api/food/orders       │  • Order auto-sim    │
└─────────────────────┘                                └──────────┬───────────┘
                                                                  │
                                                                  │ Mongoose ODM
                                                                  ▼
                                                       ┌──────────────────────┐
                                                       │   MongoDB Atlas      │
                                                       │                      │
                                                       │  • users             │
                                                       │  • drivers           │
                                                       │  • cabrides          │
                                                       │  • foodorders        │
                                                       │  • restaurants       │
                                                       │  • menuitems         │
                                                       │  • menucategories    │
                                                       └──────────────────────┘
```

**Data flow**: Flutter app → HTTP requests with JWT Bearer token → Express routes → Mongoose models → MongoDB Atlas. Payments go through Razorpay's SDK (client-side checkout) with server-side signature verification. Push notifications flow from backend → Firebase Admin SDK → FCM → device.

### Current Status

| Feature | Status | Notes |
|---------|--------|-------|
| User signup/login (email + password) | ✅ Working | JWT-based, 7-day token expiry |
| Cab ride booking with map | ✅ Working | OpenStreetMap via flutter_map, Haversine distance |
| Server-side fare calculation | ✅ Working | Base + distance + time + food-stop components |
| Ride lifecycle (confirm → assign → start → complete) | ✅ Working | Full status machine with timestamps |
| Razorpay payment (cab rides) | ✅ Working | Test mode, HMAC signature verification |
| Razorpay payment (food orders) | ✅ Working | Separate flow from cab payments |
| Food ordering (browse → cart → checkout → track) | ✅ Working | 9 dedicated screens |
| Order auto-progression simulation | ✅ Working | Backend timer simulates placed→delivered lifecycle |
| Food resale system (50% off cancelled orders) | ✅ Working | Unique feature — browse/claim/pay flow complete |
| Push notifications (Firebase) | ✅ Working | Ride + payment events, foreground + background |
| Admin dashboard | ⚠️ Partial | Stats/driver/ride/user management works; admin auth uses any-user check instead of role-based |
| Driver management (backend) | ✅ Working | CRUD + status + assignment via admin routes |
| Driver app (frontend) | ❌ Missing | Backend routes exist, no Flutter driver UI |
| OTP pickup/delivery verification | ⚠️ Partial | OTPs generated and stored; driver-side verification routes exist but no driver app to call them |
| Checkout screen (food) | ⚠️ Stub | `checkout_screen.dart` is 1.4KB minimal placeholder |
| Real-time updates (WebSocket) | ❌ Missing | Order tracking uses polling |
| Email/phone verification on signup | ❌ Missing | User model has OTP fields but signup doesn't use them |
| Rate limiting | ❌ Missing | No protection against brute force |
| Unit/integration tests | ❌ Missing | No tests written |
| PDF receipt generation | ⚠️ Partial | Packages installed (`pdf`, `printing`), used in `ride_summary_screen.dart` |

### Dead code identified and handled

- **`models/_legacy/ride.js`**: Original ride model superseded by `CabRide.js`. Was never imported by any active route. Moved to `_legacy/`.
- **`routes/_legacy/ride.js`**: Legacy ride route using old model. Was NOT mounted in `server.js` (despite the file existing). Moved to `_legacy/`.
- **`controllers/adminController.js`**: Empty file (0 bytes). Removed entirely.
- **`frontend/lib/widgets/`**: Empty directory. Removed.
- **`Admin.js` model**: Defined but never imported or used anywhere — admin auth in `routes/admin.js` uses inline middleware that checks the User model instead.

---

## Project Structure

```
Trace/
├── frontend/                          # Flutter mobile app (Dart)
│   ├── lib/
│   │   ├── main.dart                  # Entry point, Firebase init, routing
│   │   ├── models/                    # Dart data classes
│   │   │   ├── food_order.dart
│   │   │   ├── menu_item.dart
│   │   │   └── restaurant.dart
│   │   ├── providers/
│   │   │   └── food_providers.dart    # Riverpod state management
│   │   ├── screens/
│   │   │   ├── login_screen.dart
│   │   │   ├── signup_screen.dart
│   │   │   ├── home_screen.dart       # Main dashboard
│   │   │   ├── map_screen.dart        # Cab booking (93KB, largest file)
│   │   │   ├── map_logic.dart         # Haversine + route calc helpers
│   │   │   ├── ride_summary_screen.dart # Post-ride + payment + PDF
│   │   │   ├── profile_screen.dart
│   │   │   ├── admin_login_screen.dart
│   │   │   ├── admin_dashboard_screen.dart
│   │   │   ├── driver_simulation.dart # Dev tool: simulates driver status updates
│   │   │   └── food/                  # Food ordering flow (9 screens)
│   │   │       ├── food_home_screen.dart
│   │   │       ├── restaurant_detail_screen.dart
│   │   │       ├── cart_screen.dart
│   │   │       ├── checkout_screen.dart     # ⚠️ Stub
│   │   │       ├── address_selection_screen.dart
│   │   │       ├── order_tracking_screen.dart
│   │   │       ├── food_orders_screen.dart
│   │   │       ├── order_history_screen.dart
│   │   │       └── resale_orders_screen.dart
│   │   └── services/
│   │       ├── api_service.dart        # Core HTTP client (auth, cab, payment)
│   │       ├── food_api_service.dart   # Food-specific HTTP client
│   │       ├── payment_service.dart    # Razorpay SDK wrapper
│   │       ├── notification_service.dart # Firebase FCM setup
│   │       ├── cart_manager.dart       # Persistent cart state
│   │       └── user_session.dart       # SharedPreferences token mgmt
│   ├── pubspec.yaml
│   ├── android/, ios/, web/, etc.
│   └── assets/
│
├── backend/                           # Node.js + Express API
│   ├── server.js                      # Entry point: Express + Mongoose + route mounting
│   ├── package.json
│   ├── .env.example                   # Template (real .env is gitignored)
│   ├── render.yaml                    # Render.com deployment config
│   ├── config/
│   │   ├── firebase/README.md         # Firebase service account setup guide
│   │   └── database/README.md         # MongoDB Atlas setup guide
│   ├── models/mongodb/                # Mongoose schemas
│   │   ├── User.js
│   │   ├── Driver.js
│   │   ├── CabRide.js                 # 417 lines — most complex model
│   │   ├── FoodOrder.js
│   │   ├── Restaurant.js
│   │   ├── MenuItem.js
│   │   ├── MenuCategory.js
│   │   └── Admin.js                   # Defined but unused
│   ├── models/_legacy/
│   │   └── ride.js                    # Old ride model (superseded by CabRide)
│   ├── routes/
│   │   ├── auth.js                    # POST /signup, /login
│   │   ├── cabride.js                 # Ride CRUD + status machine
│   │   ├── payment.js                 # Razorpay order + verify (cab)
│   │   ├── food.js                    # Restaurants, orders, food payment, resale
│   │   ├── user.js                    # Profile, stats, FCM token
│   │   ├── admin.js                   # Dashboard stats, driver/ride/user CRUD
│   │   ├── adminFood.js              # Restaurant/menu/order admin CRUD
│   │   ├── driverFood.js             # Driver-side order management + OTP verify
│   │   └── _legacy/ride.js
│   ├── middleware/
│   │   ├── auth.js                    # JWT verification → req.user
│   │   ├── adminAuthMiddleware.js     # Role-based admin check
│   │   └── driverAuthMiddleware.js    # Role-based driver check
│   ├── services/
│   │   ├── firebase/
│   │   │   └── notificationService.js # Firebase Admin SDK push notifications
│   │   └── orderProgressionService.js # Auto-progresses food order statuses
│   └── scripts/
│       └── seedRestaurants.js         # Seeds sample restaurant/menu data
│
├── Tech-ReadMe.md                     # ← This file
└── .gitignore
```

---

## Interview Deep-Dive Reference

---

### 1. Authentication System

**What it does**: Email/password registration and login with JWT tokens.

**Why it exists**: Stateless auth was chosen over sessions because the client is a mobile app — no cookie jar, and the backend may scale horizontally across Render instances without shared session stores.

**Key functions**:

- **`POST /api/auth/signup`** (`backend/routes/auth.js`): Takes `{name, email, phone, password}`. Checks for duplicate email via `User.findOne()`. If unique, calls `User.create()` which triggers a Mongoose `pre('save')` hook that hashes the password with `bcrypt` at cost factor 12. Returns `{success: true}` — does NOT return a token on signup (user must log in separately).

- **`POST /api/auth/login`** (`backend/routes/auth.js`): Takes `{email, password}`. Fetches user with `.select("+password")` because the password field has `select: false` in the schema (never returned by default). Compares via `bcrypt.compare()`. On success, signs a JWT with `{id: user._id}` and 7-day expiry. Returns token + user profile data (without password).

- **`authMiddleware`** (`backend/middleware/auth.js`): Extracts Bearer token from `Authorization` header, verifies with `jwt.verify()`, attaches `req.user = decoded` and `req.userId = decoded.id`. Every protected route uses this.

**Non-obvious choices**:
- Password field uses `select: false` in Mongoose schema rather than manually excluding it in every query. This is a defense-in-depth pattern — even if a developer forgets to `.select('-password')`, the field won't leak.
- `bcrypt` cost factor 12 (4096 iterations) was chosen over the default 10 — slightly more secure at ~250ms hash time, still acceptable for mobile where login is infrequent.
- JWT expiry is 7 days, which is long. The tradeoff: users don't have to re-login often (better UX for a ride-hailing app), but compromised tokens have a longer window. There's no refresh token mechanism.

**Tricky parts**:
- The signup response returns `res.json({success: false})` with status 200 for duplicate emails instead of 409. This is intentional — the Flutter client checks `response['success']` rather than HTTP status codes for all API calls. Inconsistent with REST conventions but consistent internally.

---

### 2. Cab Ride System

**What it does**: Full ride lifecycle from booking through completion and payment.

**Why it exists**: This is the core product — a cab booking platform.

**Key functions**:

- **`POST /api/cabride/create`** (`backend/routes/cabride.js`): Takes pickup/drop coordinates, distance, ETA, food stops. The critical design decision: **fare is calculated server-side** via `calculateFare()`, NOT trusted from the client. The client sends `distanceKm` and `etaMin` (computed via Haversine on the Flutter side), and the backend independently computes `baseFare + (distanceKm × ₹12) + (etaMin × ₹2) + (foodStops × ₹15)`. Ride is created with status `"confirmed"`.

- **`PATCH /api/cabride/update-status`** (`backend/routes/cabride.js`): Advances ride through the state machine: `confirmed → assigned → arriving → atPickup → started → completed`. Each transition sets timestamps (`acceptedAt`, `startedAt`, `completedAt`). Sends a push notification per status change with context-specific messages.

- **`POST /api/cabride/cancel`** (`backend/routes/cabride.js`): Two hard rules enforced: (1) cannot cancel if status is `started`, `completed`, or `paid`; (2) cannot cancel after 3 minutes from `confirmedAt`. The 3-minute window is calculated as `(Date.now() - confirmedAt) / 60000 > 3`.

- **`CabRide` model** (`backend/models/mongodb/CabRide.js`, 417 lines): The most complex schema. Key design decisions:
  - **Dual driver reference**: Both a `driverId` (ObjectId ref for `populate()`) AND an embedded `driver` subdocument snapshot (name, phone, vehicle, rating). Why: the ref enables joins for admin queries, while the snapshot avoids N+1 queries for the user's ride history screen — you don't need to populate the Driver collection just to show "Rajesh, Toyota Camry" on past rides.
  - **Virtuals**: `canCancel` (computed from status + time window), `isPaymentPending` (completed but not paid), `rideDurationMin` (diff between startedAt and completedAt). These are computed on access, not stored.
  - **Instance methods**: `ride.cancel()`, `ride.assignDriver()`, `ride.startTrip()`, `ride.completeTrip()`, `ride.markPaid()` — encapsulate status transitions with validation. Example: `startTrip()` throws if status isn't in `['assigned', 'arriving', 'atPickup']`.
  - **Static methods**: `CabRide.getActiveRide(userId)` returns the user's non-terminal ride (used to resume after app restart); `CabRide.calculateEarnings(filter)` uses MongoDB aggregation pipeline.
  - **Pre-save hook for fare validation**: Before saving, the hook checks if `totalFare` matches the sum of components within ₹1 tolerance. This catches any accidental corruption.

- **`calculateFare()`** (`backend/routes/cabride.js`): Pure function. `BASE_FARE=50, PER_KM=12, PER_MIN=2, PER_STOP=15`. Returns an object with each component broken out — this breakdown is shown to the user in the ride summary screen.

**Frontend side**:

- **`map_screen.dart`** (93KB — largest file): Handles the entire ride booking flow. Uses `flutter_map` with OpenStreetMap tiles (chosen over Google Maps to avoid API key costs and billing). The map shows pickup/drop markers, draws a route polyline, and calculates distance via the Haversine formula in `map_logic.dart`.

- **`map_logic.dart`**: Contains `calculateHaversineDistance(lat1, lon1, lat2, lon2)` — standard great-circle distance. This is sent to the backend, which uses it for fare calculation. The backend doesn't recalculate distance — it trusts the client value. This is a known shortcoming (a malicious client could send a shorter distance to get a lower fare).

- **`driver_simulation.dart`**: A dev/testing screen that manually advances ride status via API calls. Since there's no driver app, this lets testers simulate the driver accepting and completing a ride.

**End-to-end ride flow** (traced through actual code):

```
1. User taps "Confirm Ride" on map_screen.dart
2. → ApiService.createRide() sends POST /api/cabride/create with coordinates
3. → Backend calculateFare() computes pricing server-side
4. → CabRide.create() saves to MongoDB with status="confirmed"
5. → Backend sends FCM notification "Ride Confirmed!"
6. → Response returns ride object to Flutter
7. → Flutter saves ride ID to SharedPreferences ('current_ride_id')
8. → User (or driver_simulation) calls updateRideStatus() to advance status
9. → Each status change triggers a push notification
10. → On status="completed", ride_summary_screen.dart shows fare + "Pay Now"
11. → User taps Pay → ApiService.createPaymentOrder() → backend creates Razorpay order
12. → PaymentService.openRideCheckout() opens Razorpay SDK overlay
13. → User pays → Razorpay callback returns paymentId + signature
14. → ApiService.verifyPayment() → backend HMAC-verifies → updates ride.isPaid=true
15. → Backend sends FCM notification "Payment Successful!"
```

---

### 3. Payment Integration (Razorpay)

**What it does**: Handles payment creation, checkout, and cryptographic verification for both cab rides and food orders.

**Why Razorpay**: Indian payment gateway that supports UPI, cards, wallets, and net banking — all essential for an Indian market ride-hailing app. The `razorpay_flutter` package provides a native checkout UI that handles PCI compliance.

**Key functions**:

- **`POST /api/payment/create-order`** (`backend/routes/payment.js`): Takes `rideId`. Finds the ride, validates it belongs to `req.user.id` and has status `"completed"`. Creates a Razorpay order via `razorpay.orders.create()` with amount in paise (× 100). The receipt ID is truncated to 40 chars (`r_${last8ofRideId}_${base36timestamp}`) because Razorpay has a 40-char receipt limit.

- **`POST /api/payment/verify`** (`backend/routes/payment.js`): Takes `{paymentId, orderId, signature, rideId}`. Reconstructs the expected signature: `HMAC-SHA256(orderId + "|" + paymentId, RAZORPAY_KEY_SECRET)`. Compares with the client-provided signature. If valid, updates ride with payment details and sets `isPaid=true, status="paid"`. This is **idempotent** — if the same paymentId is submitted twice, it returns success without re-processing.

- **`PaymentService.openCheckout()`** (`frontend/lib/services/payment_service.dart`): Generic Razorpay checkout wrapper. Creates a `Razorpay()` instance, registers success/error/wallet listeners, opens checkout with options, and returns a `Future<Map>` via a `Completer`. Has a 2-minute timeout to handle cases where the user abandons the checkout without explicitly cancelling. Two convenience wrappers: `openRideCheckout()` and `openResaleCheckout()`.

**Non-obvious choices**:
- The signature verification uses `crypto.createHmac('sha256', SECRET)` rather than relying on Razorpay's webhook. Why: webhooks require a publicly accessible endpoint and add delivery complexity. Direct verification in the payment flow is simpler and synchronous.
- The Flutter `PaymentService` uses a `Completer<Map>` pattern instead of callbacks. This lets calling code `await` the result rather than nesting callbacks — cleaner for the ride summary screen's payment flow.
- The food payment flow (`routes/food.js`) instantiates `new Razorpay()` inside each request handler rather than sharing a module-level instance. This avoids any potential state leakage between requests but does add per-request instantiation overhead (negligible for current scale).

**Tricky parts**:
- Razorpay's `receipt` field has a 40-character limit. The code uses `rideId.toString().slice(-8)` + `Date.now().toString(36).slice(-6)` to construct a unique but compact receipt. The base-36 encoding of the timestamp saves characters.
- The `Completer`-based approach in Flutter has an edge case: if the Razorpay SDK crashes or the Activity is destroyed on Android, the `Completer` might never complete. The 2-minute timeout handles this, returning `{success: false, message: 'Payment timeout'}`.

---

### 4. Food Ordering System

**What it does**: Full restaurant discovery, menu browsing, cart management, order placement, payment, order tracking, and a food resale marketplace.

**Why it exists**: The secondary revenue stream and the differentiating feature — food delivery integrated with cab rides.

**Key backend functions** (`backend/routes/food.js`, 877 lines — second largest file):

- **`GET /api/food/restaurants`**: Supports query params: `lat, lon, cuisine, vegOnly, search, sortBy`. Fetches active restaurants, calculates distance to each using Haversine, filters out those beyond `deliveryRadiusKm`, optionally sorts by rating or distance. No authentication required (public endpoint for browsing).

- **`GET /api/food/restaurants/:id`**: Returns restaurant details WITH full menu. The menu is structured as: fetch all `MenuCategory` docs for the restaurant (sorted by `displayOrder`), then for each category, fetch all available `MenuItem` docs. Returns a nested `{restaurant: {..., menu: [{category, items: [...]}]}}` structure.

- **`POST /api/food/orders/price-preview`**: Calculates pricing before order placement. Formula: `itemsTotal + platformFee(₹5) + deliveryFee + GST(5%) - discounts`. The `deliveryFee` depends on `deliveryMode`: `dedicated_delivery` charges full fee (`₹20 base + ₹8/km`), while `detour_cab` mode charges 50% (since the cab is already going that way). This is the core of the cab+food integration concept.

- **`POST /api/food/orders`**: Creates a food order. Validates each item exists and is available. Recalculates pricing server-side (doesn't trust client amounts). Generates two 4-digit OTPs: one for restaurant pickup, one for customer delivery. Starts the `orderProgressionService` auto-progression timer for this order.

- **`POST /api/food/orders/:id/cancel`**: Cancellation is only allowed in `placed` or `accepted` states. Once `preparing` starts, cancellation is blocked (the restaurant has already started cooking). This is a deliberate business rule to protect restaurants from wasted food.

**Order Auto-Progression** (`backend/services/orderProgressionService.js`):

This is a simulation system since there's no real restaurant or driver app. When an order is created, it starts a chain of `setTimeout()` calls that advance the status:
```
placed → (10s) → accepted → (15s) → preparing → (2min) → ready_for_pickup → (30s) → picked_up → (10s) → on_the_way → (3min) → delivered
```

The service uses a `Map()` to track active progressions. Each step re-reads the order from DB to check if it's been cancelled (preventing progression of cancelled orders). On server restart, `startAllPendingOrders()` finds all non-terminal orders and resumes their progression.

**Non-obvious choices**:
- `setTimeout()` chains rather than a job queue (Bull/Agenda). Why: simplicity for an MVP. Downside: if the server restarts mid-chain, the exact delay position is lost (the restart handler just re-starts from current status). A proper job queue would persist the scheduled time.
- `detour_cab` delivery mode charges 50% delivery fee. This is the economic incentive for the "order food during your cab ride" feature — the delivery is cheaper because the cab is already making the trip.
- The OTP system generates codes but the verification only works through `driverFood.js` routes, which require a driver JWT with `role: "driver"`. Since there's no driver login flow, OTP verification is effectively dead code in production.

**Food Resale System** (`backend/routes/food.js`, resale section):

- **`GET /api/food/resell/nearby`**: Finds cancelled orders marked `isResellable: true, resellStatus: 'listed'` within a radius. Auto-expires listings older than 45 minutes. Returns distance to each order.
- **`POST /api/food/resell/:orderId/claim`**: Claims a resale order for the current user. Updates delivery location.
- **`POST /api/food/resell/:orderId/verify-payment`**: Razorpay payment at 50% of original price.

**Frontend side**:

- **`FoodApiService`** (`frontend/lib/services/food_api_service.dart`, 440 lines): Dedicated HTTP client for food endpoints. Notable: the `getPricePreview()` method does extensive normalization of item data — it handles multiple possible key names for the same field (`menuItemId` vs `itemId` vs `_id` vs `id`, `addOns` vs `addons` vs `selectedAddOns`). This defensive coding suggests the cart data structure evolved over time and the API service had to handle legacy formats.

- **`CartManager`** (`frontend/lib/services/cart_manager.dart`): Singleton that persists cart state to SharedPreferences. Handles add/remove/quantity updates. Cart is scoped to a single restaurant (adding items from a different restaurant clears the cart — standard food delivery app behavior).

- **`food_providers.dart`** (`frontend/lib/providers/food_providers.dart`): Riverpod providers for restaurant list, selected restaurant, and order state. Uses `FutureProvider` for async data fetching.

---

### 5. Database Design (MongoDB / Mongoose)

**Why MongoDB**: Document model fits the nested data naturally (a ride has embedded pricing, pickup/drop objects, driver snapshot). No complex joins needed for the primary user flows. MongoDB Atlas provides managed hosting with free tier for MVPs.

**Schema design decisions**:

- **`CabRide` uses embedded pricing object** rather than a separate `Pricing` collection. Why: pricing is always read with the ride and never queried independently. Embedding avoids a join and guarantees atomic updates.

- **`CabRide` has both `driverId` (ref) and `driver` (embedded snapshot)**. This is the classic "reference vs embed" MongoDB tradeoff resolved by doing both. The ref supports admin queries that need to join driver data. The embed supports fast reads for the user's ride history (no populate needed). The snapshot is set once when the driver is assigned and never updated — if the driver changes their name later, old ride records keep the historical name. This is actually correct behavior for a ride receipt.

- **`FoodOrder.amounts` embeds the full price breakdown** (`itemsTotal, platformFee, deliveryFee, distanceFee, discounts, gstAmount, finalPayableAmount`). This captures the pricing at order time — even if fee structures change later, historical orders retain their original pricing.

- **Indexes**: The models define compound indexes optimized for the actual query patterns:
  - `CabRide`: `{userId, createdAt}` (ride history), `{status, confirmedAt}` (active rides), `{isPaid, completedAt}` (payment queries), `{driverId, status}` (admin/driver queries)
  - `FoodOrder`: `{userId, status}`, `{restaurantId, status}`, `{isResellable, resellStatus}` (resale marketplace queries)
  - `MenuItem`: text index on `{name, description}` for full-text search

- **`User.password` has `select: false`**: This Mongoose feature excludes the field from all queries by default. Login explicitly uses `.select("+password")` to include it. This prevents accidental password leaks in any API response.

---

### 6. Push Notifications (Firebase Cloud Messaging)

**What it does**: Sends real-time push notifications for ride status changes, payment confirmations, and order updates.

**Backend** (`backend/services/firebase/notificationService.js`):

The Firebase Admin SDK initializes with a **three-method fallback**:
1. `FIREBASE_SERVICE_ACCOUNT` env var (full JSON — used on Render)
2. Split env vars (`FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY`)
3. Local `firebase-credentials.json` file (dev only)

If all three fail, notifications are silently skipped (non-blocking). The `sendNotification()` function accepts `(token, title, body, data)` and constructs a message with platform-specific config:
- Android: `priority: "high"`, custom channel `"trace_rides"`
- iOS: `sound: "default"`, badge count

**Frontend** (`frontend/lib/services/notification_service.dart`):

Requests notification permission on first launch. Gets FCM token and sends it to backend via `POST /api/user/fcm-token`. Listens for token refresh events. Handles three message scenarios:
1. **Foreground**: `FirebaseMessaging.onMessage` — logged but no in-app banner (TODO: integrate `flutter_local_notifications`)
2. **Background tap**: `FirebaseMessaging.onMessageOpenedApp` — handler exists but navigation is not implemented
3. **Terminated tap**: `_messaging.getInitialMessage()` — same as above

**Non-obvious choices**:
- The fallback initialization chain means the server always starts, even without Firebase configured. This is intentional — notifications are a nice-to-have, not a blocker for core functionality.
- FCM token is stored on the User document (`user.fcmToken`). This assumes one device per user. Multi-device support would require a separate `devices` collection.

---

### 7. Admin System

**What it does**: Dashboard with stats, driver CRUD, ride management, user listing, and food order/restaurant management.

**Backend** (`backend/routes/admin.js`, `adminFood.js`):

- **`GET /api/admin/stats`**: Returns aggregate counts (total drivers, online drivers, total users, rides, completed rides, active rides) and total earnings via MongoDB `$aggregate` pipeline.
- **Driver CRUD**: Create (with bcrypt password hashing), list (with pagination + filters), update status (approve/block), delete.
- **Ride management**: List all rides (with user/driver populate), manually assign driver to ride.
- **Food admin** (`adminFood.js`): Full CRUD for restaurants, menu categories, and menu items. Order listing with status update capability.

**Critical issue with admin auth**: The `adminAuth` middleware in `routes/admin.js` checks if the user exists in the User collection — but doesn't verify any admin role. Any authenticated user can access admin endpoints. The separate `adminAuthMiddleware.js` file properly checks `decoded.role !== "admin"`, but it's NOT used by the admin routes (they use the inline `adminAuth` function instead). This is a security gap.

**Frontend** (`frontend/lib/screens/admin_login_screen.dart`, `admin_dashboard_screen.dart`):

The admin login screen sends credentials to a different endpoint and the dashboard shows basic stats. These screens are accessible from the app but the admin auth flow is inconsistent with the backend's actual middleware.

---

### 8. Frontend Architecture

**State Management**: Riverpod (`flutter_riverpod`). Used primarily for food ordering state. Cab ride state is managed via `SharedPreferences` (storing `current_ride_id`) and local screen state. This hybrid approach works but means ride state isn't reactive — the app checks for active rides on startup rather than streaming updates.

**Navigation**: Named routes defined in `main.dart` (`/login`, `/signup`, `/home`, `/profile`). Food and ride screens use `MaterialPageRoute` push navigation. A global `NavigatorKey` exists for potential deep-link navigation from notifications (not fully implemented).

**Session Management** (`user_session.dart`): Simple wrapper around SharedPreferences. Stores JWT token, user ID, and name. The `SplashScreen` checks for a stored token on launch and routes to either `LoginScreen` or `HomeScreen`.

**Theming**: Material 3 dark theme with custom colors (`primary: #00D9FF`, `secondary: #6C63FF`, `surface: #1A3A3C`, `scaffold: #0C2C2E`). Uses `fontFamily: "Sans"` (system sans-serif).

**Key dependency choices**:
- **`flutter_map` over Google Maps**: No API key required, no billing. Uses OpenStreetMap tiles. Tradeoff: less polished UI, no turn-by-turn navigation, no Places API for address autocomplete.
- **`geolocator` for GPS**: Cross-platform location access. Used to get user's current position for pickup and for restaurant distance calculations.
- **`cached_network_image` + `shimmer`**: Restaurant/food images load with shimmer skeleton placeholders, then cache to disk. Prevents re-downloading on scroll.
- **`pdf` + `printing`**: Used in `ride_summary_screen.dart` to generate PDF invoices/receipts on-device.
- **`intl`**: Date/currency formatting for Indian locale (₹ symbol, date formats).

---

### 9. Deployment

**Backend**: Deployed on Render.com (free tier web service). `render.yaml` specifies Node 20, `npm install` build step, `npm start` start command. Environment variables are set in Render dashboard (not in the YAML).

**Frontend**: Built via `flutter build apk` (Android) or `flutter build ios`. Not deployed to app stores — development/testing builds only.

**Backend URL**: `https://trace-payment-server.onrender.com` — hardcoded in both `api_service.dart` and `food_api_service.dart`. There's no environment-based URL switching (dev vs prod).

---

### 10. Known Limitations & Future Work

1. **No driver app**: Backend driver routes exist (`driverFood.js` with OTP verification, `driverAuthMiddleware.js`), but there's no Flutter driver UI. The `driver_simulation.dart` screen is a workaround.

2. **No real-time updates**: Order tracking uses manual refresh / polling. WebSocket or Server-Sent Events would enable live status updates.

3. **Admin auth is broken**: Any authenticated user can access admin routes. The `adminAuthMiddleware.js` exists but isn't wired into the admin routes.

4. **No input validation library**: Routes rely solely on Mongoose schema validation. A library like Joi or express-validator would catch malformed requests earlier with better error messages.

5. **Hardcoded backend URL**: Both API service files hardcode the Render URL. Should use a config/env approach for dev/staging/prod.

6. **No rate limiting**: The Express server has no `express-rate-limit` or similar. Login endpoint is vulnerable to credential stuffing.

7. **Client-trusted distance**: The cab fare is computed server-side, but the `distanceKm` input comes from the client's Haversine calculation. A determined user could send a shorter distance. Fix: server-side distance calculation using a routing API.

8. **Notification tap navigation**: FCM handlers exist but `_handleNotificationTap()` doesn't actually navigate to the relevant screen — it only logs the data.

9. **`checkout_screen.dart` is a stub**: Only 1.4KB. The actual food checkout/payment happens in `cart_screen.dart` instead.

10. **No tests**: Zero unit tests, integration tests, or E2E tests across both frontend and backend.
