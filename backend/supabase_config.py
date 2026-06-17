from functools import lru_cache

from supabase import Client, create_client

from config import settings


class SupabaseNotConfiguredError(RuntimeError):
    """Raised when Supabase environment variables are missing."""


@lru_cache(maxsize=1)
def get_supabase() -> Client:
    """Return the backend Supabase client.

    This uses the service role key because FastAPI is the trusted server.
    Never expose SUPABASE_SERVICE_ROLE_KEY to Flutter or any frontend.
    """
    if not settings.supabase_url or not settings.supabase_service_role_key:
        raise SupabaseNotConfiguredError(
            "Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in backend/.env"
        )

    return create_client(settings.supabase_url, settings.supabase_service_role_key)

