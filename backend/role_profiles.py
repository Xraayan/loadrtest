from typing import Any, Dict, Optional

from supabase_config import get_supabase


def is_missing_role_table_error(error: Exception) -> bool:
    message = str(error).lower()
    return (
        "pgrst204" in message
        or "pgrst205" in message
        or "schema cache" in message
        or "could not find the table" in message
        or ("relation" in message and "does not exist" in message)
    )


def get_role_profile(
    table_name: str,
    uid_column: str,
    uid: str,
) -> Optional[Dict[str, Any]]:
    try:
        return (
            get_supabase()
            .table(table_name)
            .select("*")
            .eq(uid_column, uid)
            .maybe_single()
            .execute()
            .data
        )
    except Exception as e:
        if is_missing_role_table_error(e):
            return None
        raise


def upsert_role_profile(
    table_name: str,
    payload: Dict[str, Any],
    conflict_column: str,
) -> Optional[Dict[str, Any]]:
    try:
        response = (
            get_supabase()
            .table(table_name)
            .upsert(payload, on_conflict=conflict_column)
            .execute()
        )
        return response.data[0] if response.data else payload
    except Exception as e:
        if is_missing_role_table_error(e):
            return None
        raise
