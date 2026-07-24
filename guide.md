# LoadR Beginner Guide

This is the plain-English guide for this project. It explains what the app does, what each service does, which environment variables the current backend actually reads, how the API works, and how GitHub/Railway fit in.

## What This App Does

LoadR is a load booking app.

Simple story:

1. A customer wants to move goods from one place to another.
2. The customer chooses pickup, drop, and vehicle type.
3. The backend calculates route distance and price.
4. The customer creates a job.
5. Drivers see open jobs.
6. One driver accepts the job.
7. The job becomes an active trip.
8. The app tracks trip status, driver location, documents, notifications, and driver earnings.

## Big Picture

```text
Flutter app -> FastAPI backend -> Supabase database/storage
                         |
                         -> Firebase Auth
                         -> Geoapify maps/routes
                         -> Resend or SMTP email
                         -> Railway hosting
                         -> GitHub code storage
```

Think of it like a restaurant:

- Flutter is the menu and table where users tap buttons.
- FastAPI is the waiter who receives requests.
- Supabase is the kitchen notebook where orders are stored.
- Firebase checks who the customer/driver is.
- Geoapify gives map directions.
- Resend/SMTP sends OTP emails.
- Railway keeps the waiter/server online.
- GitHub keeps the project code safe online.

## Main Folders

```text
lib/                         Flutter app code
lib/main.dart                App starts here
lib/services/api_service.dart All Flutter-to-backend API calls
lib/screens/                 App screens
lib/widgets/                 Reusable UI widgets
lib/models/                  Data models

backend/                     FastAPI backend
backend/main.py              Backend starts here
backend/config.py            Reads env variables
backend/firebase_config.py   Firebase setup
backend/supabase_config.py   Supabase setup
backend/routes/              API endpoints
backend/requirements.txt     Python dependencies

assets/                      Images and vehicle assets
android/, ios/, web/         Flutter platform files
```

## Flutter Dependencies

From `pubspec.yaml`:

| Package | Why it exists |
|---|---|
| `pinput` | OTP boxes |
| `google_fonts` | App font |
| `http` | Calls the backend API |
| `shared_preferences` | Stores simple local app state |
| `flutter_secure_storage` | Stores auth token more safely |
| `flutter_map` | Shows maps |
| `latlong2` | Latitude/longitude helpers |
| `image_picker` | Pick driver document images/files |
| `geolocator` | Get device location |
| `flutter_lints` | Code quality rules |

## Backend Dependencies

From `backend/requirements.txt`:

| Package | Why it exists |
|---|---|
| `fastapi` | Builds the API |
| `uvicorn` | Runs the API server |
| `firebase-admin` | Firebase Auth admin access |
| `python-dotenv` | Reads local `.env` file |
| `pydantic` | Validates request data |
| `pydantic-settings` | Loads env variables into settings |
| `python-multipart` | Handles document uploads |
| `supabase` | Talks to Supabase database/storage |

## Current Project Environment Variables

These match the env variables this project is using now.

### Firebase

Use this locally:

```env
FIREBASE_CREDENTIALS_PATH=./firebase-credentials.json
```

Use this on Railway:

```env
FIREBASE_CREDENTIALS_JSON={"type":"service_account",...}
```

Other Firebase vars:

```env
FIREBASE_DATABASE_URL=
```

Note:

- `FIREBASE_CREDENTIALS_PATH` means "read credentials from a file".
- `FIREBASE_CREDENTIALS_JSON` means "read credentials directly from an env variable"; the backend accepts either a JSON string or Railway's parsed JSON object.
- Railway should use `FIREBASE_CREDENTIALS_JSON` because secret files are awkward there.
- Do not commit `firebase-credentials.json`.

### Supabase

```env
SUPABASE_URL=
SUPABASE_SERVICE_ROLE_KEY=
SUPABASE_STORAGE_BUCKET=driver-documents
```

Important:

- `SUPABASE_SERVICE_ROLE_KEY` is secret.
- Only the backend should have it.
- Never put it in Flutter.

### Geoapify

```env
GEOAPIFY_API_KEY=
```

Used for:

- Place autocomplete.
- Reverse geocoding.
- Route calculation.
- Map tiles.

### Email OTP

```env
SMTP_HOST=
SMTP_PORT=587
SMTP_USERNAME=
SMTP_PASSWORD=
SMTP_FROM_EMAIL=
SMTP_USE_TLS=true
```

### Backend Runtime

Local:

```env
API_HOST=0.0.0.0
API_PORT=8000
ALLOW_CUSTOM_TOKEN_AUTH=true
SEED_FIREBASE_DATA=false
```

Railway:

```env
ALLOW_CUSTOM_TOKEN_AUTH=false
SEED_FIREBASE_DATA=false
SMTP_HOST=
SMTP_PORT=587
SMTP_USERNAME=
SMTP_PASSWORD=
SMTP_FROM_EMAIL=
SMTP_USE_TLS=true
```

Railway provides its own `PORT`. Your start command should use `$PORT`, so you usually do not need to set `API_PORT` on Railway.

## Why `ALLOW_CUSTOM_TOKEN_AUTH` Is Different

Local:

```env
ALLOW_CUSTOM_TOKEN_AUTH=true
```

This helps you test when Firebase/email is not perfect yet. The backend can accept demo/dev tokens.

Railway/public:

```env
ALLOW_CUSTOM_TOKEN_AUTH=false
```

This is safer. A public backend should only accept real Firebase-verified tokens.

If login breaks after setting it to `false`, it means the app still depends on the dev token fallback and real Firebase ID-token login needs more work.

## API Base URL In Flutter

Flutter reads the API URL from:

```text
API_BASE_URL
```

This is not a Railway backend env. It is passed when building Flutter:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://your-railway-domain.up.railway.app/api
```

For debug:

- Android emulator uses `http://10.0.2.2:8000/api`.
- Other debug platforms use `http://localhost:8000/api`.

## Backend Routes

Base URL:

```text
/api
```

Health:

```text
GET /health
```

Docs:

```text
GET /docs
```

### Auth

```text
POST /api/auth/signin
POST /api/auth/verify-otp
POST /api/auth/refresh-token
```

Flow:

1. App sends email/phone to `/signin`.
2. Backend creates OTP.
3. Backend sends OTP by Resend/SMTP.
4. App sends OTP to `/verify-otp`.
5. Backend returns `uid` and `token`.
6. App stores token.

### Users

```text
GET   /api/users/{uid}
PATCH /api/users/{uid}/role
PATCH /api/users/{uid}/profile
GET   /api/users/{uid}/onboarding
```

Used for:

- User profile.
- Role selection.
- Customer/driver onboarding.

### Drivers

```text
GET  /api/drivers/{uid}
PUT  /api/drivers/{uid}
POST /api/drivers/{uid}/location
```

Used for:

- Driver profile.
- Vehicle number.
- Driver location.

### Vehicles

```text
GET  /api/vehicles/
GET  /api/vehicles/{uid}
POST /api/vehicles/{uid}/assign?vehicle_number=Tata%20Ace
```

The code name says `vehicle_number`, but the current app stores vehicle type names like `Tata Ace`.

### Preferences

```text
GET /api/preferences/{uid}
PUT /api/preferences/{uid}
```

Example body:

```json
{
  "preferred_states": ["Kerala"],
  "preferred_vehicle_type": "Tata Ace"
}
```

### Documents

```text
POST  /api/documents/upload?uid={uid}&doc_type=license
GET   /api/documents/{uid}
PATCH /api/documents/{uid}/verify/{doc_id}?status_update=verified
```

Uploads go to Supabase Storage bucket:

```text
driver-documents
```

### Places And Maps

```text
GET /api/places/autocomplete?query=Kochi
GET /api/places/reverse?latitude=8.5&longitude=76.9
GET /api/map/geoapify/osm-bright-smooth/{z}/{x}/{y}.png
GET /api/map/geoapify/osm-bright-smooth/{z}/{x}/{y}@2x.png
```

The backend calls Geoapify so the app does not expose the Geoapify key.

### Quotes

```text
POST /api/quotes/estimate
```

Used to calculate:

- Distance.
- Route points.
- Vehicle prices.
- Suggested vehicle type.

### Jobs

```text
GET   /api/jobs/
POST  /api/jobs/
GET   /api/jobs/driver/{uid}/active
GET   /api/jobs/customer/{uid}/active
GET   /api/jobs/customer/{uid}/active/stream
GET   /api/jobs/{job_id}
PATCH /api/jobs/{job_id}/cancel
POST  /api/jobs/{job_id}/accept/{uid}
```

Jobs are customer load requests.

Important statuses:

```text
open
assigned
accepted
arriving
in_progress
completed
cancelled
```

### Trips

```text
POST  /api/trips/?uid={driver_uid}
GET   /api/trips/{uid}
GET   /api/trips/trip/{trip_id}
PATCH /api/trips/trip/{trip_id}/status?status=completed
```

Normal app flow:

```text
driver accepts job -> backend creates trip
```

### Location

```text
POST /api/location/update?uid={uid}
GET  /api/location/nearby?latitude=8.5&longitude=76.9&radius_km=25&limit=12
GET  /api/location/{uid}
```

Used for:

- Driver online/offline.
- Driver current location.
- Nearby driver markers.
- Auto-marking `arriving` when driver is near pickup.

### Notifications

```text
GET   /api/notifications/{uid}
POST  /api/notifications/{uid}
PATCH /api/notifications/{uid}/{notification_id}/read
```

### Ledger

```text
GET /api/ledger/{uid}
```

Used for driver earnings summary.

## Main App Flow

Customer:

```text
login -> choose user -> complete profile -> choose pickup/drop -> get quote -> create job -> watch active booking
```

Driver:

```text
login -> choose driver -> set location -> add details -> choose vehicle -> preferences -> upload document -> dashboard -> accept job -> active trip
```

## Supabase Tables

Main tables:

```text
profiles
customer_profiles
driver_profiles
vehicle_types
jobs
trips
driver_locations
documents
notifications
```

Storage bucket:

```text
driver-documents
```

## Local Run

Backend:

```bash
cd backend
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
python main.py
```

Flutter:

```bash
flutter pub get
flutter run
```

## Railway Deploy

Railway hosts the backend.

Settings:

```text
Root Directory: backend
```

Start command:

```bash
uvicorn main:app --host 0.0.0.0 --port $PORT
```

Needed Railway vars:

```env
FIREBASE_CREDENTIALS_JSON=
FIREBASE_DATABASE_URL=

SUPABASE_URL=
SUPABASE_SERVICE_ROLE_KEY=
SUPABASE_STORAGE_BUCKET=driver-documents

GEOAPIFY_API_KEY=

SMTP_HOST=
SMTP_PORT=587
SMTP_USERNAME=
SMTP_PASSWORD=
SMTP_FROM_EMAIL=
SMTP_USE_TLS=true

ALLOW_CUSTOM_TOKEN_AUTH=false
SEED_FIREBASE_DATA=false
```

Test after deploy:

```text
https://your-railway-domain.up.railway.app/health
```

Expected:

```json
{"status":"healthy"}
```

## GitHub

Your code was pushed to:

```text
https://github.com/Xraayan/loadrtest.git
```

Basic commands:

```bash
git status
git add -A
git commit -m "message"
git push
```

## What To Remember

```text
Flutter shows the app.
ApiService sends HTTP calls.
FastAPI handles the business logic.
Supabase stores data.
Firebase handles identity.
Geoapify handles map/search/route.
Resend or SMTP sends OTP.
Railway hosts the backend.
GitHub stores the code.
```
