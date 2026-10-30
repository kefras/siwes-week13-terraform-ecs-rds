"""Unit contracts use mocks. These do not prove real RDS connectivity."""
import importlib.util
import os
from pathlib import Path
import unittest
from unittest.mock import patch, MagicMock

spec = importlib.util.spec_from_file_location("week13_app", Path(__file__).parents[1] / "main.py")
main = importlib.util.module_from_spec(spec)
spec.loader.exec_module(main)

class DatabaseTests(unittest.TestCase):
    def test_injected_credentials_and_query(self):
        env = {"DB_HOST": "private.example", "DB_USERNAME": "injected-user", "DB_PASSWORD": "test-only", "DB_SSL_CA": "ca.pem"}
        with patch.dict(os.environ, env), patch.object(main.ssl, "create_default_context") as tls, patch.object(main.pymysql, "connect") as connect:
            cursor = connect.return_value.__enter__.return_value.cursor.return_value.__enter__.return_value
            cursor.fetchone.return_value = (1,)
            main.check_database()
            self.assertEqual(connect.call_args.kwargs["password"], "test-only")
            self.assertEqual(connect.call_args.kwargs["user"], "injected-user")
            self.assertEqual(connect.call_args.kwargs["ssl"], tls.return_value)
            cursor.execute.assert_called_once_with("SELECT 1")

    def test_database_failure_is_unhealthy_and_redacted(self):
        with patch.object(main, "check_database", side_effect=RuntimeError("do-not-expose")):
            with self.assertRaises(main.HTTPException) as error:
                main.health()
            self.assertEqual(error.exception.status_code, 503)
            self.assertNotIn("do-not-expose", error.exception.detail)

    def test_health_success_requires_query(self):
        with patch.object(main, "check_database") as probe:
            self.assertEqual(main.health()["database"], "connected")
            probe.assert_called_once()

if __name__ == "__main__":
    unittest.main()
