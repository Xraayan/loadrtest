# LoadR Backend API

FastAPI backend for LoadR.

Current demo direction:

- Firebase Auth for authentication only
- Supabase Postgres for app data
- Supabase Realtime for driver location, active status, and trip updates
- Supabase Storage for driver documents

Firebase Realtime Database is no longer used by mounted API routes.

## Setup

### 1. Create Virtual Environment
```bash
python -m venv venv
source venv/Scripts/activate  # Windows
source venv/bin/activate      # Mac/Linux
```

### 2. Install Dependencies
```bash
pip install -r requirements.txt
```

### 3. Firebase Auth Setup
- Create a Firebase project at https://firebase.google.com/
- Download Firebase credentials JSON from Project Settings
- Place it in backend folder as `firebase-credentials.json`
- Copy `.env.example` to `.env`
- Keep `ALLOW_CUSTOM_TOKEN_AUTH=true` for the current fake OTP demo flow

### 4. Supabase Setup
- Create a Supabase project
- Add `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, and `SUPABASE_STORAGE_BUCKET` to `.env`
- Verify the private Storage bucket named `driver-documents`
- Apply the project's Supabase schema and policies from your local setup notes. These SQL setup files are intentionally ignored because they are demo/environment setup artifacts.

### 5. Run the Server
```bash
python main.py
```

Server will start at `http://localhost:8000`

### 6. Geoapify Setup
Add `GEOAPIFY_API_KEY` to `backend/.env`.

The mobile app calls the backend place-search API. Keep the Geoapify key on the backend; do not pass it through Flutter.

### 7. Email OTP Setup
Use Resend's free onboarding sender for local/beta email OTP. Set these in `backend/.env` or Render environment variables:

```env
RESEND_API_KEY=re_xxxxxxxxx
RESEND_FROM_EMAIL=Acme <onboarding@resend.dev>
EMAIL_STRICT_SEND=false
```

The free onboarding sender is limited. If Resend rejects a recipient and `EMAIL_STRICT_SEND=false`, the backend prints the OTP for local beta testing instead of failing sign-in.

For production, verify a domain in Resend and use something like `LoadR <otp@yourdomain.com>`.

## API Documentation

### Authentication
- `POST /api/auth/signin` - Send OTP to email
- `POST /api/auth/verify-otp` - Verify OTP and get token
- `POST /api/auth/refresh-token` - Refresh authentication token

### Drivers
- `GET /api/drivers/{uid}` - Get driver profile
- `PUT /api/drivers/{uid}` - Update driver profile
- `POST /api/drivers/{uid}/location` - Update driver location

### Trips
- `POST /api/trips/` - Create trip
- `GET /api/trips/{uid}` - Get all trips for driver
- `GET /api/trips/trip/{trip_id}` - Get trip details
- `PATCH /api/trips/trip/{trip_id}/status` - Update trip status

### Vehicles
- `GET /api/vehicles/` - Get all vehicles
- `GET /api/vehicles/{uid}` - Get driver's vehicles
- `POST /api/vehicles/{uid}/assign` - Assign vehicle to driver

### Documents
- `POST /api/documents/upload` - Upload document
- `GET /api/documents/{uid}` - Get driver's documents
- `PATCH /api/documents/{uid}/verify/{doc_id}` - Verify document

### Location
- `POST /api/location/update` - Update current location
- `GET /api/location/{uid}` - Get current location

### Places
- `GET /api/places/autocomplete` - Search Indian place suggestions through backend Geoapify proxy
- `GET /api/places/reverse` - Reverse geocode coordinates through backend Geoapify proxy

### Quotes
- `POST /api/quotes/estimate` - Calculate distance, route points, vehicle quotes, and location metadata

## Access API Docs
Visit `http://localhost:8000/docs` for interactive Swagger documentation
