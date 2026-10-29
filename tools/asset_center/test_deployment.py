import base64
from contextlib import contextmanager
import hashlib
import http.client
import json
import os
from pathlib import Path
import tempfile
import threading
import unittest
from unittest.mock import patch
from http.server import ThreadingHTTPServer

import deploy
import server
import sync


class DeploymentTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.data = self.root / deploy.DATA_DIR
        self.data.mkdir(parents=True)
        self.assets = [{"资产ID": "CHR-001", "资产名称": "Test", "一级分类": "人物"}]
        (self.data / deploy.DATA_FILES[0]).write_text(json.dumps({"assets": self.assets}))
        (self.data / deploy.DATA_FILES[1]).write_text("seed csv")
        (self.data / deploy.DATA_FILES[2]).write_text("seed markdown")
        self.web = self.root / "tools/asset_center/web"
        self.web.mkdir(parents=True)
        (self.web / "index.html").write_text("<html>Asset Center</html>")
        (self.root / "assets").mkdir()
        (self.root / "assets/test.png").write_bytes(b"test image")
        (self.root / ".env.instabox").write_text("private credentials")
        self.auth = "Basic " + base64.b64encode(b"admin:test-password").decode()

    @contextmanager
    def serving(self):
        with (
            patch.dict(os.environ, {
                "ASSET_CENTER_PASSWORD": "test-password",
                "ASSET_CENTER_USERNAME": "admin",
                "ASSET_CENTER_AUTH_REQUIRED": "1",
                "ASSET_CENTER_PUBLIC_ORIGIN": "https://assets.example.test",
            }),
            patch.object(server, "WEB_DIR", self.web),
            patch.object(server, "WORKSPACE_ROOT", self.root),
            patch.object(sync, "WORKSPACE_ROOT", self.root),
            patch.object(sync, "JSON_PATH", self.data / deploy.DATA_FILES[0]),
            patch.object(sync, "CSV_PATH", self.data / deploy.DATA_FILES[1]),
            patch.object(sync, "CATALOG_MD_PATH", self.data / deploy.DATA_FILES[2]),
            patch.object(sync, "ALPHA_STATE_GD", self.root / "missing.gd"),
        ):
            httpd = ThreadingHTTPServer(("127.0.0.1", 0), server.AssetCenterHandler)
            thread = threading.Thread(target=httpd.serve_forever, daemon=True)
            thread.start()
            try:
                yield httpd.server_port
            finally:
                httpd.shutdown()
                httpd.server_close()
                thread.join()

    def request(self, port, method, path, body=None, headers=None):
        conn = http.client.HTTPConnection("127.0.0.1", port, timeout=5)
        conn.request(method, path, body=body, headers=headers or {})
        result = conn.getresponse()
        status, data, response_headers = result.status, result.read(), dict(result.getheaders())
        conn.close()
        return status, data, response_headers

    def test_all_public_surfaces_require_authentication(self):
        with self.serving() as port:
            for method, path in [
                ("GET", "/"), ("GET", "/api/data"), ("GET", "/media/assets/test.png"),
                ("HEAD", "/"), ("OPTIONS", "/api/data"),
                ("POST", "/api/asset/update"), ("POST", "/api/asset/create"),
            ]:
                with self.subTest(method=method, path=path):
                    status, _, headers = self.request(port, method, path)
                    self.assertEqual(status, 401)
                    self.assertIn("WWW-Authenticate", headers)
                    self.assertNotIn("Access-Control-Allow-Origin", headers)
            status, _, _ = self.request(port, "GET", "/", headers={"Authorization": "Basic wrong"})
            self.assertEqual(status, 401)

    def test_data_and_media_load_but_project_secrets_are_blocked(self):
        with self.serving() as port:
            headers = {"Authorization": self.auth}
            status, body, _ = self.request(port, "GET", "/api/data", headers=headers)
            self.assertEqual(status, 200)
            self.assertEqual(json.loads(body)["stats"]["total_assets"], 1)
            self.assertEqual(self.request(port, "GET", "/media/assets/test.png", headers=headers)[0], 200)
            for path in ("/media/.env.instabox", "/media/assets/../../outside.png",
                         "/media/docs/art/anything.png"):
                self.assertEqual(self.request(port, "GET", path, headers=headers)[0], 403)

    def test_cross_origin_writes_are_rejected_without_changing_records(self):
        before = (self.data / deploy.DATA_FILES[0]).read_bytes()
        with self.serving() as port:
            headers = {"Authorization": self.auth, "Origin": "https://attacker.example"}
            payload = json.dumps({"资产ID": "CHR-001", "备注": "should not save"})
            self.assertEqual(self.request(port, "POST", "/api/asset/update", payload, headers)[0], 403)
        self.assertEqual((self.data / deploy.DATA_FILES[0]).read_bytes(), before)

    def test_authenticated_update_persists_across_server_restart(self):
        with self.serving() as port:
            headers = {"Authorization": self.auth, "Origin": "https://assets.example.test"}
            payload = json.dumps({"资产ID": "CHR-001", "备注": "saved on server"})
            status, body, _ = self.request(port, "POST", "/api/asset/update", payload, headers)
            self.assertEqual(status, 200, body)
        with self.serving() as port:
            status, body, _ = self.request(port, "GET", "/api/data",
                                           headers={"Authorization": self.auth})
            self.assertEqual(status, 200)
            self.assertEqual(json.loads(body)["assets"][0]["备注"], "saved on server")

    def test_public_startup_fails_closed_without_a_password(self):
        with patch.dict(os.environ, {"ASSET_CENTER_PASSWORD": "", "ASSET_CENTER_AUTH_REQUIRED": "1"}):
            with self.assertRaisesRegex(RuntimeError, "PASSWORD"):
                server.run_server(0)

    def test_local_mode_remains_available_without_auth(self):
        with self.serving() as port, patch.dict(
            os.environ, {"ASSET_CENTER_PASSWORD": "", "ASSET_CENTER_AUTH_REQUIRED": ""}
        ):
            self.assertEqual(self.request(port, "GET", "/api/data")[0], 200)

    def test_release_archive_excludes_credentials_and_preserves_server_data(self):
        import tarfile
        tool = self.web.parent
        (tool / "server.py").write_text("print('server')")
        (tool / "install.sh").write_text("echo install")
        source = self.root / "godot/scripts/alpha/alpha_state.gd"
        source.parent.mkdir(parents=True)
        source.write_text("# gameplay")
        state = self.root / ".scratch/instabox"
        state.mkdir(parents=True)
        config = self.root / ".env.instabox"
        config.write_text(json.dumps({"api_key": "test-key", "username": "admin", "password": "test"}))
        binary = state / "instabox"
        binary.touch()
        files = deploy.collect_files(self.root)
        manifest = {name: hashlib.sha256(path.read_bytes()).hexdigest() for name, path in files.items()}
        for first_deploy in (True, False):
            archives = []

            def fake_cli(args, env, capture=False, stdin=None):
                if args[0] == "get":
                    return json.dumps({"state": "paused"})
                if args[:2] == ["port", "publish"]:
                    return json.dumps({"url": "https://assets.example.test"})
                if args[0] == "push" and args[2].endswith("release.tar"):
                    with tarfile.open(args[2]) as archive:
                        archives.append(archive.getnames())
                return ""

            remote_state = {"seed": first_deploy, "manifest": {} if first_deploy else manifest}
            with (
                patch.object(deploy, "ROOT", self.root),
                patch.object(deploy, "STATE", state),
                patch.object(deploy, "CONFIG", config),
                patch.object(deploy, "cli", side_effect=fake_cli),
                patch.object(deploy, "remote_command",
                             side_effect=[json.dumps(remote_state), "healthy\n"]),
                patch.object(deploy, "verify_public") as verified,
            ):
                deploy.main()
                verified.assert_called_once()
            names = archives[0]
            self.assertNotIn(".env.instabox", names)
            self.assertFalse(any(name.startswith("docs/") for name in names))
            if first_deploy:
                self.assertIn(".seed/" + str(deploy.DATA_DIR / deploy.DATA_FILES[0]), names)
                self.assertIn("assets/test.png", names)
            else:
                self.assertEqual(names, [".release-manifest.json"])


if __name__ == "__main__":
    unittest.main()
