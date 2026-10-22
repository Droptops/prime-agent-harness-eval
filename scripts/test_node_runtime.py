"""Exercise the Dockerfile's real Node guard without building or calling an API."""

import json
from pathlib import Path
import shlex
import subprocess
import unittest


class RuntimeGuardTest(unittest.TestCase):
    def test_supported_release_boundaries(self):
        dockerfile = Path(__file__).with_name("Dockerfile").read_text()
        line = next(line for line in dockerfile.splitlines() if line.startswith("RUN node -e "))
        guard = shlex.split(line)[3]
        accepted = ["22.23.4", "22.23.5", "22.24.0", "24.22.1", "24.23.0", "26.12.1", "26.13.0"]
        rejected = [
            "20.20.0", "22.23.3", "24.0.0", "24.22.0", "26.0.0", "26.12.0",
            "23.99.0", "25.99.0", "27.0.0", "28.0.0", "24.22.1-rc.1", "invalid",
        ]
        for version in accepted + rejected:
            with self.subTest(version=version):
                script = f'Object.defineProperty(process.versions, "node", {{value: {json.dumps(version)}}});\n{guard}'
                result = subprocess.run(["node", "-e", script], capture_output=True, text=True, check=False)
                self.assertEqual(result.returncode, 0 if version in accepted else 1, result.stderr)


if __name__ == "__main__":
    unittest.main()
