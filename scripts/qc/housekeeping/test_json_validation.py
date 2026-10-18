"""Exercise streaming syntax validation independently of registry retention."""
import io
import json
from pathlib import Path
import random
import runpy
import unittest

validate = runpy.run_path(str(Path(__file__).resolve().parents[2] / "validate-esir-json.py"))["validate"]


class StreamingJson(unittest.TestCase):
    def test_valid_objects(self):
        for value in [{}, {"a": [None, True, False, {}, [], -1.25e30]}, {"a": "quotes\"\n\\and unicode \u3042"}]:
            validate(io.StringIO(json.dumps(value)))

    def test_incomplete_and_invalid(self):
        for text in ["", "[]", "{", '{"a":}', '{"a":01}', '{"a":1,}', '{"a":[1,]}', '{"a":NaN}', '{}{}', '{"a":true false}', '{"a":"\n"}', '{"a":"\\x01"}', '{"a":1.}', '{"a":1e+}']:
            with self.subTest(text=text), self.assertRaises(ValueError):
                validate(io.StringIO(text))

    def test_empty_final_data(self):
        with self.assertRaises(ValueError):
            validate(io.StringIO('{}'), require_nonempty=True)
        validate(io.StringIO('{"item":{}}'), require_nonempty=True)

    def test_all_token_boundaries(self):
        for token in ["1e+3", "1.25", "-12.25E-3", '"escaped\\\"text"', '"unicode\\u3042"', "true", "null", "false", '[{},1,2]']:
            for start in range(65520, 65540):
                text = '{"x":' + ' ' * (start - 5) + token + '}'
                json.loads(text)
                with self.subTest(token=token, start=start):
                    validate(io.StringIO(text))

    def test_large_nested_object(self):
        rng = random.Random(2048)
        data = {str(i): [rng.random(), rng.randint(-1000, 1000), 'x' * rng.randint(0, 100), {"ok": True}] for i in range(3000)}
        validate(io.StringIO(json.dumps(data)))


if __name__ == "__main__":
    unittest.main()
