from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from config import settings
from firebase_config import init_firebase
from routes import auth, drivers, trips, vehicles, documents, location

# Initialize Firebase
init_firebase()

# Create FastAPI app
app = FastAPI(title="LoadR API", version="1.0.0")

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routes
app.include_router(auth.router, prefix="/api/auth", tags=["Authentication"])
app.include_router(drivers.router, prefix="/api/drivers", tags=["Drivers"])
app.include_router(trips.router, prefix="/api/trips", tags=["Trips"])
app.include_router(vehicles.router, prefix="/api/vehicles", tags=["Vehicles"])
app.include_router(documents.router, prefix="/api/documents", tags=["Documents"])
app.include_router(location.router, prefix="/api/location", tags=["Location"])

@app.get("/")
def read_root():
    return {"message": "LoadR API is running"}

@app.get("/health")
def health_check():
    return {"status": "healthy"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host=settings.api_host, port=settings.api_port)
