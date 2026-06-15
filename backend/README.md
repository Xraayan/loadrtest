# LoadR Backend API

FastAPI backend for LoadR app with Firebase integration for authentication and database.

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

### 3. Firebase Setup
- Create a Firebase project at https://firebase.google.com/
- Download Firebase credentials JSON from Project Settings
- Place it in backend folder as `firebase-credentials.json`
- Copy `.env.example` to `.env` and update with your Firebase URLs

### 4. Run the Server
```bash
python main.py
```

Server will start at `http://localhost:8000`

## API Documentation

### Authentication
- `POST /api/auth/signin` - Send OTP to phone
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

## Access API Docs
Visit `http://localhost:8000/docs` for interactive Swagger documentation
