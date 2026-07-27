import unittest

from routes.messages import delete_trip_chat


class _DeleteQuery:
    def __init__(self, calls):
        self.calls = calls
        self.filters = []

    def delete(self):
        return self

    def eq(self, column, value):
        self.filters.append((column, value))
        return self

    def execute(self):
        self.calls.append(tuple(self.filters))


class _Supabase:
    def __init__(self):
        self.calls = []

    def table(self, name):
        self.calls.append(name)
        return _DeleteQuery(self.calls)


class DeleteTripChatTest(unittest.TestCase):
    def test_deletes_job_and_trip_scoped_chat(self):
        supabase = _Supabase()

        delete_trip_chat(
            supabase=supabase,
            job_id="job-1",
            trip_id="trip-1",
        )

        self.assertEqual(
            supabase.calls,
            [
                "chat_messages",
                (("job_id", "job-1"),),
                "chat_messages",
                (("trip_id", "trip-1"),),
            ],
        )


if __name__ == "__main__":
    unittest.main()
