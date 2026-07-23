import unittest
from types import SimpleNamespace
from unittest.mock import patch

from routes.auth import _send_otp_email


class SendOtpEmailTest(unittest.TestCase):
    @patch("routes.auth.smtplib.SMTP", side_effect=OSError("timed out"))
    @patch(
        "routes.auth.settings",
        SimpleNamespace(
            resend_api_key=None,
            resend_from_email=None,
            smtp_host="smtp.example.com",
            smtp_port=587,
            smtp_use_tls=True,
            smtp_username=None,
            smtp_password=None,
            smtp_from_email="test@example.com",
            email_strict_send=False,
        ),
    )
    def test_non_strict_smtp_failure_returns_dev_fallback(self, _smtp):
        self.assertFalse(_send_otp_email("user@example.com", "1234"))


if __name__ == "__main__":
    unittest.main()
